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
constexpr std::uint32_t CMSG_ITEM_QUERY_SINGLE = 0x056;
constexpr std::uint32_t CMSG_PLAYER_LOGIN = 0x03D;
constexpr std::uint32_t CMSG_LOGOUT_REQUEST = 0x04B;
constexpr std::uint32_t CMSG_MESSAGECHAT = 0x095;
constexpr std::uint32_t CMSG_SET_ACTION_BUTTON = 0x128;
constexpr std::uint32_t CMSG_CAST_SPELL = 0x12E;
constexpr std::uint32_t CMSG_SWAP_INV_ITEM = 0x10D;
constexpr std::uint32_t CMSG_SPLIT_ITEM = 0x10E;
constexpr std::uint32_t CMSG_SET_SELECTION = 0x13D;
constexpr std::uint32_t CMSG_ATTACKSWING = 0x141;
constexpr std::uint32_t CMSG_ATTACKSTOP = 0x142;
constexpr std::uint32_t CMSG_AUTOSTORE_LOOT_ITEM = 0x108;
constexpr std::uint32_t CMSG_LOOT = 0x15D;
constexpr std::uint32_t CMSG_LOOT_MONEY = 0x15E;
constexpr std::uint32_t CMSG_LOOT_RELEASE = 0x15F;
constexpr std::uint32_t CMSG_GOSSIP_HELLO = 0x17B;
constexpr std::uint32_t CMSG_QUESTGIVER_HELLO = 0x184;
constexpr std::uint32_t CMSG_QUESTGIVER_QUERY_QUEST = 0x186;
constexpr std::uint32_t CMSG_QUESTGIVER_ACCEPT_QUEST = 0x189;
constexpr std::uint32_t CMSG_QUESTGIVER_COMPLETE_QUEST = 0x18A;
constexpr std::uint32_t CMSG_QUESTGIVER_REQUEST_REWARD = 0x18C;
constexpr std::uint32_t CMSG_QUESTGIVER_CHOOSE_REWARD = 0x18E;
constexpr std::uint32_t CMSG_QUESTLOG_REMOVE_QUEST = 0x194;
constexpr std::uint32_t CMSG_LIST_INVENTORY = 0x19E;
constexpr std::uint32_t CMSG_SELL_ITEM = 0x1A0;
constexpr std::uint32_t CMSG_BUY_ITEM = 0x1A2;
constexpr std::uint32_t CMSG_TRAINER_LIST = 0x1B0;
constexpr std::uint32_t CMSG_TRAINER_BUY_SPELL = 0x1B2;
constexpr std::uint32_t CMSG_TIME_SYNC_RESP = 0x391;
constexpr std::uint32_t MSG_MOVE_START_FORWARD = 0x0B5;
constexpr std::uint32_t MSG_MOVE_STOP = 0x0B7;
constexpr std::uint32_t MSG_MOVE_JUMP = 0x0BB;
constexpr std::uint32_t MSG_MOVE_HEARTBEAT = 0x0EE;
constexpr std::uint16_t SMSG_CHAR_CREATE = 0x03A;
constexpr std::uint16_t SMSG_CHAR_ENUM = 0x03B;
constexpr std::uint16_t SMSG_CHARACTER_LOGIN_FAILED = 0x041;
constexpr std::uint16_t SMSG_LOGOUT_RESPONSE = 0x04C;
constexpr std::uint16_t SMSG_LOGOUT_COMPLETE = 0x04D;
constexpr std::uint16_t SMSG_ITEM_QUERY_SINGLE_RESPONSE = 0x058;
constexpr std::uint16_t SMSG_MESSAGECHAT = 0x096;
constexpr std::uint16_t SMSG_UPDATE_OBJECT = 0x0A9;
constexpr std::uint16_t SMSG_INVENTORY_CHANGE_FAILURE = 0x112;
constexpr std::uint16_t SMSG_ACTION_BUTTONS = 0x129;
constexpr std::uint16_t SMSG_INITIAL_SPELLS = 0x12A;
constexpr std::uint16_t SMSG_CAST_FAILED = 0x130;
constexpr std::uint16_t SMSG_SPELL_START = 0x131;
constexpr std::uint16_t SMSG_SPELL_GO = 0x132;
constexpr std::uint16_t SMSG_SPELL_FAILURE = 0x133;
constexpr std::uint16_t SMSG_ATTACKSTART = 0x143;
constexpr std::uint16_t SMSG_ATTACKSTOP = 0x144;
constexpr std::uint16_t SMSG_ATTACKSWING_NOTINRANGE = 0x145;
constexpr std::uint16_t SMSG_ATTACKSWING_BADFACING = 0x146;
constexpr std::uint16_t SMSG_ATTACKSWING_DEADTARGET = 0x148;
constexpr std::uint16_t SMSG_ATTACKSWING_CANT_ATTACK = 0x149;
constexpr std::uint16_t SMSG_ATTACKERSTATEUPDATE = 0x14A;
constexpr std::uint16_t SMSG_LOOT_RESPONSE = 0x160;
constexpr std::uint16_t SMSG_LOOT_RELEASE_RESPONSE = 0x161;
constexpr std::uint16_t SMSG_LOOT_REMOVED = 0x162;
constexpr std::uint16_t SMSG_LOOT_MONEY_NOTIFY = 0x163;
constexpr std::uint16_t SMSG_LOOT_ITEM_NOTIFY = 0x164;
constexpr std::uint16_t SMSG_LOOT_CLEAR_MONEY = 0x165;
constexpr std::uint16_t SMSG_COMPRESSED_UPDATE_OBJECT = 0x1F6;
constexpr std::uint16_t SMSG_GOSSIP_MESSAGE = 0x17D;
constexpr std::uint16_t SMSG_LIST_INVENTORY = 0x19F;
constexpr std::uint16_t SMSG_SELL_ITEM = 0x1A1;
constexpr std::uint16_t SMSG_BUY_ITEM = 0x1A4;
constexpr std::uint16_t SMSG_BUY_FAILED = 0x1A5;
constexpr std::uint16_t SMSG_TRAINER_LIST = 0x1B1;
constexpr std::uint16_t SMSG_QUESTGIVER_QUEST_LIST = 0x185;
constexpr std::uint16_t SMSG_QUESTGIVER_QUEST_DETAILS = 0x188;
constexpr std::uint16_t SMSG_QUESTGIVER_REQUEST_ITEMS = 0x18B;
constexpr std::uint16_t SMSG_QUESTGIVER_OFFER_REWARD = 0x18D;
constexpr std::uint16_t SMSG_QUESTGIVER_QUEST_INVALID = 0x18F;
constexpr std::uint16_t SMSG_QUESTGIVER_QUEST_COMPLETE = 0x191;
constexpr std::uint16_t SMSG_TRAINER_BUY_SUCCEEDED = 0x1B3;
constexpr std::uint16_t SMSG_TRAINER_BUY_FAILED = 0x1B4;
constexpr std::uint16_t SMSG_LOGIN_VERIFY_WORLD = 0x236;
constexpr std::uint16_t SMSG_TIME_SYNC_REQ = 0x390;
constexpr std::uint16_t SMSG_GM_MESSAGECHAT = 0x3B3;
constexpr std::uint16_t SMSG_SPELL_FAILED_OTHER = 0x2A6;
constexpr std::uint8_t CHAT_MSG_SAY = 0x01;
constexpr std::uint8_t CHAT_MSG_WHISPER = 0x07;
constexpr std::uint8_t CHAT_MSG_WHISPER_INFORM = 0x09;
constexpr std::uint32_t LANG_UNIVERSAL = 0;
constexpr std::uint32_t LANG_ORCISH = 1;
constexpr std::uint32_t LANG_COMMON = 7;
constexpr std::size_t CharEnumEquipmentSlots = 23;
constexpr std::size_t MaxActionButtons = 144;
constexpr std::size_t PlayerInventorySnapshotSlots = 39;

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
    bool health_seen = false;
    std::uint32_t health = 0;
    bool max_health_seen = false;
    std::uint32_t max_health = 0;
    bool unit_flags_seen = false;
    std::uint32_t unit_flags = 0;
    bool dynamic_flags_seen = false;
    std::uint32_t dynamic_flags = 0;
};

