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
#include <chrono>
#include <cstring>
#include <cmath>
#include <iostream>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <thread>
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

    SocketFd& operator=(SocketFd&& other) noexcept
    {
        if (this != &other)
        {
            if (fd_ >= 0)
            {
                close(fd_);
            }
            fd_ = other.fd_;
            other.fd_ = -1;
        }
        return *this;
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

struct VendorBuyAttempt
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint64_t target_guid = 0;
    std::uint32_t target_entry = 0;
    bool live_target_found = false;
    bool target_has_position = false;
    bool approach_movement_sent = false;
    bool return_movement_sent = false;
    bool selection_sent = false;
    bool vendor_list_sent = false;
    bool vendor_list_response_seen = false;
    VendorListSummary vendor_list;
    bool buy_sent = false;
    bool buy_response_seen = false;
    std::uint16_t buy_response_opcode = 0;
    VendorBuyResponseSummary buy_response;
    std::vector<VisibleObjectSummary> visible_objects;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct VendorSellAttempt
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint64_t target_guid = 0;
    std::uint32_t target_entry = 0;
    bool live_target_found = false;
    bool target_has_position = false;
    bool approach_movement_sent = false;
    bool return_movement_sent = false;
    bool selection_sent = false;
    bool sell_sent = false;
    bool sell_error_seen = false;
    VendorSellErrorSummary sell_error;
    std::vector<VisibleObjectSummary> visible_objects;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct AuthenticatedWorldSession
{
    SocketFd socket;
    AuthCrypt crypt;
    RealmInfo realm;
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

std::uint64_t read_le_u64(std::span<const std::uint8_t> bytes, std::size_t offset)
{
    if (offset + 8 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint64");
    }

    std::uint64_t value = 0;
    for (int shift = 0; shift < 64; shift += 8)
    {
        value |= static_cast<std::uint64_t>(bytes[offset++]) << shift;
    }
    return value;
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

bool wait_for_socket_readable(int fd, int timeout_ms)
{
    while (true)
    {
        fd_set read_set;
        FD_ZERO(&read_set);
        FD_SET(fd, &read_set);

        timeval timeout{};
        timeout.tv_sec = timeout_ms / 1000;
        timeout.tv_usec = (timeout_ms % 1000) * 1000;

        int const rc = select(fd + 1, &read_set, nullptr, nullptr, &timeout);
        if (rc < 0 && errno == EINTR)
        {
            continue;
        }
        if (rc < 0)
        {
            throw std::runtime_error("socket select failed");
        }
        return rc > 0;
    }
}

std::optional<WorldPacketData> read_world_packet_optional(int fd, AuthCrypt* crypt, bool trace, int timeout_ms)
{
    if (!wait_for_socket_readable(fd, timeout_ms))
    {
        return std::nullopt;
    }
    return read_world_packet(fd, crypt, trace);
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

std::unique_ptr<AuthenticatedWorldSession> connect_authenticated_world(
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

    auto session = std::make_unique<AuthenticatedWorldSession>();
    session->socket = std::move(socket);
    session->realm = auth.realm;
    session->crypt.init(auth.session_key);

    bool authed = false;
    for (int i = 0; i < 10; ++i)
    {
        WorldPacketData packet = read_world_packet(session->socket.get(), &session->crypt, options.trace_world_packets);
        if (packet.opcode != SMSG_AUTH_RESPONSE)
        {
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

    return session;
}

std::vector<CharacterSummary> request_character_enum(AuthenticatedWorldSession& session, FlowOptions options, std::vector<std::uint16_t>* skipped)
{
    write_world_packet(session.socket.get(), CMSG_CHAR_ENUM, {}, &session.crypt);
    for (int i = 0; i < 20; ++i)
    {
        WorldPacketData packet = read_world_packet(session.socket.get(), &session.crypt, options.trace_world_packets);
        if (packet.opcode != SMSG_CHAR_ENUM)
        {
            if (skipped)
            {
                skipped->push_back(packet.opcode);
            }
            continue;
        }

        return parse_char_enum(packet.payload);
    }

    throw std::runtime_error("did not receive SMSG_CHAR_ENUM");
}

CharacterSummary select_character(std::vector<CharacterSummary> const& characters, std::string const& character_name)
{
    if (characters.empty())
    {
        throw std::runtime_error("account has no characters to enter world");
    }

    if (character_name.empty())
    {
        return characters[0];
    }

    for (CharacterSummary const& character : characters)
    {
        if (character.name == character_name)
        {
            return character;
        }
    }

    throw std::runtime_error("character not found: " + character_name);
}

std::uint32_t movement_timestamp_ms()
{
    auto now = std::chrono::steady_clock::now().time_since_epoch();
    return static_cast<std::uint32_t>(std::chrono::duration_cast<std::chrono::milliseconds>(now).count() & 0xFFFFFFFFu);
}

void answer_time_sync_request(AuthenticatedWorldSession& session, WorldPacketData const& packet)
{
    std::uint32_t const counter = parse_time_sync_counter(packet.payload);
    std::uint32_t const client_time = movement_timestamp_ms();
    write_world_packet(
        session.socket.get(),
        CMSG_TIME_SYNC_RESP,
        build_time_sync_response_payload(counter, client_time),
        &session.crypt);
}

float position_distance(CharacterSummary const& character, MovementSample const& movement)
{
    float const dx = character.x - movement.x;
    float const dy = character.y - movement.y;
    float const dz = character.z - movement.z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

float position_distance(LoginVerifyWorld const& login, MovementSample const& movement)
{
    float const dx = login.x - movement.x;
    float const dy = login.y - movement.y;
    float const dz = login.z - movement.z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

float position_distance(LoginVerifyWorld const& login, VisibleObjectSummary const& object)
{
    float const dx = login.x - object.x;
    float const dy = login.y - object.y;
    float const dz = login.z - object.z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

float facing_angle(float from_x, float from_y, float to_x, float to_y)
{
    constexpr float TwoPi = 6.28318530717958647692f;
    float angle = std::atan2(to_y - from_y, to_x - from_x);
    if (angle < 0.0f)
    {
        angle += TwoPi;
    }
    return angle;
}

void send_stepped_approach(
    AuthenticatedWorldSession& session,
    std::uint64_t player_guid,
    float start_x,
    float start_y,
    float start_z,
    float target_x,
    float target_y,
    float target_z,
    float stop_distance)
{
    float dx = target_x - start_x;
    float dy = target_y - start_y;
    float distance = std::sqrt(dx * dx + dy * dy);
    if (distance < 0.01f)
    {
        return;
    }

    float const travel = std::max(0.0f, distance - stop_distance);
    if (travel < 0.01f)
    {
        return;
    }

    float const direction_x = dx / distance;
    float const direction_y = dy / distance;
    float const orientation = facing_angle(start_x, start_y, target_x, target_y);
    float travelled = 0.0f;
    bool started = false;
    constexpr float StepDistance = 4.0f;

    while (travelled < travel)
    {
        travelled = std::min(travel, travelled + StepDistance);

        MovementSample movement;
        movement.flags = travelled < travel ? 0x00000001 : 0;
        movement.flags2 = 0;
        movement.time = movement_timestamp_ms();
        movement.x = start_x + direction_x * travelled;
        movement.y = start_y + direction_y * travelled;
        movement.z = target_z;
        movement.orientation = orientation;
        movement.fall_time = 0;

        if (!started)
        {
            MovementSample start = movement;
            start.flags = 0x00000001;
            start.x = start_x;
            start.y = start_y;
            start.z = start_z;
            write_world_packet(session.socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(player_guid, start), &session.crypt);
            started = true;
        }

        write_world_packet(
            session.socket.get(),
            movement.flags == 0 ? MSG_MOVE_STOP : MSG_MOVE_HEARTBEAT,
            build_movement_payload(player_guid, movement),
            &session.crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(450));
    }
}

std::uint16_t selector_high_guid(std::uint64_t selector)
{
    return static_cast<std::uint16_t>((selector >> 48) & 0xFFFF);
}

std::uint32_t target_entry_from_selector(std::uint64_t selector)
{
    if (selector <= 0x00FFFFFFu)
    {
        return static_cast<std::uint32_t>(selector);
    }

    std::uint16_t const high = selector_high_guid(selector);
    if (high == 0xF130 || high == 0xF140 || high == 0xF150 || high == 0xF110)
    {
        return static_cast<std::uint32_t>((selector >> 24) & 0x00FFFFFFu);
    }
    return 0;
}

bool selector_prefers_exact_guid(std::uint64_t selector)
{
    return selector > 0xFFFFFFFFu;
}

std::optional<VisibleObjectSummary> choose_visible_target(
    std::vector<VisibleObjectSummary> const& visible_objects,
    std::uint64_t selector,
    LoginVerifyWorld const& login)
{
    if (selector_prefers_exact_guid(selector))
    {
        for (VisibleObjectSummary const& object : visible_objects)
        {
            if (object.guid == selector)
            {
                return object;
            }
        }
    }

    std::uint32_t const target_entry = target_entry_from_selector(selector);
    if (target_entry == 0)
    {
        return std::nullopt;
    }

    std::optional<VisibleObjectSummary> best;
    float best_distance = 0;
    for (VisibleObjectSummary const& object : visible_objects)
    {
        if (object.object_type != 3 || object.entry != target_entry || !object.has_position)
        {
            continue;
        }

        float const distance = position_distance(login, object);
        if (!best || distance < best_distance)
        {
            best = object;
            best_distance = distance;
        }
    }
    return best;
}

bool is_combat_response_opcode(std::uint16_t opcode)
{
    switch (opcode)
    {
        case SMSG_ATTACKSTART:
        case SMSG_ATTACKSTOP:
        case SMSG_ATTACKSWING_NOTINRANGE:
        case SMSG_ATTACKSWING_BADFACING:
        case SMSG_ATTACKSWING_DEADTARGET:
        case SMSG_ATTACKSWING_CANT_ATTACK:
        case SMSG_ATTACKERSTATEUPDATE:
            return true;
        default:
            return false;
    }
}

std::uint32_t language_for_character(CharacterSummary const& character)
{
    switch (character.race)
    {
        case 2:  // orc
        case 5:  // undead
        case 6:  // tauren
        case 8:  // troll
        case 10: // blood elf
            return LANG_ORCISH;
        default:
            return LANG_COMMON;
    }
}

bool is_chat_response_opcode(std::uint16_t opcode)
{
    return opcode == SMSG_MESSAGECHAT || opcode == SMSG_GM_MESSAGECHAT;
}

bool is_spell_cast_response_opcode(std::uint16_t opcode)
{
    return opcode == SMSG_SPELL_START
        || opcode == SMSG_SPELL_GO
        || opcode == SMSG_CAST_FAILED
        || opcode == SMSG_SPELL_FAILURE
        || opcode == SMSG_SPELL_FAILED_OTHER;
}

bool parse_loot_release_response(
    std::span<const std::uint8_t> payload,
    std::uint64_t expected_guid,
    bool& success)
{
    if (payload.size() < 9)
    {
        return false;
    }
    std::uint64_t const guid = read_le_u64(payload, 0);
    if (expected_guid != 0 && guid != expected_guid)
    {
        return false;
    }
    success = payload[8] != 0;
    return true;
}

bool parse_loot_money_notify(
    std::span<const std::uint8_t> payload,
    std::uint32_t& amount,
    std::uint8_t& display_type)
{
    if (payload.size() < 5)
    {
        return false;
    }
    amount = read_le_u32(payload, 0);
    display_type = payload[4];
    return true;
}

void apply_corpse_target_update(CorpseLootProbeResult& result, VisibleObjectSummary const& object)
{
    if (object.guid != result.target_guid)
    {
        return;
    }

    if (object.has_position)
    {
        result.target_has_position = true;
        result.target_x = object.x;
        result.target_y = object.y;
        result.target_z = object.z;
    }
    if (object.health_seen)
    {
        result.target_health_seen = true;
        result.target_health = object.health;
        if (object.health == 0)
        {
            result.target_dead_seen = true;
        }
    }
    if (object.max_health_seen)
    {
        result.target_max_health_seen = true;
        result.target_max_health = object.max_health;
    }
    if (object.dynamic_flags_seen)
    {
        constexpr std::uint32_t UnitDynflagLootable = 0x0001;
        constexpr std::uint32_t UnitDynflagDead = 0x0020;
        result.target_dynamic_flags_seen = true;
        result.target_dynamic_flags = object.dynamic_flags;
        result.target_lootable_seen = (object.dynamic_flags & UnitDynflagLootable) != 0;
        if ((object.dynamic_flags & UnitDynflagDead) != 0)
        {
            result.target_dead_seen = true;
        }
    }
}

ActionButtonSummary action_button_at(ActionButtonsSummary const& summary, std::uint8_t button)
{
    if (button < summary.buttons.size())
    {
        return summary.buttons[button];
    }

    ActionButtonSummary empty;
    empty.button = button;
    return empty;
}

bool action_button_matches(ActionButtonSummary const& actual, ActionButtonSummary const& expected)
{
    if (!expected.populated)
    {
        return !actual.populated;
    }
    return actual.populated
        && actual.action == expected.action
        && actual.type == expected.type;
}

InventorySlotSummary* find_inventory_slot(PlayerInventorySummary& inventory, std::uint8_t slot)
{
    for (InventorySlotSummary& summary : inventory.slots)
    {
        if (summary.slot == slot)
        {
            return &summary;
        }
    }
    return nullptr;
}

InventorySlotSummary const* find_inventory_slot(PlayerInventorySummary const& inventory, std::uint8_t slot)
{
    for (InventorySlotSummary const& summary : inventory.slots)
    {
        if (summary.slot == slot)
        {
            return &summary;
        }
    }
    return nullptr;
}

InventorySlotSummary inventory_slot_at(PlayerInventorySummary const& inventory, std::uint8_t slot)
{
    if (InventorySlotSummary const* summary = find_inventory_slot(inventory, slot))
    {
        return *summary;
    }

    InventorySlotSummary empty;
    empty.slot = slot;
    if (slot < 19)
    {
        empty.section = 0;
    }
    else if (slot < 23)
    {
        empty.section = 1;
    }
    else
    {
        empty.section = 2;
    }
    return empty;
}

bool inventory_slot_matches(InventorySlotSummary const& actual, InventorySlotSummary const& expected)
{
    return actual.populated == expected.populated
        && actual.item_guid == expected.item_guid
        && (!expected.populated || actual.item_entry == expected.item_entry);
}

bool inventory_slot_changed(InventorySlotSummary const& before, InventorySlotSummary const& after)
{
    return before.populated != after.populated
        || before.item_guid != after.item_guid
        || before.item_entry != after.item_entry
        || before.stack_count != after.stack_count
        || before.durability != after.durability
        || before.max_durability != after.max_durability;
}

void ensure_inventory_slot(PlayerInventorySummary& inventory, InventorySlotSummary const& source)
{
    if (find_inventory_slot(inventory, source.slot) == nullptr)
    {
        inventory.slots.push_back(source);
    }
}

void refresh_inventory_counts(PlayerInventorySummary& inventory)
{
    inventory.populated_count = 0;
    inventory.item_detail_count = 0;
    inventory.item_template_count = 0;
    for (InventorySlotSummary const& slot : inventory.slots)
    {
        if (slot.populated)
        {
            ++inventory.populated_count;
        }
        if (slot.item_detail_seen)
        {
            ++inventory.item_detail_count;
        }
        if (slot.item_template_seen)
        {
            ++inventory.item_template_count;
        }
    }
}

void merge_inventory_summary(PlayerInventorySummary& target, PlayerInventorySummary const& source)
{
    if (!source.seen)
    {
        return;
    }

    target.seen = true;
    target.player_guid = source.player_guid != 0 ? source.player_guid : target.player_guid;
    if (source.coinage_seen)
    {
        target.coinage_seen = true;
        target.coinage = source.coinage;
    }

    for (InventorySlotSummary const& source_slot : source.slots)
    {
        ensure_inventory_slot(target, source_slot);
        InventorySlotSummary* target_slot = find_inventory_slot(target, source_slot.slot);
        if (!target_slot || !source_slot.field_seen)
        {
            continue;
        }

        bool const same_item = target_slot->item_guid == source_slot.item_guid;
        target_slot->section = source_slot.section;
        target_slot->field_seen = true;
        target_slot->populated = source_slot.populated;
        target_slot->item_guid = source_slot.item_guid;
        if (!same_item)
        {
            target_slot->item_entry = 0;
            target_slot->item_name.clear();
            target_slot->stack_count = 0;
            target_slot->durability = 0;
            target_slot->max_durability = 0;
            target_slot->item_detail_seen = false;
            target_slot->item_template_seen = false;
        }
    }

    std::sort(
        target.slots.begin(),
        target.slots.end(),
        [](InventorySlotSummary const& left, InventorySlotSummary const& right)
        {
            return left.slot < right.slot;
        });
    refresh_inventory_counts(target);
}

void apply_item_object_to_inventory(PlayerInventorySummary& inventory, InventoryItemObjectSummary const& item)
{
    if (!item.seen || item.guid == 0)
    {
        return;
    }

    for (InventorySlotSummary& slot : inventory.slots)
    {
        if (slot.item_guid != item.guid)
        {
            continue;
        }

        if (item.entry_seen)
        {
            slot.item_entry = item.entry;
        }
        if (item.stack_count_seen)
        {
            slot.stack_count = item.stack_count;
        }
        if (item.durability_seen)
        {
            slot.durability = item.durability;
        }
        if (item.max_durability_seen)
        {
            slot.max_durability = item.max_durability;
        }
        if (item.entry_seen)
        {
            slot.item_detail_seen = true;
        }
    }
    refresh_inventory_counts(inventory);
}

void apply_item_template_to_inventory(PlayerInventorySummary& inventory, ItemTemplateSummary const& item_template)
{
    if (!item_template.parsed || item_template.entry == 0)
    {
        return;
    }

    for (InventorySlotSummary& slot : inventory.slots)
    {
        if (slot.item_entry != item_template.entry)
        {
            continue;
        }
        slot.item_name = item_template.name;
        slot.item_template_seen = true;
    }
    refresh_inventory_counts(inventory);
}

std::vector<std::uint32_t> inventory_item_entries(PlayerInventorySummary const& inventory)
{
    std::vector<std::uint32_t> entries;
    for (InventorySlotSummary const& slot : inventory.slots)
    {
        if (slot.item_entry == 0)
        {
            continue;
        }
        if (std::find(entries.begin(), entries.end(), slot.item_entry) == entries.end())
        {
            entries.push_back(slot.item_entry);
        }
    }
    return entries;
}

std::optional<ItemTemplateSummary> query_item_template(
    AuthenticatedWorldSession& session,
    std::uint32_t item_entry,
    FlowOptions options,
    std::vector<std::uint16_t>& skipped_opcodes)
{
    write_world_packet(
        session.socket.get(),
        CMSG_ITEM_QUERY_SINGLE,
        build_item_query_single_payload(item_entry),
        &session.crypt);

    for (int i = 0; i < 40; ++i)
    {
        auto packet = read_world_packet_optional(
            session.socket.get(),
            &session.crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_ITEM_QUERY_SINGLE_RESPONSE)
        {
            ItemTemplateSummary item_template = parse_item_query_single_response(packet->payload);
            if (item_template.entry == item_entry)
            {
                return item_template;
            }
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        skipped_opcodes.push_back(packet->opcode);
    }

    return std::nullopt;
}

void validate_chat_message(std::string const& message)
{
    if (message.empty())
    {
        throw std::runtime_error("chat message must not be empty");
    }
    if (message.size() > 255)
    {
        throw std::runtime_error("chat message must be 255 bytes or shorter");
    }
    if (message.find_first_of("\n\r") != std::string::npos || message.find("|0") != std::string::npos)
    {
        throw std::runtime_error("chat message contains unsupported control text");
    }
}

LoginVerifyWorld login_selected_character(
    AuthenticatedWorldSession& session,
    CharacterSummary const& selected,
    FlowOptions options)
{
    write_world_packet(session.socket.get(), CMSG_PLAYER_LOGIN, build_player_login_payload(selected.guid), &session.crypt);
    auto const login_deadline = std::chrono::steady_clock::now() + std::chrono::seconds(15);
    while (std::chrono::steady_clock::now() < login_deadline)
    {
        WorldPacketData packet = read_world_packet(session.socket.get(), &session.crypt, options.trace_world_packets);
        if (packet.opcode == SMSG_LOGIN_VERIFY_WORLD)
        {
            return parse_login_verify_world(packet.payload);
        }
        if (packet.opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet.payload));
        }
    }

    throw std::runtime_error("did not receive SMSG_LOGIN_VERIFY_WORLD");
}

bool wait_for_logged_in_world(
    AuthenticatedWorldSession& session,
    FlowOptions options,
    int timeout_ms)
{
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session.socket.get(),
            &session.crypt,
            options.trace_world_packets,
            timeout_ms);
        if (!packet)
        {
            return false;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(session, *packet);
            return true;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
    }
    return false;
}

bool request_graceful_logout(AuthenticatedWorldSession& session, FlowOptions options)
{
    write_world_packet(session.socket.get(), CMSG_LOGOUT_REQUEST, {}, &session.crypt);
    bool logout_allowed = false;
    for (int i = 0; i < 40; ++i)
    {
        auto packet = read_world_packet_optional(
            session.socket.get(),
            &session.crypt,
            options.trace_world_packets,
            750);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_LOGOUT_RESPONSE)
        {
            logout_allowed = packet->payload.size() >= 5 && packet->payload[0] == 0;
            continue;
        }
        if (packet->opcode == SMSG_LOGOUT_COMPLETE)
        {
            return true;
        }
    }
    return logout_allowed;
}

bool send_set_action_button_once(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t button,
    std::uint32_t action,
    std::uint8_t type,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    bool const logged_in_world = wait_for_logged_in_world(*session, options, 650);
    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before setting action button");
    }

    write_world_packet(
        session->socket.get(),
        CMSG_SET_ACTION_BUTTON,
        build_set_action_button_payload(button, action, type),
        &session->crypt);

    (void)request_graceful_logout(*session, options);
    return true;
}

bool send_swap_inventory_item_once(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t source_slot,
    std::uint8_t destination_slot,
    FlowOptions options,
    std::vector<std::uint16_t>& skipped_opcodes)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    bool const logged_in_world = wait_for_logged_in_world(*session, options, 650);
    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before swapping inventory slots");
    }

    write_world_packet(
        session->socket.get(),
        CMSG_SWAP_INV_ITEM,
        build_swap_inventory_item_payload(source_slot, destination_slot),
        &session->crypt);

    bool failed = false;
    for (int i = 0; i < 24; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_INVENTORY_CHANGE_FAILURE)
        {
            failed = true;
            break;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return !failed;
}

bool send_split_item_once(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t source_slot,
    std::uint8_t destination_slot,
    std::uint32_t split_count,
    FlowOptions options,
    std::vector<std::uint16_t>& skipped_opcodes)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    bool const logged_in_world = wait_for_logged_in_world(*session, options, 650);
    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before splitting inventory stack");
    }

    write_world_packet(
        session->socket.get(),
        CMSG_SPLIT_ITEM,
        build_split_item_payload(255, source_slot, 255, destination_slot, split_count),
        &session->crypt);

    bool failed = false;
    for (int i = 0; i < 24; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_INVENTORY_CHANGE_FAILURE)
        {
            failed = true;
            break;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return !failed;
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
    auto session = connect_authenticated_world(host, port, account, password, options);
    CharacterFlowResult result;
    result.realm = session->realm;
    result.characters = request_character_enum(*session, options, &result.skipped_character_opcodes);
    return result;
}

CharacterCreateResult create_character(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& name,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    write_world_packet(session->socket.get(), CMSG_CHAR_CREATE, build_character_create_payload(name), &session->crypt);
    for (int i = 0; i < 20; ++i)
    {
        WorldPacketData packet = read_world_packet(session->socket.get(), &session->crypt, options.trace_world_packets);
        if (packet.opcode != SMSG_CHAR_CREATE)
        {
            continue;
        }
        if (packet.payload.empty())
        {
            throw std::runtime_error("SMSG_CHAR_CREATE payload is empty");
        }

        CharacterCreateResult result;
        result.realm = session->realm;
        result.name = name;
        result.response = packet.payload[0];
        result.success = result.response == 0x2F;
        result.characters = request_character_enum(*session, options, nullptr);
        return result;
    }

    throw std::runtime_error("did not receive SMSG_CHAR_CREATE");
}

EnterWorldResult enter_world(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);

    write_world_packet(session->socket.get(), CMSG_PLAYER_LOGIN, build_player_login_payload(selected.guid), &session->crypt);

    EnterWorldResult result;
    result.realm = session->realm;
    result.character = selected;
    bool verified_world = false;
    auto const world_deadline = std::chrono::steady_clock::now() + std::chrono::seconds(15);
    while (std::chrono::steady_clock::now() < world_deadline)
    {
        WorldPacketData packet = read_world_packet(session->socket.get(), &session->crypt, options.trace_world_packets);
        if (packet.opcode == SMSG_LOGIN_VERIFY_WORLD)
        {
            result.login = parse_login_verify_world(packet.payload);
            verified_world = true;
            continue;
        }
        if (packet.opcode == SMSG_UPDATE_OBJECT || packet.opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            result.update = parse_update_object_summary(
                packet.payload,
                packet.opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            if (verified_world)
            {
                return result;
            }
            continue;
        }
        if (packet.opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet.payload));
        }
        result.skipped_login_opcodes.push_back(packet.opcode);
        if (verified_world && result.skipped_login_opcodes.size() >= 20)
        {
            return result;
        }
    }

    if (!verified_world)
    {
        throw std::runtime_error("did not receive SMSG_LOGIN_VERIFY_WORLD");
    }
    return result;
}

VisibleTargetsSnapshotResult visible_targets_snapshot(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    VisibleTargetsSnapshotResult result;
    result.realm = session->realm;
    result.character = selected;
    result.login = login;

    int idle_after_login = 0;
    for (int i = 0; i < 120; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (result.logged_in_world)
            {
                ++idle_after_login;
                if ((idle_after_login >= 8 && !result.visible_objects.empty()) || idle_after_login >= 16)
                {
                    break;
                }
            }
            continue;
        }

        idle_after_login = 0;
        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            ++result.update_packet_count;
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            result.logged_in_world = true;
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }

        result.skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

MovementHeartbeatResult move_heartbeat(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    float delta_x,
    float delta_y,
    float delta_orientation,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);
    bool const logged_in_world = wait_for_logged_in_world(*session, options, 650);
    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before movement heartbeat");
    }

    MovementSample target;
    target.flags = 0;
    target.flags2 = 0;
    target.time = movement_timestamp_ms();
    target.x = login.x + delta_x;
    target.y = login.y + delta_y;
    target.z = login.z;
    target.orientation = login.orientation + delta_orientation;
    target.fall_time = 0;

    MovementSample start = target;
    start.flags = 0x00000001; // MOVEMENTFLAG_FORWARD
    start.time = movement_timestamp_ms();
    start.x = login.x;
    start.y = login.y;

    write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
    std::this_thread::sleep_for(std::chrono::milliseconds(250));
    target.time = movement_timestamp_ms();
    write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, target), &session->crypt);
    std::this_thread::sleep_for(std::chrono::milliseconds(650));
    (void)request_graceful_logout(*session, options);
    session.reset();

    std::this_thread::sleep_for(std::chrono::milliseconds(1500));
    EnterWorldResult live_check = enter_world(host, port, account, password, selected.name, options);
    float live_drift = position_distance(live_check.login, target);
    bool live_position_accepted = live_drift < 0.5f;

    CharacterFlowResult after_flow;
    CharacterSummary after;
    float saved_drift = 999.0f;
    bool saved_position_changed = false;
    for (int attempt = 0; attempt < 10; ++attempt)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(attempt == 0 ? 1500 : 750));
        after_flow = run_character_flow(host, port, account, password, options);
        after = select_character(after_flow.characters, selected.name);
        saved_drift = position_distance(after, target);
        saved_position_changed = std::fabs(after.x - selected.x) > 0.001f
            || std::fabs(after.y - selected.y) > 0.001f
            || std::fabs(after.z - selected.z) > 0.001f;
        if (saved_position_changed && saved_drift < 0.5f)
        {
            break;
        }
    }

    MovementHeartbeatResult result;
    result.realm = after_flow.realm;
    result.before = selected;
    result.target = target;
    result.live = live_check.login;
    result.after = after;
    result.live_position_accepted = live_position_accepted;
    result.saved_position_changed = saved_position_changed;
    result.live_drift = live_drift;
    result.saved_drift = saved_drift;
    return result;
}

