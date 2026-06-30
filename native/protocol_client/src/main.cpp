#include "auth_crypt.h"
#include "protocol_bytes.h"
#include "srp6.h"

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
constexpr std::uint8_t AUTH_LOGON_CHALLENGE = 0x00;

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

void write_all(int fd, std::span<const std::uint8_t> bytes)
{
    std::size_t offset = 0;
    while (offset < bytes.size())
    {
        ssize_t const sent = send(fd, bytes.data() + offset, bytes.size() - offset, 0);
        if (sent <= 0)
        {
            throw std::runtime_error("socket closed while writing");
        }

        offset += static_cast<std::size_t>(sent);
    }
}

void append_u16_le(std::vector<std::uint8_t>& bytes, std::uint16_t value)
{
    bytes.push_back(static_cast<std::uint8_t>(value & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}

void append_u32_le(std::vector<std::uint8_t>& bytes, std::uint32_t value)
{
    bytes.push_back(static_cast<std::uint8_t>(value & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}

std::vector<std::uint8_t> build_auth_logon_challenge(std::string const& account)
{
    if (account.empty() || account.size() > 16)
    {
        throw std::runtime_error("account name must be 1 to 16 bytes for this probe");
    }

    std::vector<std::uint8_t> bytes;
    bytes.reserve(34 + account.size());
    bytes.push_back(AUTH_LOGON_CHALLENGE);
    bytes.push_back(0x08);
    append_u16_le(bytes, static_cast<std::uint16_t>(30 + account.size()));
    bytes.insert(bytes.end(), {'W', 'o', 'W', 0});
    bytes.push_back(3);
    bytes.push_back(3);
    bytes.push_back(5);
    append_u16_le(bytes, 12340);
    bytes.insert(bytes.end(), {0, '6', '8', 'x'});
    bytes.insert(bytes.end(), {0, 'n', 'i', 'W'});
    bytes.insert(bytes.end(), {'S', 'U', 'n', 'e'});
    append_u32_le(bytes, 0);
    append_u32_le(bytes, 0x0100007F);
    bytes.push_back(static_cast<std::uint8_t>(account.size()));
    bytes.insert(bytes.end(), account.begin(), account.end());
    return bytes;
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
    if (!srp6::self_test())
    {
        throw std::runtime_error("SRP6 self-test failed");
    }
    std::cout << "SRP6_SELF_TEST_OK\n";
    return 0;
}

int auth_challenge(std::string const& host, std::string const& port, std::string const& account)
{
    SocketFd socket = connect_tcp(host, port);
    auto packet = build_auth_logon_challenge(account);
    write_all(socket.get(), packet);

    auto prefix = read_exact(socket.get(), 3);
    if (prefix[0] != AUTH_LOGON_CHALLENGE)
    {
        throw std::runtime_error("expected AUTH_LOGON_CHALLENGE response");
    }

    std::uint8_t const result = prefix[2];
    if (result != 0)
    {
        std::cout << "AUTH_CHALLENGE_REJECTED result=0x" << hex(std::span<const std::uint8_t>(&result, 1)) << "\n";
        return 1;
    }

    auto body = read_exact(socket.get(), 116);
    std::uint8_t const g_len = body[32];
    std::uint8_t const g = body[33];
    std::uint8_t const n_len = body[34];
    std::uint8_t const security_flags = body[115];

    if (g_len != 1 || n_len != 32)
    {
        throw std::runtime_error("unexpected SRP parameter lengths");
    }

    std::cout << "AUTH_CHALLENGE_OK"
              << " b_len=32"
              << " g=0x" << hex(std::span<const std::uint8_t>(&g, 1))
              << " n_len=" << static_cast<int>(n_len)
              << " salt_len=32"
              << " security_flags=0x" << hex(std::span<const std::uint8_t>(&security_flags, 1))
              << "\n";
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
              << "  acore_protocol_client --auth-challenge <host> <port> <account>\n"
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

        if (argc == 5 && std::strcmp(argv[1], "--auth-challenge") == 0)
        {
            return auth_challenge(argv[2], argv[3], argv[4]);
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