struct InventorySlotSummary
{
    std::uint8_t slot = 0;
    std::uint8_t section = 0;
    std::uint64_t item_guid = 0;
    std::uint32_t item_entry = 0;
    std::string item_name;
    std::uint32_t stack_count = 0;
    std::uint32_t durability = 0;
    std::uint32_t max_durability = 0;
    bool field_seen = false;
    bool populated = false;
    bool item_detail_seen = false;
    bool item_template_seen = false;
};

struct InventoryItemObjectSummary
{
    bool seen = false;
    std::uint64_t guid = 0;
    std::uint8_t object_type = 0;
    std::uint32_t entry = 0;
    std::uint32_t stack_count = 0;
    std::uint32_t durability = 0;
    std::uint32_t max_durability = 0;
    bool entry_seen = false;
    bool stack_count_seen = false;
    bool durability_seen = false;
    bool max_durability_seen = false;
};

struct ItemTemplateSummary
{
    bool parsed = false;
    std::uint32_t entry = 0;
    std::uint32_t item_class = 0;
    std::uint32_t subclass = 0;
    std::string name;
    std::uint32_t display_id = 0;
    std::uint32_t quality = 0;
    std::uint32_t inventory_type = 0;
    std::uint32_t item_level = 0;
    std::uint32_t required_level = 0;
};