InteractionResult interact_with_npc(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    InteractionResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before interaction");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_GOSSIP_HELLO, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.gossip_sent = true;

    for (int i = 0; i < 60; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_GOSSIP_MESSAGE)
        {
            result.gossip_response_seen = true;
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

TrainerListProbeResult trainer_list_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("trainer target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    TrainerListProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before trainer list probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_TRAINER_LIST, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.trainer_list_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_TRAINER_LIST)
        {
            result.trainer_list = parse_trainer_list_response(packet->payload);
            result.trainer_list_response_seen = result.trainer_list.parsed;
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

QuestGiverListProbeResult questgiver_list_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("questgiver target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    QuestGiverListProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before questgiver list probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_QUESTGIVER_HELLO, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.questgiver_hello_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_QUESTGIVER_QUEST_LIST)
        {
            result.quest_list = parse_questgiver_quest_list_response(packet->payload);
            result.quest_list_response_seen = result.quest_list.parsed;
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_GOSSIP_MESSAGE)
        {
            // Quest givers that also expose a gossip menu answer CMSG_QUESTGIVER_HELLO
            // with SMSG_GOSSIP_MESSAGE, carrying the offered quests embedded in the
            // packet. Parse those quests out of the gossip response.
            result.gossip = parse_gossip_message_response(packet->payload);
            result.gossip_fallback_seen = result.gossip.parsed;
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

QuestGiverDetailsProbeResult questgiver_details_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::uint32_t quest_id,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("questgiver target guid or entry must be non-zero");
    }
    if (quest_id == 0)
    {
        throw std::runtime_error("questgiver details probe requires a non-zero quest id");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    QuestGiverDetailsProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;
    result.query_quest_id = quest_id;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before questgiver details probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_QUESTGIVER_HELLO, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.questgiver_hello_sent = true;
    std::this_thread::sleep_for(std::chrono::milliseconds(250));
    write_world_packet(session->socket.get(), CMSG_QUESTGIVER_QUERY_QUEST, build_questgiver_query_quest_payload(result.target_guid, quest_id), &session->crypt);
    result.query_quest_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_QUESTGIVER_QUEST_DETAILS)
        {
            result.details = parse_questgiver_quest_details_response(packet->payload);
            result.details_response_seen = result.details.parsed;
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

QuestGiverAcceptProbeResult questgiver_accept_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::uint32_t quest_id,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("questgiver target guid or entry must be non-zero");
    }
    if (quest_id == 0)
    {
        throw std::runtime_error("questgiver accept probe requires a non-zero quest id");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    QuestGiverAcceptProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;
    result.quest_id = quest_id;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before questgiver accept probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_QUESTGIVER_HELLO, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.questgiver_hello_sent = true;
    std::this_thread::sleep_for(std::chrono::milliseconds(250));
    write_world_packet(session->socket.get(), CMSG_QUESTGIVER_ACCEPT_QUEST, build_questgiver_accept_quest_payload(result.target_guid, quest_id), &session->crypt);
    result.accept_sent = true;

    // Watch self value-updates for the accepted quest appearing in a quest-log slot.
    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            for (QuestLogSlotSummary const& slot : update.quest_log.slots)
            {
                if (slot.quest_id == quest_id)
                {
                    result.quest_in_log_after_accept = true;
                    result.accepted_slot = slot.slot;
                }
            }
            if (result.quest_in_log_after_accept)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_QUESTGIVER_QUEST_INVALID)
        {
            result.accept_response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    // Abandon the quest to restore the character's quest log to its prior state.
    if (result.quest_in_log_after_accept && result.accepted_slot >= 0)
    {
        write_world_packet(
            session->socket.get(),
            CMSG_QUESTLOG_REMOVE_QUEST,
            build_questlog_remove_quest_payload(static_cast<std::uint8_t>(result.accepted_slot)),
            &session->crypt);
        result.remove_sent = true;

        for (int i = 0; i < 80; ++i)
        {
            auto packet = read_world_packet_optional(
                session->socket.get(),
                &session->crypt,
                options.trace_world_packets,
                250);
            if (!packet)
            {
                continue;
            }
            if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
            {
                UpdateObjectSummary update = parse_update_object_summary(
                    packet->payload,
                    packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                    selected.guid);
                for (QuestLogSlotSummary const& slot : update.quest_log.slots)
                {
                    if (slot.slot == result.accepted_slot && slot.quest_id == 0)
                    {
                        result.quest_removed_after_remove = true;
                    }
                }
                if (result.quest_removed_after_remove)
                {
                    break;
                }
                continue;
            }
            if (packet->opcode == SMSG_TIME_SYNC_REQ)
            {
                answer_time_sync_request(*session, *packet);
                continue;
            }
            result.skipped_opcodes.push_back(packet->opcode);
        }
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

QuestGiverRewardProbeResult questgiver_reward_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::uint32_t quest_id,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("questgiver target guid or entry must be non-zero");
    }
    if (quest_id == 0)
    {
        throw std::runtime_error("questgiver reward probe requires a non-zero quest id");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    QuestGiverRewardProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;
    result.quest_id = quest_id;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before questgiver reward probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_QUESTGIVER_HELLO, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.questgiver_hello_sent = true;
    std::this_thread::sleep_for(std::chrono::milliseconds(250));

    // Put the quest in the log first so the completion request is meaningful.
    write_world_packet(session->socket.get(), CMSG_QUESTGIVER_ACCEPT_QUEST, build_questgiver_accept_quest_payload(result.target_guid, quest_id), &session->crypt);
    result.accept_sent = true;
    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload, packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT, selected.guid);
            for (QuestLogSlotSummary const& slot : update.quest_log.slots)
            {
                if (slot.quest_id == quest_id)
                {
                    result.quest_in_log_after_accept = true;
                    result.accepted_slot = slot.slot;
                }
            }
            if (result.quest_in_log_after_accept)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_QUESTGIVER_QUEST_INVALID)
        {
            result.quest_invalid_seen = true;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    // Ask the server for the completion screen (non-mutating). A completable quest
    // answers SMSG_QUESTGIVER_OFFER_REWARD; an incomplete one answers
    // SMSG_QUESTGIVER_REQUEST_ITEMS. We never send CMSG_QUESTGIVER_CHOOSE_REWARD,
    // so the quest is not turned in and stays abandonable.
    if (result.quest_in_log_after_accept)
    {
        write_world_packet(session->socket.get(), CMSG_QUESTGIVER_COMPLETE_QUEST, build_questgiver_complete_quest_payload(result.target_guid, quest_id), &session->crypt);
        result.complete_request_sent = true;
        for (int i = 0; i < 80; ++i)
        {
            auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
            if (!packet)
            {
                continue;
            }
            if (packet->opcode == SMSG_QUESTGIVER_OFFER_REWARD)
            {
                result.offer_reward = parse_questgiver_offer_reward_response(packet->payload);
                result.offer_reward_seen = result.offer_reward.parsed;
                result.response_opcode = packet->opcode;
                break;
            }
            if (packet->opcode == SMSG_QUESTGIVER_REQUEST_ITEMS)
            {
                result.request_items_seen = true;
                result.response_opcode = packet->opcode;
                break;
            }
            if (packet->opcode == SMSG_QUESTGIVER_QUEST_INVALID)
            {
                result.quest_invalid_seen = true;
                result.response_opcode = packet->opcode;
                break;
            }
            if (packet->opcode == SMSG_TIME_SYNC_REQ)
            {
                answer_time_sync_request(*session, *packet);
                continue;
            }
            result.skipped_opcodes.push_back(packet->opcode);
        }
    }

    // Abandon the quest to restore the character quest log to its prior state.
    if (result.quest_in_log_after_accept && result.accepted_slot >= 0)
    {
        write_world_packet(
            session->socket.get(),
            CMSG_QUESTLOG_REMOVE_QUEST,
            build_questlog_remove_quest_payload(static_cast<std::uint8_t>(result.accepted_slot)),
            &session->crypt);
        result.remove_sent = true;

        for (int i = 0; i < 80; ++i)
        {
            auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
            if (!packet)
            {
                continue;
            }
            if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
            {
                UpdateObjectSummary update = parse_update_object_summary(
                    packet->payload, packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT, selected.guid);
                for (QuestLogSlotSummary const& slot : update.quest_log.slots)
                {
                    if (slot.slot == result.accepted_slot && slot.quest_id == 0)
                    {
                        result.quest_removed_after_remove = true;
                    }
                }
                if (result.quest_removed_after_remove)
                {
                    break;
                }
                continue;
            }
            if (packet->opcode == SMSG_TIME_SYNC_REQ)
            {
                answer_time_sync_request(*session, *packet);
                continue;
            }
            result.skipped_opcodes.push_back(packet->opcode);
        }
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

VendorListProbeResult vendor_list_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("vendor target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    VendorListProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before vendor list probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_LIST_INVENTORY, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.vendor_list_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_LIST_INVENTORY)
        {
            result.vendor_list = parse_vendor_list_response(packet->payload);
            result.vendor_list_response_seen = result.vendor_list.parsed;
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

VendorBuyAttempt vendor_buy_item_once(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::uint32_t vendor_slot,
    std::uint32_t item_id,
    std::uint32_t count,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    VendorBuyAttempt result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(result.visible_objects.end(), update.visible_objects.begin(), update.visible_objects.end());
            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.live_target_found = true;
                }
            }
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before vendor buy");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    std::optional<VisibleObjectSummary> selected_target = choose_visible_target(result.visible_objects, result.target_guid, login);
    if (selected_target && selected_target->has_position)
    {
        float dx = login.x - selected_target->x;
        float dy = login.y - selected_target->y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }
        MovementSample start;
        start.flags = 0x00000001;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, selected_target->x, selected_target->y);

        MovementSample approach = start;
        approach.flags = 0;
        approach.x = selected_target->x + (dx / distance) * 1.5f;
        approach.y = selected_target->y + (dy / distance) * 1.5f;
        approach.z = selected_target->z;
        approach.orientation = facing_angle(approach.x, approach.y, selected_target->x, selected_target->y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_LIST_INVENTORY, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.vendor_list_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_LIST_INVENTORY)
        {
            result.vendor_list = parse_vendor_list_response(packet->payload);
            result.vendor_list_response_seen = result.vendor_list.parsed;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.vendor_list_response_seen)
    {
        write_world_packet(
            session->socket.get(),
            CMSG_BUY_ITEM,
            build_vendor_buy_item_payload(result.target_guid, item_id, vendor_slot, count),
            &session->crypt);
        result.buy_sent = true;

        for (int i = 0; i < 80; ++i)
        {
            auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
            if (!packet)
            {
                continue;
            }
            if (packet->opcode == SMSG_BUY_ITEM)
            {
                result.buy_response = parse_vendor_buy_response(packet->payload);
                result.buy_response.item_id = item_id;
                result.buy_response_seen = result.buy_response.parsed;
                result.buy_response_opcode = packet->opcode;
                break;
            }
            if (packet->opcode == SMSG_BUY_FAILED)
            {
                result.buy_response = parse_vendor_buy_failed_response(packet->payload);
                result.buy_response_seen = result.buy_response.parsed;
                result.buy_response_opcode = packet->opcode;
                break;
            }
            if (packet->opcode == SMSG_TIME_SYNC_REQ)
            {
                answer_time_sync_request(*session, *packet);
                continue;
            }
            if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
            {
                throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
            }
            result.skipped_opcodes.push_back(packet->opcode);
        }
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

VendorSellAttempt vendor_sell_item_once(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::uint64_t item_guid,
    std::uint32_t count,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    VendorSellAttempt result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(result.visible_objects.end(), update.visible_objects.begin(), update.visible_objects.end());
            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.live_target_found = true;
                }
            }
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before vendor sell");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    std::optional<VisibleObjectSummary> selected_target = choose_visible_target(result.visible_objects, result.target_guid, login);
    if (selected_target && selected_target->has_position)
    {
        float dx = login.x - selected_target->x;
        float dy = login.y - selected_target->y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }
        MovementSample start;
        start.flags = 0x00000001;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, selected_target->x, selected_target->y);

        MovementSample approach = start;
        approach.flags = 0;
        approach.x = selected_target->x + (dx / distance) * 1.5f;
        approach.y = selected_target->y + (dy / distance) * 1.5f;
        approach.z = selected_target->z;
        approach.orientation = facing_angle(approach.x, approach.y, selected_target->x, selected_target->y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(
        session->socket.get(),
        CMSG_SELL_ITEM,
        build_vendor_sell_item_payload(result.target_guid, item_guid, count),
        &session->crypt);
    result.sell_sent = true;

    for (int i = 0; i < 32; ++i)
    {
        auto packet = read_world_packet_optional(session->socket.get(), &session->crypt, options.trace_world_packets, 250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_SELL_ITEM)
        {
            result.sell_error = parse_vendor_sell_error_response(packet->payload);
            result.sell_error_seen = result.sell_error.parsed;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

std::optional<InventorySlotSummary> find_bought_inventory_slot(
    PlayerInventorySummary const& before,
    PlayerInventorySummary const& after,
    std::uint32_t item_id,
    std::uint32_t count)
{
    for (std::uint8_t slot = 0; slot < PlayerInventorySnapshotSlots; ++slot)
    {
        InventorySlotSummary before_slot = inventory_slot_at(before, slot);
        InventorySlotSummary after_slot = inventory_slot_at(after, slot);
        if (!after_slot.populated || after_slot.item_entry != item_id)
        {
            continue;
        }
        if (!before_slot.populated)
        {
            return after_slot;
        }
        if (before_slot.item_guid == after_slot.item_guid
            && after_slot.stack_count >= before_slot.stack_count + count)
        {
            return after_slot;
        }
        if (before_slot.item_guid != after_slot.item_guid)
        {
            return after_slot;
        }
    }
    return std::nullopt;
}

VendorBuySellProbeResult vendor_buy_sell_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    std::uint32_t vendor_slot,
    std::uint32_t item_id,
    std::uint32_t count,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("vendor target guid or entry must be non-zero");
    }
    if (vendor_slot == 0 || item_id == 0 || count == 0)
    {
        throw std::runtime_error("vendor buy/sell requires non-zero slot, item, and count");
    }

    VendorBuySellProbeResult result;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;
    result.vendor_slot = vendor_slot;
    result.item_id = item_id;
    result.count = count;

    InventorySnapshotResult before = read_inventory_snapshot(host, port, account, password, character_name, options);
    result.realm = before.realm;
    result.character = before.character;
    result.inventory_before = before.inventory;
    result.inventory_before_seen = before.inventory_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), before.skipped_opcodes.begin(), before.skipped_opcodes.end());
    if (!before.inventory_seen || before.inventory.slots.size() != PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("did not observe inventory before vendor buy/sell probe");
    }

    VendorBuyAttempt buy = vendor_buy_item_once(
        host,
        port,
        account,
        password,
        character_name,
        target_guid,
        vendor_slot,
        item_id,
        count,
        options);
    result.realm = buy.realm;
    result.character = buy.character;
    result.target_guid = buy.target_guid;
    result.target_entry = buy.target_entry;
    result.live_target_found = buy.live_target_found;
    result.target_has_position = buy.target_has_position;
    result.approach_movement_sent = buy.approach_movement_sent;
    result.return_movement_sent = buy.return_movement_sent;
    result.selection_sent = buy.selection_sent;
    result.vendor_list_sent = buy.vendor_list_sent;
    result.vendor_list_response_seen = buy.vendor_list_response_seen;
    result.vendor_list = buy.vendor_list;
    result.buy_sent = buy.buy_sent;
    result.buy_response_seen = buy.buy_response_seen;
    result.buy_response = buy.buy_response;
    result.buy_response_opcode = buy.buy_response_opcode;
    result.visible_objects = buy.visible_objects;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), buy.skipped_opcodes.begin(), buy.skipped_opcodes.end());
    if (!buy.buy_response_seen || !buy.buy_response.succeeded)
    {
        return result;
    }

    InventorySnapshotResult after_buy = read_inventory_snapshot(host, port, account, password, character_name, options);
    result.inventory_after_buy = after_buy.inventory;
    result.inventory_after_buy_seen = after_buy.inventory_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_buy.skipped_opcodes.begin(), after_buy.skipped_opcodes.end());
    if (!after_buy.inventory_seen || after_buy.inventory.slots.size() != PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("did not observe inventory after vendor buy");
    }

    std::optional<InventorySlotSummary> bought_slot = find_bought_inventory_slot(before.inventory, after_buy.inventory, item_id, count);
    if (!bought_slot)
    {
        return result;
    }
    result.bought_item_found = true;
    result.bought_slot_after_buy = *bought_slot;
    result.bought_slot_before = inventory_slot_at(before.inventory, bought_slot->slot);

    VendorSellAttempt sell = vendor_sell_item_once(
        host,
        port,
        account,
        password,
        character_name,
        result.target_guid,
        bought_slot->item_guid,
        count,
        options);
    result.sell_sent = sell.sell_sent;
    result.sell_error_seen = sell.sell_error_seen;
    result.sell_error = sell.sell_error;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), sell.skipped_opcodes.begin(), sell.skipped_opcodes.end());

    InventorySnapshotResult after_sell = read_inventory_snapshot(host, port, account, password, character_name, options);
    result.inventory_after_sell = after_sell.inventory;
    result.inventory_after_sell_seen = after_sell.inventory_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_sell.skipped_opcodes.begin(), after_sell.skipped_opcodes.end());
    if (!after_sell.inventory_seen || after_sell.inventory.slots.size() != PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("did not observe inventory after vendor sell");
    }

    result.bought_slot_after_sell = inventory_slot_at(after_sell.inventory, bought_slot->slot);
    result.sell_confirmed = sell.sell_sent
        && !sell.sell_error_seen
        && !inventory_slot_changed(result.bought_slot_before, result.bought_slot_after_sell);

    result.coinage_before_seen = before.inventory.coinage_seen;
    result.coinage_after_buy_seen = after_buy.inventory.coinage_seen;
    result.coinage_after_sell_seen = after_sell.inventory.coinage_seen;
    if (result.coinage_before_seen && result.coinage_after_buy_seen)
    {
        result.buy_coinage_delta = static_cast<std::int64_t>(after_buy.inventory.coinage)
            - static_cast<std::int64_t>(before.inventory.coinage);
    }
    if (result.coinage_after_buy_seen && result.coinage_after_sell_seen)
    {
        result.sell_coinage_delta = static_cast<std::int64_t>(after_sell.inventory.coinage)
            - static_cast<std::int64_t>(after_buy.inventory.coinage);
    }
    if (result.coinage_before_seen && result.coinage_after_sell_seen)
    {
        result.roundtrip_coinage_delta = static_cast<std::int64_t>(after_sell.inventory.coinage)
            - static_cast<std::int64_t>(before.inventory.coinage);
    }
    result.roundtrip_confirmed = result.sell_confirmed
        && result.buy_coinage_delta < 0
        && result.sell_coinage_delta > 0
        && result.roundtrip_coinage_delta < 0;
    return result;
}

