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
