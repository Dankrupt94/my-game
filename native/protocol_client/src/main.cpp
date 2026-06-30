#include "auth_crypt.h"
#include "protocol_bytes.h"
#include "srp6.h"
#include "world_packets.h"

#include <openssl/rand.h>

#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace
{
constexpr std::uint16_t SMSG_AUTH_CHALLENGE = 0x1EC;
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

std::uint16_t read_le_u16(std::span<const std::uint8_t> bytes, std::size_t offset)
{
    if (offset + 2 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint16");
    }

    return static_cast<std::uint16_t>(bytes[offset])
        | static_cast<std::uint16_t>(bytes[offset + 1] << 8);
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

struct AuthChallengeData
{
    srp6::EphemeralKey B{};
    srp6::Salt salt{};
    std::uint8_t security_flags = 0;
};

AuthChallengeData read_auth_challenge_response(int fd)
{
    auto prefix = read_exact(fd, 3);
    if (prefix[0] != AUTH_LOGON_CHALLENGE)
    {
        throw std::runtime_error("expected AUTH_LOGON_CHALLENGE response");
    }

    std::uint8_t const result = prefix[2];
    if (result != 0)
    {
        throw std::runtime_error("auth challenge rejected with result 0x" + hex(std::span<const std::uint8_t>(&result, 1)));
    }

    auto body = read_exact(fd, 116);
    std::uint8_t const g_len = body[32];
    std::uint8_t const g = body[33];
    std::uint8_t const n_len = body[34];
    if (g_len != 1 || g != 7 || n_len != 32)
    {
        throw std::runtime_error("unexpected SRP parameter lengths");
    }

    AuthChallengeData challenge;
    std::copy_n(body.data(), challenge.B.size(), challenge.B.begin());
    std::copy_n(body.data() + 67, challenge.salt.size(), challenge.salt.begin());
    challenge.security_flags = body[115];
    return challenge;
}

std::vector<std::uint8_t> build_auth_logon_proof(srp6::ClientProof const& proof)
{
    std::vector<std::uint8_t> bytes;
    bytes.reserve(75);
    bytes.push_back(0x01);
    bytes.insert(bytes.end(), proof.A.begin(), proof.A.end());
    bytes.insert(bytes.end(), proof.M.begin(), proof.M.end());
    bytes.insert(bytes.end(), 20, 0x00); // crc_hash/version proof; accepted when StrictVersionCheck is false.
    bytes.push_back(0x00); // number_of_keys
    bytes.push_back(0x00); // securityFlags
    return bytes;
}

void read_auth_proof_response(int fd, srp6::ClientProof const& proof)
{
    auto prefix = read_exact(fd, 2);
    if (prefix[0] != 0x01)
    {
        throw std::runtime_error("expected AUTH_LOGON_PROOF response");
    }
    if (prefix[1] != 0)
    {
        throw std::runtime_error("auth proof rejected with result 0x" + hex(std::span<const std::uint8_t>(&prefix[1], 1)));
    }

    auto body = read_exact(fd, 30);
    srp6::Proof M2{};
    std::copy_n(body.data(), M2.size(), M2.begin());
    if (M2 != proof.M2)
    {
        throw std::runtime_error("server SRP proof mismatch");
    }
}

std::string read_c_string(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    std::size_t start = offset;
    while (offset < bytes.size() && bytes[offset] != 0)
    {
        ++offset;
    }
    if (offset >= bytes.size())
    {
        throw std::runtime_error("unterminated string");
    }

    std::string value(reinterpret_cast<char const*>(bytes.data() + start), offset - start);
    ++offset;
    return value;
}

void parse_realm_list(std::span<const std::uint8_t> body)
{
    if (body.size() < 6)
    {
        throw std::runtime_error("realm list body too short");
    }

    std::size_t offset = 0;
    offset += 4; // reserved uint32
    std::uint16_t const realm_count = read_le_u16(body, offset);
    offset += 2;
    if (realm_count == 0)
    {
        throw std::runtime_error("realm list contains no compatible realms");
    }

    if (offset + 3 > body.size())
    {
        throw std::runtime_error("realm entry too short");
    }

    std::uint8_t const realm_type = body[offset++];
    std::uint8_t const lock = body[offset++];
    std::uint8_t const flags = body[offset++];
    std::string name = read_c_string(body, offset);
    std::string endpoint = read_c_string(body, offset);

    if (offset + 4 + 1 + 1 + 1 > body.size())
    {
        throw std::runtime_error("realm entry numeric fields missing");
    }

    offset += 4; // population float
    std::uint8_t const character_count = body[offset++];
    std::uint8_t const timezone = body[offset++];
    std::uint8_t const realm_id = body[offset++];

    std::cout << "AUTH_FLOW_OK"
              << " realms=" << realm_count
              << " first_realm=\"" << name << "\""
              << " endpoint=\"" << endpoint << "\""
              << " realm_id=" << static_cast<int>(realm_id)
              << " type=" << static_cast<int>(realm_type)
              << " lock=" << static_cast<int>(lock)
              << " flags=0x" << hex(std::span<const std::uint8_t>(&flags, 1))
              << " chars=" << static_cast<int>(character_count)
              << " timezone=" << static_cast<int>(timezone)
              << "\n";
}

srp6::EphemeralKey random_ephemeral()
{
    srp6::EphemeralKey bytes{};
    if (RAND_bytes(bytes.data(), static_cast<int>(bytes.size())) != 1)
    {
        throw std::runtime_error("RAND_bytes failed");
    }
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
    if (!world_packet_self_test())
    {
        throw std::runtime_error("world packet self-test failed");
    }
    std::cout << "WORLD_PACKET_SELF_TEST_OK\n";
    return 0;
}

int auth_challenge(std::string const& host, std::string const& port, std::string const& account)
{
    SocketFd socket = connect_tcp(host, port);
    auto packet = build_auth_logon_challenge(account);
    write_all(socket.get(), packet);

    AuthChallengeData challenge = read_auth_challenge_response(socket.get());

    std::cout << "AUTH_CHALLENGE_OK"
              << " b_len=32"
              << " g=0x07"
              << " n_len=32"
              << " salt_len=32"
              << " security_flags=0x" << hex(std::span<const std::uint8_t>(&challenge.security_flags, 1))
              << "\n";
    return 0;
}

int auth_flow(std::string const& host, std::string const& port, std::string const& account)
{
    char const* password = std::getenv("ACORE_PROTOCOL_PASSWORD");
    if (!password || std::string(password).empty())
    {
        throw std::runtime_error("ACORE_PROTOCOL_PASSWORD is not set");
    }

    SocketFd socket = connect_tcp(host, port);
    auto challenge_packet = build_auth_logon_challenge(account);
    write_all(socket.get(), challenge_packet);
    AuthChallengeData challenge = read_auth_challenge_response(socket.get());
    if (challenge.security_flags != 0)
    {
        throw std::runtime_error("security-token auth is not implemented yet");
    }

    srp6::ClientProof proof = srp6::compute_client_proof(
        account,
        password,
        challenge.salt,
        challenge.B,
        random_ephemeral());

    auto proof_packet = build_auth_logon_proof(proof);
    write_all(socket.get(), proof_packet);
    read_auth_proof_response(socket.get(), proof);

    std::array<std::uint8_t, 5> realm_request{0x10, 0, 0, 0, 0};
    write_all(socket.get(), realm_request);
    auto realm_header = read_exact(socket.get(), 3);
    if (realm_header[0] != 0x10)
    {
        throw std::runtime_error("expected REALM_LIST response");
    }

    std::uint16_t const body_size = read_le_u16(realm_header, 1);
    auto body = read_exact(socket.get(), body_size);
    parse_realm_list(body);
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
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --auth-flow <host> <port> <account>\n"
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

        if (argc == 5 && std::strcmp(argv[1], "--auth-flow") == 0)
        {
            return auth_flow(argv[2], argv[3], argv[4]);
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