TrainerBuySpellProbeResult trainer_buy_spell_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    std::uint32_t spell_id,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("trainer target guid or entry must be non-zero");
    }
    if (spell_id == 0)
    {
        throw std::runtime_error("trainer spell id must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    TrainerBuySpellProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;
    result.spell_id = spell_id;

    bool logged_in_world = false;
    for (int i = 0; i < 160; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before trainer buy probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_TRAINER_LIST, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.trainer_list_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_TRAINER_LIST)
        {
            result.trainer_list = parse_trainer_list_response(packet->payload);
            result.trainer_list_response_seen = result.trainer_list.parsed;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.trainer_list_response_seen)
    {
        write_world_packet(
            session->socket.get(),
            CMSG_TRAINER_BUY_SPELL,
            build_trainer_buy_spell_payload(result.target_guid, spell_id),
            &session->crypt);
        result.buy_spell_sent = true;

        for (int i = 0; i < 80; ++i)
        {
            auto packet = read_world_packet_optional(
                session->socket.get(),
                &session->crypt,
                options.trace_world_packets,
                250);
            if (!packet)
            {
                continue;
            }
            if (packet->opcode == SMSG_TRAINER_BUY_SUCCEEDED)
            {
                result.buy_response = parse_trainer_buy_succeeded_response(packet->payload);
                result.buy_response_seen = result.buy_response.parsed;
                result.response_opcode = packet->opcode;
                break;
            }
            if (packet->opcode == SMSG_TRAINER_BUY_FAILED)
            {
                result.buy_response = parse_trainer_buy_failed_response(packet->payload);
                result.buy_response_seen = result.buy_response.parsed;
                result.response_opcode = packet->opcode;
                break;
            }
            if (packet->opcode == SMSG_TIME_SYNC_REQ)
            {
                answer_time_sync_request(*session, *packet);
                continue;
            }
            if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
            {
                throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
            }
            result.skipped_opcodes.push_back(packet->opcode);
        }
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

CombatProbeResult combat_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("combat target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    CombatProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    bool logged_in_world = false;
    for (int i = 0; i < 180; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before combat probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001; // MOVEMENTFLAG_FORWARD
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = login.orientation;
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_ATTACKSWING, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.attack_sent = true;

    auto const combat_deadline = std::chrono::steady_clock::now() + std::chrono::seconds(15);
    while (std::chrono::steady_clock::now() < combat_deadline)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_ATTACKERSTATEUPDATE)
        {
            result.attacker_state_update = parse_attacker_state_update(packet->payload);
            result.attacker_state_update_seen = result.attacker_state_update.parsed;
            result.combat_response_seen = true;
            result.response_opcode = packet->opcode;
            break;
        }
        if (is_combat_response_opcode(packet->opcode))
        {
            result.combat_response_seen = true;
            if (result.response_opcode == 0)
            {
                result.response_opcode = packet->opcode;
            }
            if (packet->opcode != SMSG_ATTACKSTART && packet->opcode != SMSG_ATTACKSTOP)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    write_world_packet(session->socket.get(), CMSG_ATTACKSTOP, {}, &session->crypt);
    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }
    (void)request_graceful_logout(*session, options);
    return result;
}

ChatSayResult chat_say(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::string const& message,
    FlowOptions options)
{
    validate_chat_message(message);

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    bool const logged_in_world = wait_for_logged_in_world(*session, options, 650);
    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before chat");
    }

    ChatSayResult result;
    result.realm = session->realm;
    result.character = selected;
    result.message = message;
    result.language = language_for_character(selected);

    write_world_packet(session->socket.get(), CMSG_MESSAGECHAT, build_chat_say_payload(result.language, message), &session->crypt);
    result.message_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (is_chat_response_opcode(packet->opcode))
        {
            ChatMessageSummary chat = parse_chat_message_summary(
                packet->payload,
                packet->opcode == SMSG_GM_MESSAGECHAT);
            result.chat_response_seen = true;
            result.response_opcode = packet->opcode;
            result.chat_type = chat.chat_type;
            result.language = chat.language;
            result.sender_guid = chat.sender_guid;
            result.receiver_guid = chat.receiver_guid;
            result.received_message = chat.message;
            result.echoed_message_seen = chat.message == message;
            if (result.echoed_message_seen)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

ChatSayResult chat_whisper_self(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::string const& message,
    FlowOptions options)
{
    validate_chat_message(message);

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    bool const logged_in_world = wait_for_logged_in_world(*session, options, 650);
    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before whisper");
    }

    ChatSayResult result;
    result.realm = session->realm;
    result.character = selected;
    result.message = message;
    result.language = language_for_character(selected);

    write_world_packet(
        session->socket.get(),
        CMSG_MESSAGECHAT,
        build_chat_whisper_payload(result.language, selected.name, message),
        &session->crypt);
    result.message_sent = true;

    for (int i = 0; i < 80; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (is_chat_response_opcode(packet->opcode))
        {
            ChatMessageSummary chat = parse_chat_message_summary(
                packet->payload,
                packet->opcode == SMSG_GM_MESSAGECHAT);
            result.chat_response_seen = true;
            result.response_opcode = packet->opcode;
            result.chat_type = chat.chat_type;
            result.language = chat.language;
            result.sender_guid = chat.sender_guid;
            result.receiver_guid = chat.receiver_guid;
            result.received_message = chat.message;
            if (chat.message == message && chat.chat_type == CHAT_MSG_WHISPER)
            {
                result.whisper_seen = true;
            }
            if (chat.message == message && chat.chat_type == CHAT_MSG_WHISPER_INFORM)
            {
                result.whisper_inform_seen = true;
            }
            result.echoed_message_seen = result.whisper_seen && result.whisper_inform_seen;
            if (result.echoed_message_seen)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

SpellbookResult read_initial_spellbook(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    SpellbookResult result;
    result.realm = session->realm;
    result.character = selected;

    for (int i = 0; i < 180; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (result.initial_spells_seen && result.logged_in_world)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_INITIAL_SPELLS)
        {
            result.spellbook = parse_initial_spells_summary(packet->payload);
            result.initial_spells_seen = result.spellbook.seen;
            if (result.logged_in_world)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            result.logged_in_world = true;
            if (result.initial_spells_seen)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

ActionButtonsResult read_action_buttons(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    ActionButtonsResult result;
    result.realm = session->realm;
    result.character = selected;

    for (int i = 0; i < 180; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (result.action_buttons_seen && result.logged_in_world)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_ACTION_BUTTONS)
        {
            result.action_buttons = parse_action_buttons_summary(packet->payload);
            result.action_buttons_seen = result.action_buttons.seen;
            if (result.logged_in_world)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            result.logged_in_world = true;
            if (result.action_buttons_seen)
            {
                break;
            }
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

InventorySnapshotResult read_inventory_snapshot(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options)
{
    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    InventorySnapshotResult result;
    result.realm = session->realm;
    result.character = selected;

    int idle_after_ready = 0;
    for (int i = 0; i < 260; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (result.inventory_seen && result.logged_in_world)
            {
                ++idle_after_ready;
                bool const all_details_seen = result.inventory.populated_count > 0
                    && result.inventory.item_detail_count >= result.inventory.populated_count;
                if (all_details_seen || idle_after_ready >= 20)
                {
                    break;
                }
            }
            continue;
        }
        idle_after_ready = 0;
        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            if (update.inventory.seen)
            {
                merge_inventory_summary(result.inventory, update.inventory);
                result.inventory_seen = true;
            }
            for (InventoryItemObjectSummary const& item : update.inventory_items)
            {
                apply_item_object_to_inventory(result.inventory, item);
            }
            continue;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            result.logged_in_world = true;
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    for (std::uint32_t item_entry : inventory_item_entries(result.inventory))
    {
        std::optional<ItemTemplateSummary> item_template = query_item_template(
            *session,
            item_entry,
            options,
            result.skipped_opcodes);
        if (item_template)
        {
            apply_item_template_to_inventory(result.inventory, *item_template);
        }
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

InventorySwapProbeResult swap_inventory_slots_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t source_slot,
    std::uint8_t destination_slot,
    FlowOptions options)
{
    if (source_slot == destination_slot)
    {
        throw std::runtime_error("source and destination inventory slots must be different");
    }
    if (source_slot >= PlayerInventorySnapshotSlots || destination_slot >= PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("inventory slots must be from 0 to 38");
    }

    InventorySwapProbeResult result;
    result.source_slot = source_slot;
    result.destination_slot = destination_slot;

    InventorySnapshotResult before = read_inventory_snapshot(host, port, account, password, character_name, options);
    result.realm = before.realm;
    result.character = before.character;
    result.before_seen = before.inventory_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), before.skipped_opcodes.begin(), before.skipped_opcodes.end());
    if (!before.inventory_seen || before.inventory.slots.size() != PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("did not observe inventory before swap probe");
    }

    result.source_before = inventory_slot_at(before.inventory, source_slot);
    result.destination_before = inventory_slot_at(before.inventory, destination_slot);
    if (!result.source_before.populated)
    {
        throw std::runtime_error("source inventory slot is empty; refusing to run swap probe");
    }

    result.swap_sent = send_swap_inventory_item_once(
        host,
        port,
        account,
        password,
        character_name,
        source_slot,
        destination_slot,
        options,
        result.skipped_opcodes);

    InventorySnapshotResult after_swap;
    try
    {
        after_swap = read_inventory_snapshot(host, port, account, password, character_name, options);
    }
    catch (...)
    {
        (void)send_swap_inventory_item_once(
            host,
            port,
            account,
            password,
            character_name,
            destination_slot,
            source_slot,
            options,
            result.skipped_opcodes);
        throw;
    }

    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_swap.skipped_opcodes.begin(), after_swap.skipped_opcodes.end());
    result.source_after_swap = inventory_slot_at(after_swap.inventory, source_slot);
    result.destination_after_swap = inventory_slot_at(after_swap.inventory, destination_slot);
    result.swap_confirmed = result.swap_sent
        && after_swap.inventory_seen
        && inventory_slot_matches(result.source_after_swap, result.destination_before)
        && inventory_slot_matches(result.destination_after_swap, result.source_before);

    if (!result.swap_confirmed)
    {
        if (result.destination_after_swap.item_guid == result.source_before.item_guid)
        {
            (void)send_swap_inventory_item_once(
                host,
                port,
                account,
                password,
                character_name,
                destination_slot,
                source_slot,
                options,
                result.skipped_opcodes);
        }
        throw std::runtime_error("inventory swap was sent but not confirmed by the next inventory snapshot");
    }

    result.restore_sent = send_swap_inventory_item_once(
        host,
        port,
        account,
        password,
        character_name,
        destination_slot,
        source_slot,
        options,
        result.skipped_opcodes);

    InventorySnapshotResult after_restore = read_inventory_snapshot(host, port, account, password, character_name, options);
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_restore.skipped_opcodes.begin(), after_restore.skipped_opcodes.end());
    result.source_after_restore = inventory_slot_at(after_restore.inventory, source_slot);
    result.destination_after_restore = inventory_slot_at(after_restore.inventory, destination_slot);
    result.restore_confirmed = result.restore_sent
        && after_restore.inventory_seen
        && inventory_slot_matches(result.source_after_restore, result.source_before)
        && inventory_slot_matches(result.destination_after_restore, result.destination_before);

    return result;
}

InventorySplitProbeResult split_inventory_stack_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t source_slot,
    std::uint8_t destination_slot,
    std::uint32_t split_count,
    FlowOptions options)
{
    if (source_slot == destination_slot)
    {
        throw std::runtime_error("source and destination inventory slots must be different");
    }
    if (source_slot >= PlayerInventorySnapshotSlots || destination_slot >= PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("inventory slots must be from 0 to 38");
    }
    if (split_count == 0)
    {
        throw std::runtime_error("split count must be greater than zero");
    }

    InventorySplitProbeResult result;
    result.source_slot = source_slot;
    result.destination_slot = destination_slot;
    result.split_count = split_count;

    InventorySnapshotResult before = read_inventory_snapshot(host, port, account, password, character_name, options);
    result.realm = before.realm;
    result.character = before.character;
    result.before_seen = before.inventory_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), before.skipped_opcodes.begin(), before.skipped_opcodes.end());
    if (!before.inventory_seen || before.inventory.slots.size() != PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("did not observe inventory before split probe");
    }

    result.source_before = inventory_slot_at(before.inventory, source_slot);
    result.destination_before = inventory_slot_at(before.inventory, destination_slot);
    if (!result.source_before.populated)
    {
        throw std::runtime_error("source inventory slot is empty; refusing to run split probe");
    }
    if (result.destination_before.populated)
    {
        throw std::runtime_error("destination inventory slot is not empty; refusing to run split probe");
    }
    if (result.source_before.stack_count <= split_count)
    {
        throw std::runtime_error("source inventory stack is not large enough for a reversible split probe");
    }

    result.split_sent = send_split_item_once(
        host,
        port,
        account,
        password,
        character_name,
        source_slot,
        destination_slot,
        split_count,
        options,
        result.skipped_opcodes);

    InventorySnapshotResult after_split;
    try
    {
        after_split = read_inventory_snapshot(host, port, account, password, character_name, options);
    }
    catch (...)
    {
        (void)send_swap_inventory_item_once(
            host,
            port,
            account,
            password,
            character_name,
            destination_slot,
            source_slot,
            options,
            result.skipped_opcodes);
        throw;
    }

    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_split.skipped_opcodes.begin(), after_split.skipped_opcodes.end());
    result.source_after_split = inventory_slot_at(after_split.inventory, source_slot);
    result.destination_after_split = inventory_slot_at(after_split.inventory, destination_slot);
    result.split_confirmed = result.split_sent
        && after_split.inventory_seen
        && result.source_after_split.populated
        && result.source_after_split.item_guid == result.source_before.item_guid
        && result.source_after_split.item_entry == result.source_before.item_entry
        && result.source_after_split.stack_count + split_count == result.source_before.stack_count
        && result.destination_after_split.populated
        && result.destination_after_split.item_entry == result.source_before.item_entry
        && result.destination_after_split.stack_count == split_count;

    if (!result.split_confirmed)
    {
        if (result.destination_after_split.populated
            && result.destination_after_split.item_entry == result.source_before.item_entry)
        {
            (void)send_swap_inventory_item_once(
                host,
                port,
                account,
                password,
                character_name,
                destination_slot,
                source_slot,
                options,
                result.skipped_opcodes);
        }
        throw std::runtime_error("inventory split was sent but not confirmed by the next inventory snapshot");
    }

    result.merge_sent = send_swap_inventory_item_once(
        host,
        port,
        account,
        password,
        character_name,
        destination_slot,
        source_slot,
        options,
        result.skipped_opcodes);

    InventorySnapshotResult after_merge = read_inventory_snapshot(host, port, account, password, character_name, options);
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_merge.skipped_opcodes.begin(), after_merge.skipped_opcodes.end());
    result.source_after_merge = inventory_slot_at(after_merge.inventory, source_slot);
    result.destination_after_merge = inventory_slot_at(after_merge.inventory, destination_slot);
    result.merge_confirmed = result.merge_sent
        && after_merge.inventory_seen
        && inventory_slot_matches(result.source_after_merge, result.source_before)
        && inventory_slot_matches(result.destination_after_merge, result.destination_before);

    return result;
}

SetActionButtonProbeResult set_action_button_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t button,
    std::uint32_t action,
    std::uint8_t type,
    FlowOptions options)
{
    if (button >= MaxActionButtons)
    {
        throw std::runtime_error("action button must be less than 144");
    }
    if (action >= 0x01000000u)
    {
        throw std::runtime_error("action id must fit in 24 bits");
    }

    SetActionButtonProbeResult result;
    result.button = button;
    result.action = action;
    result.type = type;

    ActionButtonsResult before = read_action_buttons(host, port, account, password, character_name, options);
    result.realm = before.realm;
    result.character = before.character;
    result.before_seen = before.action_buttons_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), before.skipped_opcodes.begin(), before.skipped_opcodes.end());
    if (!before.action_buttons_seen || before.action_buttons.buttons.size() != MaxActionButtons)
    {
        throw std::runtime_error("did not observe action buttons before set probe");
    }
    result.original = action_button_at(before.action_buttons, button);

    result.set_sent = send_set_action_button_once(
        host,
        port,
        account,
        password,
        character_name,
        button,
        action,
        type,
        options);

    std::uint32_t restore_action = result.original.populated ? result.original.action : 0;
    std::uint8_t restore_type = result.original.populated ? result.original.type : 0;

    ActionButtonsResult after_set;
    try
    {
        after_set = read_action_buttons(host, port, account, password, character_name, options);
    }
    catch (...)
    {
        (void)send_set_action_button_once(
            host,
            port,
            account,
            password,
            character_name,
            button,
            restore_action,
            restore_type,
            options);
        throw;
    }
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_set.skipped_opcodes.begin(), after_set.skipped_opcodes.end());
    result.after_set = action_button_at(after_set.action_buttons, button);
    result.set_confirmed = after_set.action_buttons_seen
        && result.after_set.populated
        && result.after_set.action == action
        && result.after_set.type == type;

    result.restore_sent = send_set_action_button_once(
        host,
        port,
        account,
        password,
        character_name,
        button,
        restore_action,
        restore_type,
        options);

    ActionButtonsResult after_restore = read_action_buttons(host, port, account, password, character_name, options);
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after_restore.skipped_opcodes.begin(), after_restore.skipped_opcodes.end());
    result.after_restore = action_button_at(after_restore.action_buttons, button);
    result.restore_confirmed = after_restore.action_buttons_seen
        && action_button_matches(result.after_restore, result.original);

    return result;
}