struct PlayerInventorySummary
{
    bool seen = false;
    std::uint64_t player_guid = 0;
    bool coinage_seen = false;
    std::uint32_t coinage = 0;
    std::size_t populated_count = 0;
    std::size_t item_detail_count = 0;
    std::size_t item_template_count = 0;
    std::vector<InventorySlotSummary> slots;
};

struct QuestLogSlotSummary
{
    std::int32_t slot = 0;
    std::uint32_t quest_id = 0;
};

struct PlayerQuestLogSummary
{
    bool seen = false;
    std::uint64_t player_guid = 0;
    // Only the quest-log slots whose id field was present in this update block.
    std::vector<QuestLogSlotSummary> slots;
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
    std::vector<InventoryItemObjectSummary> inventory_items;
    PlayerInventorySummary inventory;
    PlayerQuestLogSummary quest_log;
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

struct InitialSpellSummary
{
    std::uint32_t spell_id = 0;
    std::uint16_t slot = 0;
};

struct InitialSpellsSummary
{
    bool seen = false;
    std::uint8_t spellbook_flags = 0;
    std::uint16_t cooldown_count = 0;
    std::vector<InitialSpellSummary> spells;
};

struct ActionButtonSummary
{
    std::uint8_t button = 0;
    std::uint32_t action = 0;
    std::uint8_t type = 0;
    std::uint32_t packed = 0;
    bool populated = false;
};

struct ActionButtonsSummary
{
    bool seen = false;
    std::uint8_t state = 0;
    std::size_t populated_count = 0;
    std::vector<ActionButtonSummary> buttons;
};

struct AttackSubDamageSummary
{
    std::uint32_t school_mask = 0;
    float float_damage = 0;
    std::uint32_t damage = 0;
    std::uint32_t absorb = 0;
    std::uint32_t resist = 0;
};

struct AttackerStateUpdateSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint32_t hit_info = 0;
    std::uint64_t attacker_guid = 0;
    std::uint64_t target_guid = 0;
    std::uint32_t total_damage = 0;
    std::uint32_t overkill = 0;
    std::uint8_t sub_damage_count = 0;
    std::uint8_t target_state = 0;
    std::uint32_t attacker_state = 0;
    std::uint32_t melee_spell_id = 0;
    std::uint32_t blocked_amount = 0;
    bool has_absorb = false;
    bool has_resist = false;
    bool has_blocked_amount = false;
    bool has_rage_gain = false;
    bool has_debug_fields = false;
    std::vector<AttackSubDamageSummary> sub_damages;
};

