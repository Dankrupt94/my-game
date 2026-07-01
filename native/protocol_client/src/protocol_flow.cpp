#include "protocol_flow.h"

#include "auth_crypt.h"
#include "protocol_bytes.h"

#include <openssl/rand.h>

#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace acore_protocol
{
namespace
{
constexpr std::uint8_t AUTH_LOGON_CHALLENGE = 0x00;
constexpr int SocketTimeoutSeconds = 30;

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

struct AuthChallengeData
{
    srp6::EphemeralKey B{};
    srp6::Salt salt{};
    std::uint8_t security_flags = 0;
};

struct WorldPacketData
{
    std::uint16_t opcode = 0;
    std::vector<std::uint8_t> payload;
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
            timeval timeout{};
            timeout.tv_sec = SocketTimeoutSeconds;
            timeout.tv_usec = 0;
            if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) != 0
                || setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) != 0)
            {
                close(fd);
                throw std::runtime_error("could not configure socket timeout");
            }
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
        if (got < 0 && errno == EINTR)
        {
            continue;
        }
        if (got < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
        {
            throw std::runtime_error("socket read timed out");
        }
        if (got <= 0)
        {
            throw std::runtime_error("socket closed while reading");
        }

        offset += static_cast<std::size_t>(got);
    }
    return bytes;
}

std::vector<std::uint8_t> read_exact_context(int fd, std::size_t size, char const* context)
{
    try
    {
        return read_exact(fd, size);
    }
    catch (std::exception const& exc)
    {
        throw std::runtime_error(std::string(context) + ": " + exc.what());
    }
}

