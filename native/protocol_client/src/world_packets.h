#pragma once

#include "srp6.h"

#include <array>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

constexpr std::uint32_t CMSG_AUTH_SESSION = 0x1ED;
constexpr std::uint32_t CMSG_CHAR_ENUM = 0x037;
constexpr std::uint16_t SMSG_CHAR_ENUM = 0x03B;
constexpr std::size_t CharEnumEquipmentSlots = 23;

struct CharacterSummary
{
    std::uint64_t guid = 0;
    std::string name;
    std::uint8_t race = 0;
    std::uint8_t character_class = 0;
    std::uint8_t gender = 0;
    std::uint8_t level = 0;
    std::uint32_t zone = 0;
    std::uint32_t map = 0;
    float x = 0;
    float y = 0;
    float z = 0;
};

std::vector<std::uint8_t> build_empty_addon_info();
std::vector<std::uint8_t> build_auth_session_payload(
    std::string const& account,
    srp6::SessionKey const& session_key,
    std::array<std::uint8_t, 4> const& server_seed,
    std::array<std::uint8_t, 4> const& local_challenge,
    std::uint32_t realm_id,
    std::span<const std::uint8_t> addon_info);
std::vector<std::uint8_t> build_client_packet(std::uint32_t opcode, std::span<const std::uint8_t> payload);
std::vector<CharacterSummary> parse_char_enum(std::span<const std::uint8_t> payload);
bool world_packet_self_test();