struct SpellCastResponseSummary
{
    bool parsed = false;
    std::uint16_t opcode = 0;
    std::uint64_t source_guid = 0;
    std::uint64_t caster_guid = 0;
    std::uint8_t cast_count = 0;
    std::uint32_t spell_id = 0;
    std::uint32_t cast_flags = 0;
    std::uint8_t fail_reason = 0;
    bool cast_failed = false;
    bool spell_start = false;
    bool spell_go = false;
    bool spell_failure = false;
};

struct LootItemSummary
{
    std::uint8_t slot = 0;
    std::uint32_t item_id = 0;
    std::uint32_t count = 0;
    std::uint32_t display_id = 0;
    std::uint32_t random_suffix = 0;
    std::uint32_t random_property_id = 0;
    std::uint8_t slot_type = 0;
};

struct TrainerSpellSummary
{
    std::int32_t spell_id = 0;
    std::uint8_t usable = 0;
    std::int32_t money_cost = 0;
    std::array<std::int32_t, 2> point_cost = {};
    std::uint8_t req_level = 0;
    std::int32_t req_skill_line = 0;
    std::int32_t req_skill_rank = 0;
    std::array<std::int32_t, 3> req_ability = {};
};

struct TrainerListSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t trainer_guid = 0;
    std::int32_t trainer_type = 0;
    std::int32_t spell_count = 0;
    std::string greeting;
    std::vector<TrainerSpellSummary> spells;
};

struct TrainerBuyResponseSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t trainer_guid = 0;
    std::int32_t spell_id = 0;
    std::int32_t failure_reason = 0;
    bool succeeded = false;
    bool failed = false;
};

struct QuestGiverQuestSummary
{
    std::uint32_t quest_id = 0;
    std::uint32_t quest_icon = 0;
    std::int32_t quest_level = 0;
    std::uint32_t quest_flags = 0;
    std::uint8_t repeatable = 0;
    std::string title;
};

struct QuestGiverListSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t questgiver_guid = 0;
    std::string greeting;
    std::uint32_t emote_delay = 0;
    std::uint32_t emote_type = 0;
    std::int32_t quest_count = 0;
    std::vector<QuestGiverQuestSummary> quests;
};

struct GossipQuestItemSummary
{
    std::uint32_t quest_id = 0;
    std::uint32_t quest_icon = 0;
    std::int32_t quest_level = 0;
    std::uint32_t quest_flags = 0;
    std::uint8_t repeatable = 0;
};

struct GossipMessageSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t sender_guid = 0;
    std::uint32_t menu_id = 0;
    std::uint32_t title_text_id = 0;
    std::uint32_t gossip_option_count = 0;
    std::int32_t quest_count = 0;
    std::vector<GossipQuestItemSummary> quests;
};

struct QuestRewardItemSummary
{
    std::uint32_t item_id = 0;
    std::uint32_t item_count = 0;
};

struct QuestGiverDetailsSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t npc_guid = 0;
    std::uint32_t quest_id = 0;
    std::uint32_t quest_flags = 0;
    std::uint32_t suggested_players = 0;
    bool hidden_rewards = false;
    std::int32_t reward_choice_count = 0;
    std::int32_t reward_item_count = 0;
    std::uint32_t money_reward = 0;
    std::uint32_t xp_reward = 0;
    std::uint32_t reward_spell = 0;
    std::uint32_t honor_reward = 0;
    std::vector<QuestRewardItemSummary> reward_choice_items;
    std::vector<QuestRewardItemSummary> reward_items;
};

struct QuestGiverOfferRewardSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t npc_guid = 0;
    std::uint32_t quest_id = 0;
    std::uint32_t quest_flags = 0;
    std::uint32_t suggested_players = 0;
    std::int32_t reward_choice_count = 0;
    std::int32_t reward_item_count = 0;
    std::uint32_t money_reward = 0;
    std::uint32_t xp_reward = 0;
    std::uint32_t honor_reward = 0;
    std::uint32_t reward_spell = 0;
    std::vector<QuestRewardItemSummary> reward_choice_items;
    std::vector<QuestRewardItemSummary> reward_items;
};

struct QuestGiverQuestCompleteSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint32_t quest_id = 0;
    std::uint32_t xp_reward = 0;
    std::uint32_t money_reward = 0;
};

struct VendorItemSummary
{
    std::uint32_t vendor_slot = 0;
    std::uint32_t item_id = 0;
    std::uint32_t display_id = 0;
    std::uint32_t left_in_stock = 0;
    std::uint32_t buy_price = 0;
    std::uint32_t max_durability = 0;
    std::uint32_t buy_count = 0;
    std::uint32_t extended_cost = 0;
};

struct VendorListSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t vendor_guid = 0;
    std::uint8_t item_count = 0;
    std::uint8_t error_code = 0;
    std::vector<VendorItemSummary> items;
};

struct VendorBuyResponseSummary
{
    bool parsed = false;
    bool succeeded = false;
    bool failed = false;
    std::size_t payload_size = 0;
    std::uint64_t vendor_guid = 0;
    std::uint32_t vendor_slot = 0;
    std::uint32_t item_id = 0;
    std::uint32_t left_in_stock = 0;
    std::uint32_t count = 0;
    std::uint32_t failure_param = 0;
    std::uint8_t failure_reason = 0;
};

struct VendorSellErrorSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t vendor_guid = 0;
    std::uint64_t item_guid = 0;
    std::uint32_t param = 0;
    std::uint8_t reason = 0;
};

