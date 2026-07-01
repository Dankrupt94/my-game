#include "world_packets.h"

#include "protocol_bytes.h"

#include <openssl/evp.h>
#include <zlib.h>

#include <algorithm>
#include <cstring>
#include <memory>
#include <stdexcept>

namespace
{
using MdPtr = std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)>;

void append_u8(std::vector<std::uint8_t>& bytes, std::uint8_t value)
{
    bytes.push_back(value);
}

void append_u32_le(std::vector<std::uint8_t>& bytes, std::uint32_t value)
{
    bytes.push_back(static_cast<std::uint8_t>(value & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    bytes.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}

void append_u64_le(std::vector<std::uint8_t>& bytes, std::uint64_t value)
{
    for (int shift = 0; shift < 64; shift += 8)
    {
        bytes.push_back(static_cast<std::uint8_t>((value >> shift) & 0xFF));
    }
}

void append_packed_guid(std::vector<std::uint8_t>& bytes, std::uint64_t value)
{
    std::uint8_t mask = 0;
    std::array<std::uint8_t, 8> guid_bytes{};
    for (int i = 0; i < 8; ++i)
    {
        guid_bytes[i] = static_cast<std::uint8_t>((value >> (i * 8)) & 0xFF);
        if (guid_bytes[i] != 0)
        {
            mask |= static_cast<std::uint8_t>(1 << i);
        }
    }

    append_u8(bytes, mask);
    for (int i = 0; i < 8; ++i)
    {
        if ((mask & (1 << i)) != 0)
        {
            append_u8(bytes, guid_bytes[i]);
        }
    }
}

void append_float_le(std::vector<std::uint8_t>& bytes, float value)
{
    static_assert(sizeof(float) == sizeof(std::uint32_t));
    std::uint32_t raw = 0;
    std::memcpy(&raw, &value, sizeof(raw));
    append_u32_le(bytes, raw);
}

std::uint8_t read_u8(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    if (offset + 1 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint8");
    }
    return bytes[offset++];
}

std::uint32_t read_u32_le(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    if (offset + 4 > bytes.size())
    {
        throw std::runtime_error("not enough bytes for uint32");
    }
    std::uint32_t value = static_cast<std::uint32_t>(bytes[offset])
        | (static_cast<std::uint32_t>(bytes[offset + 1]) << 8)
        | (static_cast<std::uint32_t>(bytes[offset + 2]) << 16)
        | (static_cast<std::uint32_t>(bytes[offset + 3]) << 24);
    offset += 4;
    return value;
}

std::uint64_t read_u64_le(std::span<const std::uint8_t> bytes, std::size_t& offset)
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

std::uint64_t read_packed_guid(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    std::uint8_t const mask = read_u8(bytes, offset);
    std::uint64_t value = 0;
    for (int i = 0; i < 8; ++i)
    {
        if ((mask & (1 << i)) != 0)
        {
            value |= static_cast<std::uint64_t>(read_u8(bytes, offset)) << (i * 8);
        }
    }
    return value;
}

float read_float_le(std::span<const std::uint8_t> bytes, std::size_t& offset)
{
    std::uint32_t raw = read_u32_le(bytes, offset);
    float value = 0;
    std::memcpy(&value, &raw, sizeof(value));
    return value;
}

void skip_bytes(std::span<const std::uint8_t> bytes, std::size_t& offset, std::size_t count)
{
    if (offset + count > bytes.size())
    {
        throw std::runtime_error("not enough bytes to skip field");
    }
    offset += count;
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
        throw std::runtime_error("unterminated character name");
    }
    std::string value(reinterpret_cast<char const*>(bytes.data() + start), offset - start);
    ++offset;
    return value;
}

std::array<std::uint8_t, 20> sha1(std::initializer_list<std::span<const std::uint8_t>> parts)
{
    MdPtr ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!ctx || EVP_DigestInit_ex(ctx.get(), EVP_sha1(), nullptr) != 1)
    {
        throw std::runtime_error("SHA1 init failed");
    }
    for (auto part : parts)
    {
        if (EVP_DigestUpdate(ctx.get(), part.data(), part.size()) != 1)
        {
            throw std::runtime_error("SHA1 update failed");
        }
    }
    std::array<std::uint8_t, 20> digest{};
    unsigned int len = 0;
    if (EVP_DigestFinal_ex(ctx.get(), digest.data(), &len) != 1 || len != digest.size())
    {
        throw std::runtime_error("SHA1 final failed");
    }
    return digest;
}