void write_all(int fd, std::span<const std::uint8_t> bytes)
{
    std::size_t offset = 0;
    while (offset < bytes.size())
    {
        ssize_t const sent = send(fd, bytes.data() + offset, bytes.size() - offset, 0);
        if (sent < 0 && errno == EINTR)
        {
            continue;
        }
        if (sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
        {
            throw std::runtime_error("socket write timed out");
        }
        if (sent <= 0)
        {
            throw std::runtime_error("socket closed while writing");
        }

        offset += static_cast<std::size_t>(sent);
    }
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

RealmInfo parse_realm_list(std::span<const std::uint8_t> body)
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
    std::size_t const colon = endpoint.rfind(':');
    if (colon == std::string::npos || colon + 1 >= endpoint.size())
    {
        throw std::runtime_error("realm endpoint does not contain host:port");
    }

    return {
        .realm_count = realm_count,
        .realm_type = realm_type,
        .lock = lock,
        .flags = flags,
        .character_count = character_count,
        .timezone = timezone,
        .realm_id = realm_id,
        .name = name,
        .endpoint = endpoint,
        .host = endpoint.substr(0, colon),
        .port = endpoint.substr(colon + 1),
    };
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

std::array<std::uint8_t, 4> random_seed4()
{
    std::array<std::uint8_t, 4> bytes{};
    if (RAND_bytes(bytes.data(), static_cast<int>(bytes.size())) != 1)
    {
        throw std::runtime_error("RAND_bytes failed");
    }
    return bytes;
}

WorldPacketData read_world_packet(int fd, AuthCrypt* crypt, bool trace)
{
    auto header = read_exact_context(fd, 4, "reading world packet header");
    if (crypt && crypt->initialized())
    {
        crypt->decrypt_server_header(header);
    }

    if ((header[0] & 0x80) != 0)
    {
        auto extra = read_exact_context(fd, 1, "reading large world packet header");
        if (crypt && crypt->initialized())
        {
            crypt->decrypt_server_header(extra);
        }
        header.push_back(extra[0]);
    }

    ServerHeader parsed = parse_server_header(header);
    if (parsed.size < 2)
    {
        throw std::runtime_error("server packet size is smaller than opcode");
    }
    if (trace)
    {
        std::cerr << "WORLD_PACKET_IN opcode=0x" << std::hex << parsed.opcode << std::dec
                  << " payload_size=" << (parsed.size - 2)
                  << " header=" << hex(header)
                  << "\n";
    }

    return {
        .opcode = parsed.opcode,
        .payload = read_exact_context(fd, parsed.size - 2, "reading world packet payload"),
    };
}

void write_world_packet(int fd, std::uint32_t opcode, std::span<const std::uint8_t> payload, AuthCrypt* crypt)
{
    auto packet = build_client_packet(opcode, payload);
    if (crypt && crypt->initialized())
    {
        crypt->encrypt_client_header(std::span<std::uint8_t>(packet.data(), 6));
    }
    write_all(fd, packet);
}

std::uint8_t parse_auth_response(std::span<const std::uint8_t> payload)
{
    if (payload.empty())
    {
        throw std::runtime_error("SMSG_AUTH_RESPONSE payload is empty");
    }
    return payload[0];
}
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
    bytes.insert(bytes.end(), {'6', '8', 'x', 0});
    bytes.insert(bytes.end(), {'n', 'i', 'W', 0});
    bytes.insert(bytes.end(), {'S', 'U', 'n', 'e'});
    append_u32_le(bytes, 0);
    append_u32_le(bytes, 0x0100007F);
    bytes.push_back(static_cast<std::uint8_t>(account.size()));
    bytes.insert(bytes.end(), account.begin(), account.end());
    return bytes;
}

std::string format_auth_flow_ok(RealmInfo const& realm)
{
    std::uint8_t const flags = realm.flags;
    return "AUTH_FLOW_OK realms=" + std::to_string(realm.realm_count)
        + " first_realm=\"" + realm.name + "\""
        + " endpoint=\"" + realm.endpoint + "\""
        + " realm_id=" + std::to_string(realm.realm_id)
        + " type=" + std::to_string(realm.realm_type)
        + " lock=" + std::to_string(realm.lock)
        + " flags=0x" + hex(std::span<const std::uint8_t>(&flags, 1))
        + " chars=" + std::to_string(realm.character_count)
        + " timezone=" + std::to_string(realm.timezone);
}

AuthChallengeSummary probe_auth_challenge(
    std::string const& host,
    std::string const& port,
    std::string const& account)
{
    SocketFd socket = connect_tcp(host, port);
    auto packet = build_auth_logon_challenge(account);
    write_all(socket.get(), packet);

    AuthChallengeData challenge = read_auth_challenge_response(socket.get());
    return {.security_flags = challenge.security_flags};
}

AuthFlowResult run_auth_flow(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password)
{
    if (password.empty())
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
    return {
        .session_key = proof.K,
        .realm = parse_realm_list(body),
    };
}

WorldChallengeSummary probe_world_challenge(std::string const& host, std::string const& port)
{
    SocketFd socket = connect_tcp(host, port);
    WorldPacketData packet = read_world_packet(socket.get(), nullptr, false);

    if (packet.opcode != SMSG_AUTH_CHALLENGE)
    {
        throw std::runtime_error("expected SMSG_AUTH_CHALLENGE");
    }
    if (packet.payload.size() != 40)
    {
        throw std::runtime_error("unexpected auth challenge payload size");
    }

    WorldChallengeSummary summary;
    summary.marker = read_le_u32(packet.payload, 0);
    std::copy_n(packet.payload.data() + 4, summary.seed.size(), summary.seed.begin());
    return summary;
}

CharacterFlowResult run_character_flow(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    FlowOptions options)
{
    AuthFlowResult auth = run_auth_flow(host, port, account, password);
    SocketFd socket = connect_tcp(auth.realm.host, auth.realm.port);

    WorldPacketData challenge_packet = read_world_packet(socket.get(), nullptr, options.trace_world_packets);
    if (challenge_packet.opcode != SMSG_AUTH_CHALLENGE || challenge_packet.payload.size() != 40)
    {
        throw std::runtime_error("expected SMSG_AUTH_CHALLENGE from worldserver");
    }

    std::array<std::uint8_t, 4> server_seed{};
    std::copy_n(challenge_packet.payload.data() + 4, server_seed.size(), server_seed.begin());
    std::array<std::uint8_t, 4> local_challenge = random_seed4();
    auto addon_info = build_empty_addon_info();
    auto auth_payload = build_auth_session_payload(
        account,
        auth.session_key,
        server_seed,
        local_challenge,
        auth.realm.realm_id,
        addon_info);
    write_world_packet(socket.get(), CMSG_AUTH_SESSION, auth_payload, nullptr);

    AuthCrypt crypt;
    crypt.init(auth.session_key);

    CharacterFlowResult result;
    result.realm = auth.realm;

    bool authed = false;
    for (int i = 0; i < 10; ++i)
    {
        WorldPacketData packet = read_world_packet(socket.get(), &crypt, options.trace_world_packets);
        if (packet.opcode != SMSG_AUTH_RESPONSE)
        {
            result.skipped_auth_opcodes.push_back(packet.opcode);
            continue;
        }

        std::uint8_t const response = parse_auth_response(packet.payload);
        if (response != 0x0C)
        {
            throw std::runtime_error("world auth failed with response 0x" + hex(std::span<const std::uint8_t>(&response, 1)));
        }
        authed = true;
        break;
    }

    if (!authed)
    {
        throw std::runtime_error("did not receive SMSG_AUTH_RESPONSE");
    }

    write_world_packet(socket.get(), CMSG_CHAR_ENUM, {}, &crypt);
    for (int i = 0; i < 20; ++i)
    {
        WorldPacketData packet = read_world_packet(socket.get(), &crypt, options.trace_world_packets);
        if (packet.opcode != SMSG_CHAR_ENUM)
        {
            result.skipped_character_opcodes.push_back(packet.opcode);
            continue;
        }

        result.characters = parse_char_enum(packet.payload);
        return result;
    }

    throw std::runtime_error("did not receive SMSG_CHAR_ENUM");
}
}