struct LootResponseSummary
{
    bool parsed = false;
    std::size_t payload_size = 0;
    std::uint64_t guid = 0;
    std::uint8_t loot_type = 0;
    bool error = false;
    std::uint8_t error_code = 0;
    std::uint32_t gold = 0;
    std::uint8_t item_count = 0;
    std::vector<LootItemSummary> items;
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
std::vector<std::uint8_t> build_trainer_buy_spell_payload(std::uint64_t trainer_guid, std::uint32_t spell_id);
std::vector<std::uint8_t> build_vendor_buy_item_payload(
    std::uint64_t vendor_guid,
    std::uint32_t item_id,
    std::uint32_t vendor_slot,
    std::uint32_t count);
std::vector<std::uint8_t> build_vendor_sell_item_payload(
    std::uint64_t vendor_guid,
    std::uint64_t item_guid,
    std::uint32_t count);
std::vector<std::uint8_t> build_loot_payload(std::uint64_t raw_guid);
std::vector<std::uint8_t> build_loot_release_payload(std::uint64_t raw_guid);
std::vector<std::uint8_t> build_autostore_loot_item_payload(std::uint8_t loot_slot);
std::vector<std::uint8_t> build_item_query_single_payload(std::uint32_t item_entry);
std::vector<std::uint8_t> build_time_sync_response_payload(std::uint32_t counter, std::uint32_t client_time);
std::vector<std::uint8_t> build_movement_payload(std::uint64_t character_guid, MovementSample const& movement);
std::vector<std::uint8_t> build_chat_say_payload(std::uint32_t language, std::string const& message);
std::vector<std::uint8_t> build_chat_whisper_payload(
    std::uint32_t language,
    std::string const& target_name,
    std::string const& message);
std::vector<std::uint8_t> build_cast_spell_payload(
    std::uint8_t cast_count,
    std::uint32_t spell_id,
    std::uint8_t cast_flags,
    std::uint32_t target_mask);
std::vector<std::uint8_t> build_cast_spell_unit_payload(
    std::uint8_t cast_count,
    std::uint32_t spell_id,
    std::uint8_t cast_flags,
    std::uint64_t target_guid);
std::vector<std::uint8_t> build_set_action_button_payload(
    std::uint8_t button,
    std::uint32_t action,
    std::uint8_t type);
std::vector<std::uint8_t> build_swap_inventory_item_payload(
    std::uint8_t source_slot,
    std::uint8_t destination_slot);
std::vector<std::uint8_t> build_split_item_payload(
    std::uint8_t source_bag,
    std::uint8_t source_slot,
    std::uint8_t destination_bag,
    std::uint8_t destination_slot,
    std::uint32_t count);
std::vector<std::uint8_t> build_client_packet(std::uint32_t opcode, std::span<const std::uint8_t> payload);
std::vector<CharacterSummary> parse_char_enum(std::span<const std::uint8_t> payload);
LoginVerifyWorld parse_login_verify_world(std::span<const std::uint8_t> payload);
std::uint32_t parse_time_sync_counter(std::span<const std::uint8_t> payload);
ChatMessageSummary parse_chat_message_summary(std::span<const std::uint8_t> payload, bool gm_message);
InitialSpellsSummary parse_initial_spells_summary(std::span<const std::uint8_t> payload);
ActionButtonsSummary parse_action_buttons_summary(std::span<const std::uint8_t> payload);
ItemTemplateSummary parse_item_query_single_response(std::span<const std::uint8_t> payload);
AttackerStateUpdateSummary parse_attacker_state_update(std::span<const std::uint8_t> payload);
SpellCastResponseSummary parse_spell_cast_response(std::uint16_t opcode, std::span<const std::uint8_t> payload);
LootResponseSummary parse_loot_response(std::span<const std::uint8_t> payload);
TrainerListSummary parse_trainer_list_response(std::span<const std::uint8_t> payload);
QuestGiverListSummary parse_questgiver_quest_list_response(std::span<const std::uint8_t> payload);
GossipMessageSummary parse_gossip_message_response(std::span<const std::uint8_t> payload);
QuestGiverDetailsSummary parse_questgiver_quest_details_response(std::span<const std::uint8_t> payload);
std::vector<std::uint8_t> build_questgiver_query_quest_payload(std::uint64_t guid, std::uint32_t quest_id);
std::vector<std::uint8_t> build_questgiver_accept_quest_payload(std::uint64_t guid, std::uint32_t quest_id);
std::vector<std::uint8_t> build_questlog_remove_quest_payload(std::uint8_t slot);
std::vector<std::uint8_t> build_questgiver_complete_quest_payload(std::uint64_t guid, std::uint32_t quest_id);
std::vector<std::uint8_t> build_questgiver_request_reward_payload(std::uint64_t guid, std::uint32_t quest_id);
std::vector<std::uint8_t> build_questgiver_choose_reward_payload(std::uint64_t guid, std::uint32_t quest_id, std::uint32_t reward_index);
QuestGiverOfferRewardSummary parse_questgiver_offer_reward_response(std::span<const std::uint8_t> payload);
QuestGiverQuestCompleteSummary parse_questgiver_quest_complete_response(std::span<const std::uint8_t> payload);
TrainerBuyResponseSummary parse_trainer_buy_succeeded_response(std::span<const std::uint8_t> payload);
TrainerBuyResponseSummary parse_trainer_buy_failed_response(std::span<const std::uint8_t> payload);
VendorListSummary parse_vendor_list_response(std::span<const std::uint8_t> payload);
VendorBuyResponseSummary parse_vendor_buy_response(std::span<const std::uint8_t> payload);
VendorBuyResponseSummary parse_vendor_buy_failed_response(std::span<const std::uint8_t> payload);
VendorSellErrorSummary parse_vendor_sell_error_response(std::span<const std::uint8_t> payload);
UpdateObjectSummary parse_update_object_summary(
    std::span<const std::uint8_t> payload,
    bool compressed,
    std::uint64_t player_guid);
bool world_packet_self_test();