void append_synthetic_character(std::vector<std::uint8_t>& payload)
{
    append_u64_le(payload, 0x0000000000001234ULL);
    payload.insert(payload.end(), {'S', 'a', 'f', 'e', 'T', 'e', 's', 't', 0});
    append_u8(payload, 1);  // race
    append_u8(payload, 1);  // class
    append_u8(payload, 0);  // gender
    append_u8(payload, 2);  // skin
    append_u8(payload, 3);  // face
    append_u8(payload, 4);  // hair style
    append_u8(payload, 5);  // hair color
    append_u8(payload, 0);  // facial hair
    append_u8(payload, 80); // level
    append_u32_le(payload, 12);
    append_u32_le(payload, 0);
    append_float_le(payload, -8949.95f);
    append_float_le(payload, -132.493f);
    append_float_le(payload, 83.5312f);
    append_u32_le(payload, 0); // guild
    append_u32_le(payload, 0); // char flags
    append_u32_le(payload, 0); // customize flags
    append_u8(payload, 0);     // first login
    append_u32_le(payload, 0); // pet display
    append_u32_le(payload, 0); // pet level
    append_u32_le(payload, 0); // pet family
    for (std::size_t slot = 0; slot < CharEnumEquipmentSlots; ++slot)
    {
        append_u32_le(payload, 0);
        append_u8(payload, 0);
        append_u32_le(payload, 0);
    }
}

std::vector<std::uint8_t> inflate_update_payload(std::span<const std::uint8_t> payload, std::uint32_t& uncompressed_size)
{
    if (payload.size() < 4)
    {
        throw std::runtime_error("compressed update object payload is too short");
    }

    std::size_t offset = 0;
    uncompressed_size = read_u32_le(payload, offset);
    std::vector<std::uint8_t> inflated(uncompressed_size);
    uLongf destination_size = inflated.size();
    int const result = uncompress(
        inflated.data(),
        &destination_size,
        payload.data() + offset,
        payload.size() - offset);
    if (result != Z_OK || destination_size != inflated.size())
    {
        throw std::runtime_error("could not inflate compressed update object payload");
    }
    return inflated;
}
}

std::vector<std::uint8_t> build_empty_addon_info()
{
    std::vector<std::uint8_t> plain;
    append_u32_le(plain, 0); // addon count
    append_u32_le(plain, 0); // current time

    uLongf compressed_size = compressBound(plain.size());
    std::vector<std::uint8_t> compressed(compressed_size);
    int const result = compress2(compressed.data(), &compressed_size, plain.data(), plain.size(), Z_BEST_SPEED);
    if (result != Z_OK)
    {
        throw std::runtime_error("addon info compression failed");
    }
    compressed.resize(compressed_size);

    std::vector<std::uint8_t> packet;
    append_u32_le(packet, static_cast<std::uint32_t>(plain.size()));
    packet.insert(packet.end(), compressed.begin(), compressed.end());
    return packet;
}

std::vector<std::uint8_t> build_auth_session_payload(
    std::string const& account,
    srp6::SessionKey const& session_key,
    std::array<std::uint8_t, 4> const& server_seed,
    std::array<std::uint8_t, 4> const& local_challenge,
    std::uint32_t realm_id,
    std::span<const std::uint8_t> addon_info)
{
    static constexpr std::array<std::uint8_t, 4> zeros{0, 0, 0, 0};
    auto digest = sha1({
        std::span<const std::uint8_t>(reinterpret_cast<std::uint8_t const*>(account.data()), account.size()),
        zeros,
        local_challenge,
        server_seed,
        session_key,
    });

    std::vector<std::uint8_t> payload;
    append_u32_le(payload, 12340);
    append_u32_le(payload, 0);
    payload.insert(payload.end(), account.begin(), account.end());
    append_u8(payload, 0);
    append_u32_le(payload, 0);
    payload.insert(payload.end(), local_challenge.begin(), local_challenge.end());
    append_u32_le(payload, 0);
    append_u32_le(payload, 0);
    append_u32_le(payload, realm_id);
    append_u64_le(payload, 0);
    payload.insert(payload.end(), digest.begin(), digest.end());
    payload.insert(payload.end(), addon_info.begin(), addon_info.end());
    return payload;
}