SpellCastProbeResult cast_spell_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint32_t spell_id,
    FlowOptions options)
{
    if (spell_id == 0)
    {
        throw std::runtime_error("spell id must be positive");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    (void)login_selected_character(*session, selected, options);

    SpellCastProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.spell_id = spell_id;

    result.logged_in_world = wait_for_logged_in_world(*session, options, 650);
    if (!result.logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before spell cast");
    }

    write_world_packet(
        session->socket.get(),
        CMSG_CAST_SPELL,
        build_cast_spell_payload(1, spell_id, 0, 0),
        &session->crypt);
    result.cast_sent = true;

    for (int i = 0; i < 100; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (is_spell_cast_response_opcode(packet->opcode))
        {
            try
            {
                SpellCastResponseSummary response = parse_spell_cast_response(packet->opcode, packet->payload);
                if (response.spell_id == spell_id)
                {
                    result.response = response;
                    result.response_seen = true;
                    result.accepted = response.spell_start || response.spell_go;
                    if (response.spell_go || response.cast_failed || response.spell_failure)
                    {
                        break;
                    }
                    continue;
                }
            }
            catch (std::exception const&)
            {
                // Keep scanning; packet opcode evidence is retained below.
            }
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

TargetedSpellCastProbeResult cast_spell_at_target_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint32_t spell_id,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (spell_id == 0)
    {
        throw std::runtime_error("spell id must be positive");
    }
    if (target_guid == 0)
    {
        throw std::runtime_error("target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    TargetedSpellCastProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.spell_id = spell_id;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    for (int i = 0; i < 180; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (result.logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            result.logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!result.logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before targeted spell cast");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_ATTACKSWING, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.attack_sent = true;
    write_world_packet(
        session->socket.get(),
        CMSG_CAST_SPELL,
        build_cast_spell_unit_payload(1, spell_id, 0, result.target_guid),
        &session->crypt);
    result.cast_sent = true;

    for (int i = 0; i < 100; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (is_spell_cast_response_opcode(packet->opcode))
        {
            try
            {
                SpellCastResponseSummary response = parse_spell_cast_response(packet->opcode, packet->payload);
                if (response.spell_id == spell_id)
                {
                    result.response = response;
                    result.response_seen = true;
                    result.accepted = response.spell_start || response.spell_go;
                    if (response.spell_go || response.cast_failed || response.spell_failure)
                    {
                        break;
                    }
                    continue;
                }
            }
            catch (std::exception const&)
            {
                // Keep scanning; packet opcode evidence is retained below.
            }
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    write_world_packet(session->socket.get(), CMSG_ATTACKSTOP, {}, &session->crypt);
    (void)request_graceful_logout(*session, options);
    return result;
}

LootOpenProbeResult loot_open_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("loot target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    LootOpenProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    bool logged_in_world = false;
    for (int i = 0; i < 180; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_has_position = target->has_position;
                    result.target_x = target->x;
                    result.target_y = target->y;
                    result.target_z = target->z;
                    result.live_target_found = true;
                }
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before loot probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    if (result.target_has_position)
    {
        float dx = login.x - result.target_x;
        float dy = login.y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }

        MovementSample start;
        start.flags = 0x00000001;
        start.flags2 = 0;
        start.time = movement_timestamp_ms();
        start.x = login.x;
        start.y = login.y;
        start.z = login.z;
        start.orientation = facing_angle(start.x, start.y, result.target_x, result.target_y);
        start.fall_time = 0;

        MovementSample approach = start;
        approach.flags = 0;
        approach.time = movement_timestamp_ms();
        approach.x = result.target_x + (dx / distance) * 1.5f;
        approach.y = result.target_y + (dy / distance) * 1.5f;
        approach.z = result.target_z;
        approach.orientation = facing_angle(approach.x, approach.y, result.target_x, result.target_y);

        write_world_packet(session->socket.get(), MSG_MOVE_START_FORWARD, build_movement_payload(selected.guid, start), &session->crypt);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        approach.time = movement_timestamp_ms();
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, approach), &session->crypt);
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_LOOT, build_loot_payload(result.target_guid), &session->crypt);
    result.loot_open_sent = true;

    for (int i = 0; i < 60; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            continue;
        }
        if (packet->opcode == SMSG_LOOT_RESPONSE)
        {
            result.loot = parse_loot_response(packet->payload);
            result.loot_response_seen = result.loot.parsed;
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_LOOT_RELEASE_RESPONSE)
        {
            result.loot_release_response_seen = parse_loot_release_response(
                packet->payload,
                result.target_guid,
                result.loot_release_success);
            result.response_opcode = packet->opcode;
            break;
        }
        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    if (result.loot_response_seen && !result.loot.error)
    {
        write_world_packet(session->socket.get(), CMSG_LOOT_RELEASE, build_loot_release_payload(result.target_guid), &session->crypt);
        result.loot_release_sent = true;
        for (int i = 0; i < 40; ++i)
        {
            auto packet = read_world_packet_optional(
                session->socket.get(),
                &session->crypt,
                options.trace_world_packets,
                250);
            if (!packet)
            {
                continue;
            }
            if (packet->opcode == SMSG_LOOT_RELEASE_RESPONSE)
            {
                result.loot_release_response_seen = parse_loot_release_response(
                    packet->payload,
                    result.target_guid,
                    result.loot_release_success);
                break;
            }
            if (packet->opcode == SMSG_TIME_SYNC_REQ)
            {
                answer_time_sync_request(*session, *packet);
                continue;
            }
            if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
            {
                throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
            }
            result.skipped_opcodes.push_back(packet->opcode);
        }
    }

    if (result.approach_movement_sent)
    {
        MovementSample back;
        back.flags = 0;
        back.flags2 = 0;
        back.time = movement_timestamp_ms();
        back.x = login.x;
        back.y = login.y;
        back.z = login.z;
        back.orientation = login.orientation;
        back.fall_time = 0;
        write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
        result.return_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    (void)request_graceful_logout(*session, options);
    return result;
}

CorpseLootProbeResult corpse_loot_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("corpse loot target guid or entry must be non-zero");
    }

    auto session = connect_authenticated_world(host, port, account, password, options);
    std::vector<CharacterSummary> characters = request_character_enum(*session, options, nullptr);
    CharacterSummary selected = select_character(characters, character_name);
    LoginVerifyWorld login = login_selected_character(*session, selected, options);

    CorpseLootProbeResult result;
    result.realm = session->realm;
    result.character = selected;
    result.target_entry = target_entry_from_selector(target_guid);
    result.target_name = target_name;

    bool logged_in_world = false;
    for (int i = 0; i < 180; ++i)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            if (logged_in_world)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());

            if (!result.live_target_found)
            {
                std::optional<VisibleObjectSummary> target = choose_visible_target(result.visible_objects, target_guid, login);
                if (target)
                {
                    result.target_guid = target->guid;
                    result.target_entry = target->entry;
                    result.target_name = target_name;
                    result.live_target_found = true;
                    apply_corpse_target_update(result, *target);
                }
            }
            for (VisibleObjectSummary const& object : update.visible_objects)
            {
                apply_corpse_target_update(result, object);
            }
            continue;
        }

        if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            logged_in_world = true;
            if (result.live_target_found)
            {
                break;
            }
            continue;
        }

        if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        result.skipped_opcodes.push_back(packet->opcode);
    }

    auto stop_and_return = [&]()
    {
        if (result.attack_sent && !result.attack_stop_sent)
        {
            write_world_packet(session->socket.get(), CMSG_ATTACKSTOP, {}, &session->crypt);
            result.attack_stop_sent = true;
        }

        if (result.approach_movement_sent && !result.return_movement_sent)
        {
            MovementSample back;
            back.flags = 0;
            back.flags2 = 0;
            back.time = movement_timestamp_ms();
            back.x = login.x;
            back.y = login.y;
            back.z = login.z;
            back.orientation = login.orientation;
            back.fall_time = 0;
            write_world_packet(session->socket.get(), MSG_MOVE_STOP, build_movement_payload(selected.guid, back), &session->crypt);
            result.return_movement_sent = true;
            std::this_thread::sleep_for(std::chrono::milliseconds(250));
        }
    };

    if (!logged_in_world)
    {
        throw std::runtime_error("did not receive post-login SMSG_TIME_SYNC_REQ before corpse loot probe");
    }
    if (!result.live_target_found)
    {
        (void)request_graceful_logout(*session, options);
        return result;
    }

    float current_x = login.x;
    float current_y = login.y;
    float current_z = login.z;
    auto update_current_stop_point = [&]()
    {
        float dx = current_x - result.target_x;
        float dy = current_y - result.target_y;
        float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < 0.01f)
        {
            dx = 1.0f;
            dy = 0.0f;
            distance = 1.0f;
        }
        current_x = result.target_x + (dx / distance) * 1.5f;
        current_y = result.target_y + (dy / distance) * 1.5f;
        current_z = result.target_z;
    };

    if (result.target_has_position)
    {
        send_stepped_approach(
            *session,
            selected.guid,
            login.x,
            login.y,
            login.z,
            result.target_x,
            result.target_y,
            result.target_z,
            1.5f);
        update_current_stop_point();
        result.approach_movement_sent = true;
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    }

    write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.selection_sent = true;
    write_world_packet(session->socket.get(), CMSG_ATTACKSWING, build_raw_guid_payload(result.target_guid), &session->crypt);
    result.attack_sent = true;

    auto last_attack_sent = std::chrono::steady_clock::now();
    auto last_approach_sent = last_attack_sent;
    auto const combat_deadline = std::chrono::steady_clock::now() + std::chrono::seconds(120);
    auto maintain_combat = [&]()
    {
        auto const now = std::chrono::steady_clock::now();
        if (result.loot_open_sent || result.target_dead_seen)
        {
            return;
        }
        if (result.target_has_position && now - last_approach_sent > std::chrono::seconds(6))
        {
            send_stepped_approach(
                *session,
                selected.guid,
                current_x,
                current_y,
                current_z,
                result.target_x,
                result.target_y,
                result.target_z,
                1.5f);
            update_current_stop_point();
            last_approach_sent = std::chrono::steady_clock::now();
        }
        if (now - last_attack_sent > std::chrono::seconds(3))
        {
            write_world_packet(session->socket.get(), CMSG_SET_SELECTION, build_raw_guid_payload(result.target_guid), &session->crypt);
            write_world_packet(session->socket.get(), CMSG_ATTACKSWING, build_raw_guid_payload(result.target_guid), &session->crypt);
            last_attack_sent = std::chrono::steady_clock::now();
        }
    };

    while (std::chrono::steady_clock::now() < combat_deadline)
    {
        auto packet = read_world_packet_optional(
            session->socket.get(),
            &session->crypt,
            options.trace_world_packets,
            250);
        if (!packet)
        {
            maintain_combat();
            continue;
        }

        if (packet->opcode == SMSG_UPDATE_OBJECT || packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT)
        {
            UpdateObjectSummary update = parse_update_object_summary(
                packet->payload,
                packet->opcode == SMSG_COMPRESSED_UPDATE_OBJECT,
                selected.guid);
            result.visible_objects.insert(
                result.visible_objects.end(),
                update.visible_objects.begin(),
                update.visible_objects.end());
            for (VisibleObjectSummary const& object : update.visible_objects)
            {
                apply_corpse_target_update(result, object);
            }
        }
        else if (packet->opcode == SMSG_ATTACKERSTATEUPDATE)
        {
            result.attacker_state_update = parse_attacker_state_update(packet->payload);
            if (result.attacker_state_update.parsed)
            {
                ++result.attacker_state_update_count;
                result.total_damage += result.attacker_state_update.total_damage;
                if (result.response_opcode == 0)
                {
                    result.response_opcode = packet->opcode;
                }
            }
        }
        else if (packet->opcode == SMSG_TIME_SYNC_REQ)
        {
            answer_time_sync_request(*session, *packet);
            continue;
        }
        else if (packet->opcode == SMSG_CHARACTER_LOGIN_FAILED)
        {
            throw std::runtime_error("character login failed with response 0x" + hex(packet->payload));
        }
        else
        {
            result.skipped_opcodes.push_back(packet->opcode);
        }

        if (!result.loot_open_sent && (result.target_lootable_seen || result.target_dead_seen))
        {
            if (!result.attack_stop_sent)
            {
                write_world_packet(session->socket.get(), CMSG_ATTACKSTOP, {}, &session->crypt);
                result.attack_stop_sent = true;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            write_world_packet(session->socket.get(), CMSG_LOOT, build_loot_payload(result.target_guid), &session->crypt);
            result.loot_open_sent = true;
        }

        maintain_combat();

        if (packet->opcode == SMSG_LOOT_RESPONSE)
        {
            result.loot = parse_loot_response(packet->payload);
            result.loot_response_seen = result.loot.parsed;
            result.response_opcode = packet->opcode;
            if (!result.loot_response_seen || result.loot.error)
            {
                break;
            }

            if (result.loot.gold > 0)
            {
                write_world_packet(session->socket.get(), CMSG_LOOT_MONEY, {}, &session->crypt);
                result.loot_money_sent = true;
            }
            for (LootItemSummary const& item : result.loot.items)
            {
                write_world_packet(
                    session->socket.get(),
                    CMSG_AUTOSTORE_LOOT_ITEM,
                    build_autostore_loot_item_payload(item.slot),
                    &session->crypt);
                ++result.loot_item_pickup_sent_count;
            }

            write_world_packet(session->socket.get(), CMSG_LOOT_RELEASE, build_loot_release_payload(result.target_guid), &session->crypt);
            result.loot_release_sent = true;
            auto const loot_deadline = std::chrono::steady_clock::now() + std::chrono::seconds(8);
            while (std::chrono::steady_clock::now() < loot_deadline)
            {
                auto loot_packet = read_world_packet_optional(
                    session->socket.get(),
                    &session->crypt,
                    options.trace_world_packets,
                    250);
                if (!loot_packet)
                {
                    continue;
                }
                if (loot_packet->opcode == SMSG_LOOT_MONEY_NOTIFY)
                {
                    result.loot_money_notify_seen = parse_loot_money_notify(
                        loot_packet->payload,
                        result.loot_money_amount,
                        result.loot_money_display_type);
                    continue;
                }
                if (loot_packet->opcode == SMSG_LOOT_REMOVED)
                {
                    ++result.loot_item_removed_count;
                    continue;
                }
                if (loot_packet->opcode == SMSG_LOOT_RELEASE_RESPONSE)
                {
                    result.loot_release_response_seen = parse_loot_release_response(
                        loot_packet->payload,
                        result.target_guid,
                        result.loot_release_success);
                    break;
                }
                if (loot_packet->opcode == SMSG_TIME_SYNC_REQ)
                {
                    answer_time_sync_request(*session, *loot_packet);
                    continue;
                }
                result.skipped_opcodes.push_back(loot_packet->opcode);
            }
            break;
        }

        if (packet->opcode == SMSG_LOOT_RELEASE_RESPONSE)
        {
            result.loot_release_response_seen = parse_loot_release_response(
                packet->payload,
                result.target_guid,
                result.loot_release_success);
            result.response_opcode = packet->opcode;
            break;
        }
    }

    stop_and_return();
    (void)request_graceful_logout(*session, options);
    return result;
}

