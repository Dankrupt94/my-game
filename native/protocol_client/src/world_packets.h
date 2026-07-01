#pragma once

#include "srp6.h"

#include <array>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

constexpr std::uint32_t CMSG_AUTH_SESSION = 0x1ED;
constexpr std::uint32_t CMSG_CHAR_CREATE = 0x036;
constexpr std::uint32_t CMSG_CHAR_ENUM = 0x037;
constexpr std::uint32_t CMSG_PLAYER_LOGIN = 0x03D;
constexpr std::uint32_t CMSG_LOGOUT_REQUEST = 0x04B;
constexpr std::uint32_t CMSG_MESSAGECHAT = 0x095;
constexpr std::uint32_t CMSG_SET_SELECTION = 0x13D;
constexpr std::uint32_t CMSG_ATTACKSWING = 0x141;
constexpr std::uint32_t CMSG_ATTACKSTOP = 0x142;
constexpr std::uint32_t CMSG_GOSSIP_HELLO = 0x17B;
constexpr std::uint32_t MSG_MOVE_START_FORWARD = 0x0B5;
constexpr std::uint32_t MSG_MOVE_STOP = 0x0B7;
constexpr std::uint32_t MSG_MOVE_JUMP = 0x0BB;
constexpr std::uint32_t MSG_MOVE_HEARTBEAT = 0x0EE;
constexpr std::uint16_t SMSG_CHAR_CREATE = 0x03A;
constexpr std::uint16_t SMSG_CHAR_ENUM = 0x03B;
constexpr std::uint16_t SMSG_CHARACTER_LOGIN_FAILED = 0x041;
constexpr std::uint16_t SMSG_LOGOUT_RESPONSE = 0x04C;
constexpr std::uint16_t SMSG_LOGOUT_COMPLETE = 0x04D;
constexpr std::uint16_t SMSG_MESSAGECHAT = 0x096;
constexpr std::uint16_t SMSG_UPDATE_OBJECT = 0x0A9;
constexpr std::uint16_t SMSG_ATTACKSTART = 0x143;
constexpr std::uint16_t SMSG_ATTACKSTOP = 0x144;
constexpr std::uint16_t SMSG_ATTACKSWING_NOTINRANGE = 0x145;
constexpr std::uint16_t SMSG_ATTACKSWING_BADFACING = 0x146;
constexpr std::uint16_t SMSG_ATTACKSWING_DEADTARGET = 0x148;
constexpr std::uint16_t SMSG_ATTACKSWING_CANT_ATTACK = 0x149;
constexpr std::uint16_t SMSG_ATTACKERSTATEUPDATE = 0x14A;
constexpr std::uint16_t SMSG_COMPRESSED_UPDATE_OBJECT = 0x1F6;
constexpr std::uint16_t SMSG_GOSSIP_MESSAGE = 0x17D;
constexpr std::uint16_t SMSG_LOGIN_VERIFY_WORLD = 0x236;
constexpr std::uint16_t SMSG_TIME_SYNC_REQ = 0x390;
constexpr std::uint16_t SMSG_GM_MESSAGECHAT = 0x3B3;
constexpr std::uint8_t CHAT_MSG_SAY = 0x01;
constexpr std::uint32_t LANG_ORCISH = 1;
constexpr std::uint32_t LANG_COMMON = 7;
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

struct LoginVerifyWorld
{
    std::uint32_t map = 0;
    float x = 0;
    float y = 0;
    float z = 0;
    float orientation = 0;
};

struct VisibleObjectSummary
{
    std::uint64_t guid = 0;
    std::uint16_t high_guid = 0;
    std::uint32_t entry = 0;
    std::uint32_t counter = 0;
    std::uint8_t update_type = 0;
    std::uint8_t object_type = 0;
    std::uint16_t update_flags = 0;
    std::uint32_t movement_flags = 0;
    std::uint16_t movement_flags2 = 0;
    bool has_position = false;
    float x = 0;
    float y = 0;
    float z = 0;
    float orientation = 0;
};

struct UpdateObjectSummary
{
    bool seen = false;
    bool compressed = false;
    std::uint32_t uncompressed_size = 0;
    std::uint32_t block_count = 0;
    std::uint8_t first_update_type = 0;
    std::uint64_t first_guid = 0;
    bool contains_player_guid = false;
    std::size_t payload_size = 0;
    bool visible_parse_complete = false;
    std::string visible_parse_error;
    std::vector<VisibleObjectSummary> visible_objects;
};

struct MovementSample
{
    std::uint32_t flags = 0;
    std::uint16_t flags2 = 0;
    std::uint32_t time = 0;
    float x = 0;
    float y = 0;
    float z = 0;
    float orientation = 0;
    std::uint32_t fall_time = 0;
};

struct ChatMessageSummary
{
    bool parsed = false;
    std::uint8_t chat_type = 0;
    std::uint32_t language = 0;
    std::uint64_t sender_guid = 0;
    std::uint64_t receiver_guid = 0;
    std::string sender_name;
    std::string message;
    std::uint8_t chat_tag = 0;
};

std::vector<std::uint8_t> build_empty_addon_info();
std::vector<std::uint8_t> build_auth_session_payload(
    std::string const& account,
    srp6::SessionKey const& session_key,
    std::array<std::uint8_t, 4> const& server_seed,
    std::array<std::uint8_t, 4> const& local_challenge,
    std::uint32_t realm_id,
    std::span<const std::uint8_t> addon_info);
std::vector<std::uint8_t> build_character_create_payload(std::string const& name);
std::vector<std::uint8_t> build_player_login_payload(std::uint64_t character_guid);
std::vector<std::uint8_t> build_raw_guid_payload(std::uint64_t raw_guid);
std::vector<std::uint8_t> build_movement_payload(std::uint64_t character_guid, MovementSample const& movement);
std::vector<std::uint8_t> build_chat_say_payload(std::uint32_t language, std::string const& message);
std::vector<std::uint8_t> build_client_packet(std::uint32_t opcode, std::span<const std::uint8_t> payload);
std::vector<CharacterSummary> parse_char_enum(std::span<const std::uint8_t> payload);
LoginVerifyWorld parse_login_verify_world(std::span<const std::uint8_t> payload);
ChatMessageSummary parse_chat_message_summary(std::span<const std::uint8_t> payload, bool gm_message);
UpdateObjectSummary parse_update_object_summary(
    std::span<const std::uint8_t> payload,
    bool compressed,
    std::uint64_t player_guid);
bool world_packet_self_test();