std::vector<std::uint8_t> build_character_create_payload(std::string const& name)
{
    if (name.empty() || name.size() > 12)
    {
        throw std::runtime_error("character name must be 1 to 12 bytes");
    }

    std::vector<std::uint8_t> payload;
    payload.insert(payload.end(), name.begin(), name.end());
    append_u8(payload, 0);
    append_u8(payload, 1); // human
    append_u8(payload, 1); // warrior
    append_u8(payload, 0); // male
    append_u8(payload, 0); // skin
    append_u8(payload, 0); // face
    append_u8(payload, 0); // hair style
    append_u8(payload, 0); // hair color
    append_u8(payload, 0); // facial hair
    append_u8(payload, 0); // outfit id; AzerothCore ignores this on create.
    return payload;
}

std::vector<std::uint8_t> build_player_login_payload(std::uint64_t character_guid)
{
    std::vector<std::uint8_t> payload;
    append_u64_le(payload, character_guid);
    return payload;
}

std::vector<std::uint8_t> build_movement_payload(std::uint64_t character_guid, MovementSample const& movement)
{
    std::vector<std::uint8_t> payload;
    append_packed_guid(payload, character_guid);
    append_u32_le(payload, movement.flags);
    payload.push_back(static_cast<std::uint8_t>(movement.flags2 & 0xFF));
    payload.push_back(static_cast<std::uint8_t>((movement.flags2 >> 8) & 0xFF));
    append_u32_le(payload, movement.time);
    append_float_le(payload, movement.x);
    append_float_le(payload, movement.y);
    append_float_le(payload, movement.z);
    append_float_le(payload, movement.orientation);
    append_u32_le(payload, movement.fall_time);
    return payload;
}

std::vector<std::uint8_t> build_client_packet(std::uint32_t opcode, std::span<const std::uint8_t> payload)
{
    std::vector<std::uint8_t> packet = build_client_header(opcode, payload.size());
    packet.insert(packet.end(), payload.begin(), payload.end());
    return packet;
}

std::vector<CharacterSummary> parse_char_enum(std::span<const std::uint8_t> payload)
{
    std::size_t offset = 0;
    std::uint8_t const count = read_u8(payload, offset);
    std::vector<CharacterSummary> characters;
    characters.reserve(count);

    for (std::uint8_t i = 0; i < count; ++i)
    {
        CharacterSummary character;
        character.guid = read_u64_le(payload, offset);
        character.name = read_c_string(payload, offset);
        character.race = read_u8(payload, offset);
        character.character_class = read_u8(payload, offset);
        character.gender = read_u8(payload, offset);
        skip_bytes(payload, offset, 5); // skin, face, hair style, hair color, facial hair
        character.level = read_u8(payload, offset);
        character.zone = read_u32_le(payload, offset);
        character.map = read_u32_le(payload, offset);
        character.x = read_float_le(payload, offset);
        character.y = read_float_le(payload, offset);
        character.z = read_float_le(payload, offset);
        skip_bytes(payload, offset, 4);  // guild id
        skip_bytes(payload, offset, 4);  // character flags
        skip_bytes(payload, offset, 4);  // customize flags
        skip_bytes(payload, offset, 1);  // first login
        skip_bytes(payload, offset, 12); // pet display, level, family

        std::size_t const equipment_bytes = CharEnumEquipmentSlots * (4 + 1 + 4);
        if (offset + equipment_bytes > payload.size())
        {
            throw std::runtime_error("character enum equipment block is incomplete");
        }
        offset += equipment_bytes;

        characters.push_back(std::move(character));
    }

    if (offset != payload.size())
    {
        throw std::runtime_error("character enum parser left trailing bytes");
    }
    return characters;
}

