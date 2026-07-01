#pragma once

#include "srp6.h"
#include "world_packets.h"

#include <array>
#include <cstdint>
#include <string>
#include <vector>

namespace acore_protocol
{
constexpr std::uint16_t SMSG_AUTH_CHALLENGE = 0x1EC;
constexpr std::uint16_t SMSG_AUTH_RESPONSE = 0x1EE;

struct AuthChallengeSummary
{
    std::uint8_t security_flags = 0;
};

struct RealmInfo
{
    std::uint16_t realm_count = 0;
    std::uint8_t realm_type = 0;
    std::uint8_t lock = 0;
    std::uint8_t flags = 0;
    std::uint8_t character_count = 0;
    std::uint8_t timezone = 0;
    std::uint32_t realm_id = 0;
    std::string name;
    std::string endpoint;
    std::string host;
    std::string port;
};

struct AuthFlowResult
{
    srp6::SessionKey session_key{};
    RealmInfo realm;
};

struct WorldChallengeSummary
{
    std::uint32_t marker = 0;
    std::array<std::uint8_t, 4> seed{};
};

struct CharacterFlowResult
{
    RealmInfo realm;
    std::vector<std::uint16_t> skipped_auth_opcodes;
    std::vector<std::uint16_t> skipped_character_opcodes;
    std::vector<CharacterSummary> characters;
};

struct CharacterCreateResult
{
    RealmInfo realm;
    std::string name;
    std::uint8_t response = 0;
    bool success = false;
    std::vector<CharacterSummary> characters;
};

struct EnterWorldResult
{
    RealmInfo realm;
    CharacterSummary character;
    LoginVerifyWorld login;
    UpdateObjectSummary update;
    std::vector<std::uint16_t> skipped_login_opcodes;
};

struct MovementHeartbeatResult
{
    RealmInfo realm;
    CharacterSummary before;
    MovementSample target;
    LoginVerifyWorld live;
    CharacterSummary after;
    bool live_position_accepted = false;
    bool saved_position_changed = false;
    float live_drift = 0;
    float saved_drift = 0;
};

struct InteractionResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint64_t target_guid = 0;
    std::uint32_t target_entry = 0;
    std::string target_name;
    bool live_target_found = false;
    bool selection_sent = false;
    bool gossip_sent = false;
    bool gossip_response_seen = false;
    std::uint16_t response_opcode = 0;
    std::vector<VisibleObjectSummary> visible_objects;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct CombatProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint64_t target_guid = 0;
    std::uint32_t target_entry = 0;
    std::string target_name;
    bool live_target_found = false;
    bool target_has_position = false;
    float target_x = 0;
    float target_y = 0;
    float target_z = 0;
    bool approach_movement_sent = false;
    bool return_movement_sent = false;
    bool selection_sent = false;
    bool attack_sent = false;
    bool combat_response_seen = false;
    bool attacker_state_update_seen = false;
    std::uint16_t response_opcode = 0;
    AttackerStateUpdateSummary attacker_state_update;
    std::vector<VisibleObjectSummary> visible_objects;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct ChatSayResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::string message;
    std::string received_message;
    std::uint64_t sender_guid = 0;
    std::uint64_t receiver_guid = 0;
    std::uint8_t chat_type = 0;
    std::uint32_t language = 0;
    bool message_sent = false;
    bool chat_response_seen = false;
    bool echoed_message_seen = false;
    bool whisper_seen = false;
    bool whisper_inform_seen = false;
    std::uint16_t response_opcode = 0;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct SpellbookResult
{
    RealmInfo realm;
    CharacterSummary character;
    InitialSpellsSummary spellbook;
    bool initial_spells_seen = false;
    bool logged_in_world = false;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct ActionButtonsResult
{
    RealmInfo realm;
    CharacterSummary character;
    ActionButtonsSummary action_buttons;
    bool action_buttons_seen = false;
    bool logged_in_world = false;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct InventorySnapshotResult
{
    RealmInfo realm;
    CharacterSummary character;
    PlayerInventorySummary inventory;
    bool inventory_seen = false;
    bool logged_in_world = false;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct InventorySwapProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint8_t source_slot = 0;
    std::uint8_t destination_slot = 0;
    InventorySlotSummary source_before;
    InventorySlotSummary destination_before;
    InventorySlotSummary source_after_swap;
    InventorySlotSummary destination_after_swap;
    InventorySlotSummary source_after_restore;
    InventorySlotSummary destination_after_restore;
    bool before_seen = false;
    bool swap_sent = false;
    bool swap_confirmed = false;
    bool restore_sent = false;
    bool restore_confirmed = false;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct InventorySplitProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint8_t source_slot = 0;
    std::uint8_t destination_slot = 0;
    std::uint32_t split_count = 0;
    InventorySlotSummary source_before;
    InventorySlotSummary destination_before;
    InventorySlotSummary source_after_split;
    InventorySlotSummary destination_after_split;
    InventorySlotSummary source_after_merge;
    InventorySlotSummary destination_after_merge;
    bool before_seen = false;
    bool split_sent = false;
    bool split_confirmed = false;
    bool merge_sent = false;
    bool merge_confirmed = false;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct SetActionButtonProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint8_t button = 0;
    std::uint32_t action = 0;
    std::uint8_t type = 0;
    ActionButtonSummary original;
    ActionButtonSummary after_set;
    ActionButtonSummary after_restore;
    bool before_seen = false;
    bool set_sent = false;
    bool set_confirmed = false;
    bool restore_sent = false;
    bool restore_confirmed = false;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct SpellCastProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint32_t spell_id = 0;
    bool cast_sent = false;
    bool logged_in_world = false;
    bool response_seen = false;
    bool accepted = false;
    SpellCastResponseSummary response;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct TargetedSpellCastProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint32_t spell_id = 0;
    std::uint64_t target_guid = 0;
    std::uint32_t target_entry = 0;
    std::string target_name;
    bool live_target_found = false;
    bool selection_sent = false;
    bool attack_sent = false;
    bool cast_sent = false;
    bool logged_in_world = false;
    bool response_seen = false;
    bool accepted = false;
    SpellCastResponseSummary response;
    std::vector<VisibleObjectSummary> visible_objects;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct LootOpenProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint64_t target_guid = 0;
    std::uint32_t target_entry = 0;
    std::string target_name;
    bool live_target_found = false;
    bool target_has_position = false;
    float target_x = 0;
    float target_y = 0;
    float target_z = 0;
    bool approach_movement_sent = false;
    bool return_movement_sent = false;
    bool selection_sent = false;
    bool loot_open_sent = false;
    bool loot_response_seen = false;
    bool loot_release_sent = false;
    bool loot_release_response_seen = false;
    bool loot_release_success = false;
    std::uint16_t response_opcode = 0;
    LootResponseSummary loot;
    std::vector<VisibleObjectSummary> visible_objects;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct CorpseLootProbeResult
{
    RealmInfo realm;
    CharacterSummary character;
    std::uint64_t target_guid = 0;
    std::uint32_t target_entry = 0;
    std::string target_name;
    bool live_target_found = false;
    bool target_has_position = false;
    float target_x = 0;
    float target_y = 0;
    float target_z = 0;
    bool target_health_seen = false;
    std::uint32_t target_health = 0;
    bool target_max_health_seen = false;
    std::uint32_t target_max_health = 0;
    bool target_dynamic_flags_seen = false;
    std::uint32_t target_dynamic_flags = 0;
    bool target_dead_seen = false;
    bool target_lootable_seen = false;
    bool approach_movement_sent = false;
    bool return_movement_sent = false;
    bool selection_sent = false;
    bool attack_sent = false;
    bool attack_stop_sent = false;
    std::size_t attacker_state_update_count = 0;
    AttackerStateUpdateSummary attacker_state_update;
    std::uint32_t total_damage = 0;
    bool loot_open_sent = false;
    bool loot_response_seen = false;
    bool loot_money_sent = false;
    bool loot_money_notify_seen = false;
    std::uint32_t loot_money_amount = 0;
    std::uint8_t loot_money_display_type = 0;
    std::size_t loot_item_pickup_sent_count = 0;
    std::size_t loot_item_removed_count = 0;
    bool loot_release_sent = false;
    bool loot_release_response_seen = false;
    bool loot_release_success = false;
    std::uint16_t response_opcode = 0;
    LootResponseSummary loot;
    std::vector<VisibleObjectSummary> visible_objects;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct LootInventoryHandoffResult
{
    RealmInfo realm;
    CharacterSummary character;
    CorpseLootProbeResult corpse_loot;
    PlayerInventorySummary inventory_before;
    PlayerInventorySummary inventory_after;
    bool inventory_before_seen = false;
    bool inventory_after_seen = false;
    std::size_t changed_slot_count = 0;
    std::size_t added_slot_count = 0;
    std::size_t removed_slot_count = 0;
    std::size_t stack_changed_slot_count = 0;
    bool coinage_changed = false;
    std::int64_t coinage_delta = 0;
    bool handoff_confirmed = false;
    std::vector<InventorySlotSummary> changed_slots;
    std::vector<std::uint16_t> skipped_opcodes;
};

struct FlowOptions
{
    bool trace_world_packets = false;
};

std::vector<std::uint8_t> build_auth_logon_challenge(std::string const& account);
std::string format_auth_flow_ok(RealmInfo const& realm);

AuthChallengeSummary probe_auth_challenge(
    std::string const& host,
    std::string const& port,
    std::string const& account);

AuthFlowResult run_auth_flow(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password);

WorldChallengeSummary probe_world_challenge(
    std::string const& host,
    std::string const& port);

CharacterFlowResult run_character_flow(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    FlowOptions options = {});

CharacterCreateResult create_character(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& name,
    FlowOptions options = {});

EnterWorldResult enter_world(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options = {});

MovementHeartbeatResult move_heartbeat(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    float delta_x,
    float delta_y,
    float delta_orientation,
    FlowOptions options = {});

InteractionResult interact_with_npc(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options = {});

CombatProbeResult combat_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options = {});

ChatSayResult chat_say(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::string const& message,
    FlowOptions options = {});

ChatSayResult chat_whisper_self(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::string const& message,
    FlowOptions options = {});

SpellbookResult read_initial_spellbook(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options = {});

ActionButtonsResult read_action_buttons(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options = {});

InventorySnapshotResult read_inventory_snapshot(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    FlowOptions options = {});

InventorySwapProbeResult swap_inventory_slots_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t source_slot,
    std::uint8_t destination_slot,
    FlowOptions options = {});

InventorySplitProbeResult split_inventory_stack_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t source_slot,
    std::uint8_t destination_slot,
    std::uint32_t split_count,
    FlowOptions options = {});

SetActionButtonProbeResult set_action_button_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint8_t button,
    std::uint32_t action,
    std::uint8_t type,
    FlowOptions options = {});

SpellCastProbeResult cast_spell_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint32_t spell_id,
    FlowOptions options = {});

TargetedSpellCastProbeResult cast_spell_at_target_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint32_t spell_id,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options = {});

LootOpenProbeResult loot_open_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options = {});

CorpseLootProbeResult corpse_loot_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options = {});

LootInventoryHandoffResult loot_inventory_handoff_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& password,
    std::string const& character_name,
    std::uint64_t target_guid,
    std::string const& target_name,
    FlowOptions options = {});
}