LootInventoryHandoffResult loot_inventory_handoff_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options)
{
    if (target_guid == 0)
    {
        throw std::runtime_error("loot inventory target guid or entry must be non-zero");
    }

    LootInventoryHandoffResult result;

    InventorySnapshotResult before = read_inventory_snapshot(
        host,
        port,
        account,
        password,
        character_name,
        options);
    result.realm = before.realm;
    result.character = before.character;
    result.inventory_before = before.inventory;
    result.inventory_before_seen = before.inventory_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), before.skipped_opcodes.begin(), before.skipped_opcodes.end());
    if (!before.inventory_seen || before.inventory.slots.size() != PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("did not observe inventory before loot handoff probe");
    }

    result.corpse_loot = corpse_loot_probe(
        host,
        port,
        account,
        password,
        character_name,
        target_guid,
        target_name,
        options);
    result.realm = result.corpse_loot.realm;
    result.character = result.corpse_loot.character;
    result.skipped_opcodes.insert(
        result.skipped_opcodes.end(),
        result.corpse_loot.skipped_opcodes.begin(),
        result.corpse_loot.skipped_opcodes.end());

    InventorySnapshotResult after = read_inventory_snapshot(
        host,
        port,
        account,
        password,
        character_name,
        options);
    result.inventory_after = after.inventory;
    result.inventory_after_seen = after.inventory_seen;
    result.skipped_opcodes.insert(result.skipped_opcodes.end(), after.skipped_opcodes.begin(), after.skipped_opcodes.end());
    if (!after.inventory_seen || after.inventory.slots.size() != PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error("did not observe inventory after loot handoff probe");
    }

    for (std::uint8_t slot = 0; slot < PlayerInventorySnapshotSlots; ++slot)
    {
        InventorySlotSummary before_slot = inventory_slot_at(before.inventory, slot);
        InventorySlotSummary after_slot = inventory_slot_at(after.inventory, slot);
        if (!inventory_slot_changed(before_slot, after_slot))
        {
            continue;
        }

        result.changed_slots.push_back(after_slot);
        ++result.changed_slot_count;
        if (!before_slot.populated && after_slot.populated)
        {
            ++result.added_slot_count;
        }
        else if (before_slot.populated && !after_slot.populated)
        {
            ++result.removed_slot_count;
        }
        else if (before_slot.populated
            && after_slot.populated
            && before_slot.item_guid == after_slot.item_guid
            && before_slot.stack_count != after_slot.stack_count)
        {
            ++result.stack_changed_slot_count;
        }
    }

    if (before.inventory.coinage_seen && after.inventory.coinage_seen)
    {
        result.coinage_delta = static_cast<std::int64_t>(after.inventory.coinage)
            - static_cast<std::int64_t>(before.inventory.coinage);
        result.coinage_changed = result.coinage_delta != 0;
    }

    bool const loot_window_ok = result.corpse_loot.loot_response_seen && !result.corpse_loot.loot.error;
    bool const item_expected = !result.corpse_loot.loot.items.empty();
    bool const money_expected = result.corpse_loot.loot.gold > 0;
    bool const inventory_changed = result.changed_slot_count > 0 || result.coinage_delta > 0;
    result.handoff_confirmed = result.inventory_before_seen
        && result.inventory_after_seen
        && loot_window_ok
        && (item_expected || money_expected)
        && inventory_changed;

    return result;
}
}