LoginVerifyWorld parse_login_verify_world(std::span<const std::uint8_t> payload)
{
    if (payload.size() != 20)
    {
        throw std::runtime_error("SMSG_LOGIN_VERIFY_WORLD payload must be 20 bytes");
    }

    std::size_t offset = 0;
    LoginVerifyWorld position;
    position.map = read_u32_le(payload, offset);
    position.x = read_float_le(payload, offset);
    position.y = read_float_le(payload, offset);
    position.z = read_float_le(payload, offset);
    position.orientation = read_float_le(payload, offset);
    return position;
}

UpdateObjectSummary parse_update_object_summary(
    std::span<const std::uint8_t> payload,
    bool compressed,
    std::uint64_t player_guid)
{
    UpdateObjectSummary summary;
    summary.seen = true;
    summary.compressed = compressed;
    summary.payload_size = payload.size();

    std::vector<std::uint8_t> inflated;
    std::span<const std::uint8_t> body = payload;
    if (compressed)
    {
        inflated = inflate_update_payload(payload, summary.uncompressed_size);
        body = inflated;
    }

    std::size_t offset = 0;
    summary.block_count = read_u32_le(body, offset);
    if (summary.block_count == 0 || offset >= body.size())
    {
        return summary;
    }

    summary.first_update_type = read_u8(body, offset);
    if (summary.first_update_type == 2 || summary.first_update_type == 3 || summary.first_update_type == 0 || summary.first_update_type == 1)
    {
        summary.first_guid = read_packed_guid(body, offset);
        summary.contains_player_guid = summary.first_guid == player_guid;
    }
    return summary;
}

bool world_packet_self_test()
{
    srp6::SessionKey session_key{};
    std::array<std::uint8_t, 4> server_seed{1, 2, 3, 4};
    std::array<std::uint8_t, 4> local_challenge{5, 6, 7, 8};
    auto addon_info = build_empty_addon_info();
    auto auth_payload = build_auth_session_payload("TEST", session_key, server_seed, local_challenge, 1, addon_info);
    auto auth_packet = build_client_packet(CMSG_AUTH_SESSION, auth_payload);
    if (auth_packet.size() != auth_payload.size() + 6)
    {
        return false;
    }
    if (auth_packet[2] != 0xED || auth_packet[3] != 0x01)
    {
        return false;
    }

    auto char_enum_packet = build_client_packet(CMSG_CHAR_ENUM, {});
    if (hex(char_enum_packet) != "000437000000")
    {
        return false;
    }

    auto login_packet = build_client_packet(CMSG_PLAYER_LOGIN, build_player_login_payload(0x1234));
    if (login_packet.size() != 14 || login_packet[2] != 0x3D)
    {
        return false;
    }

    MovementSample movement;
    movement.x = -8949.95f;
    movement.y = -132.493f;
    movement.z = 83.5312f;
    auto movement_packet = build_client_packet(MSG_MOVE_HEARTBEAT, build_movement_payload(0x1234, movement));
    if (movement_packet.size() != 6 + 1 + 2 + 4 + 2 + 4 + 16 + 4 || movement_packet[2] != 0xEE)
    {
        return false;
    }

    auto create_payload = build_character_create_payload("Codextest");
    if (create_payload.empty() || create_payload.back() != 0)
    {
        return false;
    }

    std::vector<std::uint8_t> login_verify;
    append_u32_le(login_verify, 0);
    append_float_le(login_verify, -8949.95f);
    append_float_le(login_verify, -132.493f);
    append_float_le(login_verify, 83.5312f);
    append_float_le(login_verify, 0.1f);
    auto verify = parse_login_verify_world(login_verify);
    if (verify.map != 0 || verify.z < 83.0f)
    {
        return false;
    }

    std::vector<std::uint8_t> char_payload;
    append_u8(char_payload, 1);
    append_synthetic_character(char_payload);
    auto characters = parse_char_enum(char_payload);
    bool rejected_truncation = false;
    try
    {
        std::vector<std::uint8_t> truncated{1, 0x34, 0x12};
        (void)parse_char_enum(truncated);
    }
    catch (std::exception const&)
    {
        rejected_truncation = true;
    }

    return rejected_truncation
        && characters.size() == 1
        && characters[0].guid == 0x1234
        && characters[0].name == "SafeTest"
        && characters[0].level == 80
        && characters[0].zone == 12
        && characters[0].map == 0;
}
