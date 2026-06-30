#include "auth_crypt.h"
#include "protocol_bytes.h"

#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>
#include <unistd.h>

#include <array>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace
{
constexpr std::uint16_t SMSG_AUTH_CHALLENGE = 0x1EC;
constexpr std::uint32_t CMSG_CHAR_ENUM = 0x037;

class SocketFd
{
public:
    explicit SocketFd(int fd = -1) : fd_(fd) {}
    ~SocketFd()
    {
        if (fd_ >= 0)
        {
            close(fd_);
        }
    }

    SocketFd(SocketFd const&) = delete;
    SocketFd& operator=(SocketFd const&) = delete;

    SocketFd(SocketFd&& other) noexcept : fd_(other.fd_)
    {
        other.fd_ = -1;
    }

    [[nodiscard]] int get() const { return fd_; }

private:
    int fd_;
};

SocketFd connect_tcp(std::string const& host, std::string const& port)
{
    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    addrinfo* result = nullptr;
    int const rc = getaddrinfo(host.c_str(), port.c_str(), &hints, &result);
    if (rc != 0)
    {
        throw std::runtime_error(std::string("getaddrinfo failed: ") + gai_strerror(rc));
    }

    std::unique_ptr<addrinfo, decltype(&freeaddrinfo)> addresses(result, freeaddrinfo);
    for (addrinfo* entry = addresses.get(); entry; entry = entry->ai_next)
    {
        int fd = socket(entry->ai_family, entry->ai_socktype, entry->ai_protocol);
        if (fd < 0)
        {
            continue;
        }

        if (connect(fd, entry->ai_addr, entry->ai_addrlen) == 0)
        {
            return SocketFd(fd);
        }

        close(fd);
    }

    throw std::runtime_error("could not connect to " + host + ":" + port);
}

std::vector<std::uint8_t> read_exact(int fd, std::size_t size)
{
    std::vector<std::uint8_t> bytes(size);
    std::size_t offset = 0;
    while (offset < size)
    {
        ssize_t const got = recv(fd, bytes.data() + offset, size - offset, 0);
        if (got <= 0)
        {
            throw std::runtime_error("socket closed while reading");
        }

        offset += static_cast<std::size_t>(got);
    }
    return bytes;
}

std::uint32_t read_le_u32(std::span<const std::uint8_t> bytes, std::size_t offset)
{
    if (offset + 4 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint32");
    }

    return static_cast<std::uint32_t>(bytes[offset])
        | (static_cast<std::uint32_t>(bytes[offset + 1]) << 8)
        | (static_cast<std::uint32_t>(bytes[offset + 2]) << 16)
        | (static_cast<std::uint32_t>(bytes[offset + 3]) << 24);
}

int self_test()
{
    auto client_header = build_client_header(CMSG_CHAR_ENUM, 0);
    if (hex(client_header) != "000437000000")
    {
        throw std::runtime_error("client header encoding failed");
    }

    auto server_header = build_server_header_for_test(SMSG_AUTH_CHALLENGE, 40);
    if (hex(server_header) != "002aec01")
    {
        throw std::runtime_error("server header encoding failed");
    }

    ServerHeader parsed = parse_server_header(server_header);
    if (parsed.size != 42 || parsed.opcode != SMSG_AUTH_CHALLENGE || parsed.header_length != 4)
    {
        throw std::runtime_error("server header parsing failed");
    }

    std::array<std::uint8_t, AuthCrypt::SessionKeyLength> session_key{};
    for (std::size_t i = 0; i < session_key.size(); ++i)
    {
        session_key[i] = static_cast<std::uint8_t>(i);
    }

    AuthCrypt crypt;
    crypt.init(session_key);
    auto encrypted = client_header;
    crypt.encrypt_client_header(encrypted);
    if (encrypted == client_header)
    {
        throw std::runtime_error("client header was not encrypted");
    }

    std::cout << "PROTOCOL_CLIENT_SELF_TEST_OK encrypted_char_enum_header="
              << hex(encrypted) << "\n";
    return 0;
}

int world_challenge(std::string const& host, std::string const& port)
{
    SocketFd socket = connect_tcp(host, port);

    auto first = read_exact(socket.get(), 4);
    std::vector<std::uint8_t> header = first;
    if ((first[0] & 0x80) != 0)
    {
        auto extra = read_exact(socket.get(), 1);
        header.push_back(extra[0]);
    }

    ServerHeader parsed = parse_server_header(header);
    std::size_t const payload_size = parsed.size - 2;
    auto payload = read_exact(socket.get(), payload_size);

    if (parsed.opcode != SMSG_AUTH_CHALLENGE)
    {
        throw std::runtime_error("expected SMSG_AUTH_CHALLENGE");
    }
    if (payload.size() != 40)
    {
        throw std::runtime_error("unexpected auth challenge payload size");
    }

    std::uint32_t const marker = read_le_u32(payload, 0);
    std::span<const std::uint8_t> seed(payload.data() + 4, 4);

    std::cout << "WORLD_CHALLENGE_OK opcode=0x1ec payload_size=" << payload.size()
              << " marker=" << marker
              << " seed=" << hex(seed)
              << "\n";
    return 0;
}

void usage()
{
    std::cerr << "Usage:\n"
              << "  acore_protocol_client --self-test\n"
              << "  acore_protocol_client --world-challenge <host> <port>\n";
}
}

int main(int argc, char** argv)
{
    try
    {
        if (argc == 2 && std::strcmp(argv[1], "--self-test") == 0)
        {
            return self_test();
        }

        if (argc == 4 && std::strcmp(argv[1], "--world-challenge") == 0)
        {
            return world_challenge(argv[2], argv[3]);
        }

        usage();
        return 2;
    }
    catch (std::exception const& exc)
    {
        std::cerr << "ERROR: " << exc.what() << "\n";
        return 1;
    }
}
