#include "acore_protocol_client.h"

#include "protocol_flow.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/char_string.hpp>

#include <cstdint>
#include <exception>
#include <iomanip>
#include <sstream>
#include <string>

using namespace godot;

namespace
{
std::string to_std_string(String const& value)
{
    CharString utf8 = value.utf8();
    return std::string(utf8.get_data());
}

String guid_to_hex(std::uint64_t guid)
{
    std::ostringstream out;
    out << "0x" << std::hex << guid;
    return String(out.str().c_str());
}

Array opcode_array(std::vector<std::uint16_t> const& opcodes)
{
    Array values;
    for (std::uint16_t opcode : opcodes)
    {
        values.append(static_cast<int>(opcode));
    }
    return values;
}

Dictionary failure(std::string const& message)
{
    Dictionary result;
    result["ok"] = false;
    result["error"] = String(message.c_str());
    return result;
}

Dictionary realm_dictionary(acore_protocol::RealmInfo const& realm)
{
    Dictionary value;
    value["name"] = String(realm.name.c_str());
    value["endpoint"] = String(realm.endpoint.c_str());
    value["realm_id"] = static_cast<int>(realm.realm_id);
    value["type"] = static_cast<int>(realm.realm_type);
    value["lock"] = static_cast<int>(realm.lock);
    value["flags"] = static_cast<int>(realm.flags);
    value["character_count"] = static_cast<int>(realm.character_count);
    value["timezone"] = static_cast<int>(realm.timezone);
    return value;
}

Array character_array(std::vector<CharacterSummary> const& characters)
{
    Array values;
    for (CharacterSummary const& character : characters)
    {
        Dictionary value;
        value["guid"] = guid_to_hex(character.guid);
        value["name"] = String(character.name.c_str());
        value["level"] = static_cast<int>(character.level);
        value["race"] = static_cast<int>(character.race);
        value["class"] = static_cast<int>(character.character_class);
        value["map"] = static_cast<int>(character.map);
        value["x"] = character.x;
        value["y"] = character.y;
        value["z"] = character.z;
        values.append(value);
    }
    return values;
}

Dictionary character_dictionary(CharacterSummary const& character)
{
    Dictionary value;
    value["guid"] = guid_to_hex(character.guid);
    value["name"] = String(character.name.c_str());
    value["level"] = static_cast<int>(character.level);
    value["race"] = static_cast<int>(character.race);
    value["class"] = static_cast<int>(character.character_class);
    value["map"] = static_cast<int>(character.map);
    value["x"] = character.x;
    value["y"] = character.y;
    value["z"] = character.z;
    return value;
}

Dictionary login_verify_dictionary(LoginVerifyWorld const& login)
{
    Dictionary value;
    value["map"] = static_cast<int>(login.map);
    value["x"] = login.x;
    value["y"] = login.y;
    value["z"] = login.z;
    value["orientation"] = login.orientation;
    return value;
}

Dictionary visible_object_dictionary(VisibleObjectSummary const& object)
{
    Dictionary value;
    value["guid"] = guid_to_hex(object.guid);
    value["high_guid"] = static_cast<int>(object.high_guid);
    value["entry"] = static_cast<int>(object.entry);
    value["counter"] = static_cast<int>(object.counter);
    value["update_type"] = static_cast<int>(object.update_type);
    value["object_type"] = static_cast<int>(object.object_type);
    value["update_flags"] = static_cast<int>(object.update_flags);
    value["movement_flags"] = static_cast<int>(object.movement_flags);
    value["movement_flags2"] = static_cast<int>(object.movement_flags2);
    value["has_position"] = object.has_position;
    value["x"] = object.x;
    value["y"] = object.y;
    value["z"] = object.z;
    value["orientation"] = object.orientation;
    value["health_seen"] = object.health_seen;
    value["health"] = static_cast<int64_t>(object.health);
    value["max_health_seen"] = object.max_health_seen;
    value["max_health"] = static_cast<int64_t>(object.max_health);
    value["unit_flags_seen"] = object.unit_flags_seen;
    value["unit_flags"] = static_cast<int64_t>(object.unit_flags);
    value["dynamic_flags_seen"] = object.dynamic_flags_seen;
    value["dynamic_flags"] = static_cast<int64_t>(object.dynamic_flags);
    return value;
}

Array visible_object_array(std::vector<VisibleObjectSummary> const& objects)
{
    Array values;
    for (VisibleObjectSummary const& object : objects)
    {
        values.append(visible_object_dictionary(object));
    }
    return values;
}

Array spell_array(std::vector<InitialSpellSummary> const& spells)
{
    Array values;
    for (InitialSpellSummary const& spell : spells)
    {
        Dictionary value;
        value["id"] = static_cast<int>(spell.spell_id);
        value["slot"] = static_cast<int>(spell.slot);
        values.append(value);
    }
    return values;
}

Dictionary action_button_dictionary(ActionButtonSummary const& button)
{
    Dictionary value;
    value["button"] = static_cast<int>(button.button);
    value["action"] = static_cast<int>(button.action);
    value["type"] = static_cast<int>(button.type);
    value["packed"] = static_cast<int64_t>(button.packed);
    value["populated"] = button.populated;
    return value;
}

Array action_button_array(std::vector<ActionButtonSummary> const& buttons)
{
    Array values;
    for (ActionButtonSummary const& button : buttons)
    {
        values.append(action_button_dictionary(button));
    }
    return values;
}

String inventory_section_name(std::uint8_t section)
{
    switch (section)
    {
        case 0:
            return "equipment";
        case 1:
            return "bag";
        case 2:
            return "backpack";
        default:
            return "unknown";
    }
}

Dictionary inventory_slot_dictionary(InventorySlotSummary const& slot)
{
    Dictionary value;
    value["slot"] = static_cast<int>(slot.slot);
    value["section"] = inventory_section_name(slot.section);
    value["item_guid"] = guid_to_hex(slot.item_guid);
    value["item_entry"] = static_cast<int64_t>(slot.item_entry);
    value["item_name"] = String(slot.item_name.c_str());
    value["stack_count"] = static_cast<int64_t>(slot.stack_count);
    value["durability"] = static_cast<int64_t>(slot.durability);
    value["max_durability"] = static_cast<int64_t>(slot.max_durability);
    value["field_seen"] = slot.field_seen;
    value["populated"] = slot.populated;
    value["item_detail_seen"] = slot.item_detail_seen;
    value["item_template_seen"] = slot.item_template_seen;
    return value;
}

Array inventory_slot_array(std::vector<InventorySlotSummary> const& slots)
{
    Array values;
    for (InventorySlotSummary const& slot : slots)
    {
        values.append(inventory_slot_dictionary(slot));
    }
    return values;
}

Dictionary inventory_dictionary(PlayerInventorySummary const& inventory)
{
    Dictionary value;
    value["seen"] = inventory.seen;
    value["player_guid"] = guid_to_hex(inventory.player_guid);
    value["coinage_seen"] = inventory.coinage_seen;
    value["coinage"] = static_cast<int64_t>(inventory.coinage);
    value["slot_count"] = static_cast<int>(inventory.slots.size());
    value["populated_count"] = static_cast<int>(inventory.populated_count);
    value["item_detail_count"] = static_cast<int>(inventory.item_detail_count);
    value["item_template_count"] = static_cast<int>(inventory.item_template_count);
    value["slots"] = inventory_slot_array(inventory.slots);
    return value;
}

Dictionary spell_cast_response_dictionary(SpellCastResponseSummary const& response)
{
    Dictionary value;
    value["parsed"] = response.parsed;
    value["opcode"] = static_cast<int>(response.opcode);
    value["source_guid"] = guid_to_hex(response.source_guid);
    value["caster_guid"] = guid_to_hex(response.caster_guid);
    value["cast_count"] = static_cast<int>(response.cast_count);
    value["spell_id"] = static_cast<int>(response.spell_id);
    value["cast_flags"] = static_cast<int64_t>(response.cast_flags);
    value["fail_reason"] = static_cast<int>(response.fail_reason);
    value["cast_failed"] = response.cast_failed;
    value["spell_start"] = response.spell_start;
    value["spell_go"] = response.spell_go;
    value["spell_failure"] = response.spell_failure;
    return value;
}

Dictionary attacker_state_update_dictionary(AttackerStateUpdateSummary const& update)
{
    Dictionary value;
    value["parsed"] = update.parsed;
    value["payload_size"] = static_cast<int>(update.payload_size);
    value["hit_info"] = static_cast<int64_t>(update.hit_info);
    value["attacker_guid"] = guid_to_hex(update.attacker_guid);
    value["target_guid"] = guid_to_hex(update.target_guid);
    value["total_damage"] = static_cast<int64_t>(update.total_damage);
    value["overkill"] = static_cast<int64_t>(update.overkill);
    value["sub_damage_count"] = static_cast<int>(update.sub_damage_count);
    value["target_state"] = static_cast<int>(update.target_state);
    value["attacker_state"] = static_cast<int64_t>(update.attacker_state);
    value["melee_spell_id"] = static_cast<int64_t>(update.melee_spell_id);
    value["blocked_amount"] = static_cast<int64_t>(update.blocked_amount);
    value["has_absorb"] = update.has_absorb;
    value["has_resist"] = update.has_resist;
    value["has_blocked_amount"] = update.has_blocked_amount;
    value["has_rage_gain"] = update.has_rage_gain;
    value["has_debug_fields"] = update.has_debug_fields;
    return value;
}

Dictionary loot_item_dictionary(LootItemSummary const& item)
{
    Dictionary value;
    value["slot"] = static_cast<int>(item.slot);
    value["item_id"] = static_cast<int64_t>(item.item_id);
    value["count"] = static_cast<int64_t>(item.count);
    value["display_id"] = static_cast<int64_t>(item.display_id);
    value["random_suffix"] = static_cast<int64_t>(item.random_suffix);
    value["random_property_id"] = static_cast<int64_t>(item.random_property_id);
    value["slot_type"] = static_cast<int>(item.slot_type);
    return value;
}

Array loot_item_array(std::vector<LootItemSummary> const& items)
{
    Array values;
    for (LootItemSummary const& item : items)
    {
        values.append(loot_item_dictionary(item));
    }
    return values;
}

Dictionary loot_response_dictionary(LootResponseSummary const& loot)
{
    Dictionary value;
    value["parsed"] = loot.parsed;
    value["payload_size"] = static_cast<int>(loot.payload_size);
    value["guid"] = guid_to_hex(loot.guid);
    value["loot_type"] = static_cast<int>(loot.loot_type);
    value["error"] = loot.error;
    value["error_code"] = static_cast<int>(loot.error_code);
    value["gold"] = static_cast<int64_t>(loot.gold);
    value["item_count"] = static_cast<int>(loot.item_count);
    value["items"] = loot_item_array(loot.items);
    return value;
}

Dictionary update_dictionary(UpdateObjectSummary const& update)
{
    Dictionary value;
    value["seen"] = update.seen;
    value["compressed"] = update.compressed;
    value["uncompressed_size"] = static_cast<int>(update.uncompressed_size);
    value["block_count"] = static_cast<int>(update.block_count);
    value["first_update_type"] = static_cast<int>(update.first_update_type);
    value["first_guid"] = guid_to_hex(update.first_guid);
    value["contains_player_guid"] = update.contains_player_guid;
    value["payload_size"] = static_cast<int>(update.payload_size);
    value["visible_parse_complete"] = update.visible_parse_complete;
    value["visible_parse_error"] = String(update.visible_parse_error.c_str());
    value["visible_objects"] = visible_object_array(update.visible_objects);
    value["visible_object_count"] = static_cast<int>(update.visible_objects.size());
    return value;
}

Dictionary movement_dictionary(MovementSample const& movement)
{
    Dictionary value;
    value["flags"] = static_cast<int>(movement.flags);
    value["flags2"] = static_cast<int>(movement.flags2);
    value["time"] = static_cast<int>(movement.time);
    value["x"] = movement.x;
    value["y"] = movement.y;
    value["z"] = movement.z;
    value["orientation"] = movement.orientation;
    value["fall_time"] = static_cast<int>(movement.fall_time);
    return value;
}

Dictionary live_position_dictionary(LoginVerifyWorld const& login)
{
    Dictionary value;
    value["map"] = static_cast<int>(login.map);
    value["x"] = login.x;
    value["y"] = login.y;
    value["z"] = login.z;
    value["orientation"] = login.orientation;
    return value;
}
}

void AcoreProtocolClient::_bind_methods()
{
    ClassDB::bind_method(D_METHOD("self_test"), &AcoreProtocolClient::self_test);
    ClassDB::bind_method(
        D_METHOD("character_flow", "host", "port", "account", "password"),
        &AcoreProtocolClient::character_flow);
    ClassDB::bind_method(
        D_METHOD("create_character", "host", "port", "account", "password", "name"),
        &AcoreProtocolClient::create_character);
    ClassDB::bind_method(
        D_METHOD("enter_world", "host", "port", "account", "password", "character_name"),
        &AcoreProtocolClient::enter_world);
    ClassDB::bind_method(
        D_METHOD("move_heartbeat", "host", "port", "account", "password", "character_name", "delta_x", "delta_y", "delta_orientation"),
        &AcoreProtocolClient::move_heartbeat);
    ClassDB::bind_method(
        D_METHOD("interact_with_npc", "host", "port", "account", "password", "character_name", "target_entry", "target_name"),
        &AcoreProtocolClient::interact_with_npc);
    ClassDB::bind_method(
        D_METHOD("combat_probe", "host", "port", "account", "password", "character_name", "target_entry", "target_name"),
        &AcoreProtocolClient::combat_probe);
    ClassDB::bind_method(
        D_METHOD("loot_open_probe", "host", "port", "account", "password", "character_name", "target_entry", "target_name"),
        &AcoreProtocolClient::loot_open_probe);
    ClassDB::bind_method(
        D_METHOD("corpse_loot_probe", "host", "port", "account", "password", "character_name", "target_entry", "target_name"),
        &AcoreProtocolClient::corpse_loot_probe);
    ClassDB::bind_method(
        D_METHOD("chat_say", "host", "port", "account", "password", "character_name", "message"),
        &AcoreProtocolClient::chat_say);
    ClassDB::bind_method(
        D_METHOD("chat_whisper_self", "host", "port", "account", "password", "character_name", "message"),
        &AcoreProtocolClient::chat_whisper_self);
    ClassDB::bind_method(
        D_METHOD("spellbook", "host", "port", "account", "password", "character_name"),
        &AcoreProtocolClient::spellbook);
    ClassDB::bind_method(
        D_METHOD("action_buttons", "host", "port", "account", "password", "character_name"),
        &AcoreProtocolClient::action_buttons);
    ClassDB::bind_method(
        D_METHOD("inventory_snapshot", "host", "port", "account", "password", "character_name"),
        &AcoreProtocolClient::inventory_snapshot);
    ClassDB::bind_method(
        D_METHOD("swap_inventory_slots", "host", "port", "account", "password", "character_name", "source_slot", "destination_slot"),
        &AcoreProtocolClient::swap_inventory_slots);
    ClassDB::bind_method(
        D_METHOD("split_inventory_stack", "host", "port", "account", "password", "character_name", "source_slot", "destination_slot", "split_count"),
        &AcoreProtocolClient::split_inventory_stack);
    ClassDB::bind_method(
        D_METHOD("set_action_button", "host", "port", "account", "password", "character_name", "button", "action", "type"),
        &AcoreProtocolClient::set_action_button);
    ClassDB::bind_method(
        D_METHOD("cast_spell", "host", "port", "account", "password", "character_name", "spell_id"),
        &AcoreProtocolClient::cast_spell);
    ClassDB::bind_method(
        D_METHOD("cast_spell_at_target", "host", "port", "account", "password", "character_name", "spell_id", "target_entry", "target_name"),
        &AcoreProtocolClient::cast_spell_at_target);
}

Dictionary AcoreProtocolClient::self_test()
{
    try
    {
        auto challenge = acore_protocol::build_auth_logon_challenge("TEST");
        if (challenge.size() != 38)
        {
            return failure("unexpected auth logon challenge size");
        }

        Dictionary result;
        result["ok"] = true;
        result["logon_challenge_size"] = 38;
        result["bridge"] = "AcoreProtocolClient";
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::move_heartbeat(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    double delta_x,
    double delta_y,
    double delta_orientation)
{
    try
    {
        acore_protocol::MovementHeartbeatResult flow = acore_protocol::move_heartbeat(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<float>(delta_x),
            static_cast<float>(delta_y),
            static_cast<float>(delta_orientation));

        Dictionary result;
        result["ok"] = flow.live_position_accepted;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["movement_sent"] = true;
        result["live_position_accepted"] = flow.live_position_accepted;
        result["saved_position_changed"] = flow.saved_position_changed;
        result["drift"] = flow.live_drift;
        result["live_drift"] = flow.live_drift;
        result["saved_drift"] = flow.saved_drift;
        result["realm"] = realm_dictionary(flow.realm);
        result["before"] = character_dictionary(flow.before);
        result["target"] = movement_dictionary(flow.target);
        result["live"] = live_position_dictionary(flow.live);
        result["after"] = character_dictionary(flow.after);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::interact_with_npc(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t target_entry,
    String const& target_name)
{
    try
    {
        if (target_entry <= 0)
        {
            return failure("target entry must be positive");
        }

        acore_protocol::InteractionResult flow = acore_protocol::interact_with_npc(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint64_t>(target_entry),
            to_std_string(target_name));

        Dictionary result;
        result["ok"] = flow.live_target_found && flow.selection_sent && flow.gossip_sent && flow.gossip_response_seen;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["target_guid"] = guid_to_hex(flow.target_guid);
        result["target_entry"] = static_cast<int>(flow.target_entry);
        result["target_name"] = String(flow.target_name.c_str());
        result["live_target_found"] = flow.live_target_found;
        result["selection_sent"] = flow.selection_sent;
        result["gossip_sent"] = flow.gossip_sent;
        result["gossip_response_seen"] = flow.gossip_response_seen;
        result["response_opcode"] = static_cast<int>(flow.response_opcode);
        result["visible_objects"] = visible_object_array(flow.visible_objects);
        result["visible_object_count"] = static_cast<int>(flow.visible_objects.size());
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::combat_probe(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t target_entry,
    String const& target_name)
{
    try
    {
        if (target_entry <= 0)
        {
            return failure("combat target entry must be positive");
        }

        acore_protocol::CombatProbeResult flow = acore_protocol::combat_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint64_t>(target_entry),
            to_std_string(target_name));

        Dictionary result;
        result["ok"] = flow.live_target_found && flow.attack_sent && flow.attacker_state_update_seen;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["target_guid"] = guid_to_hex(flow.target_guid);
        result["target_entry"] = static_cast<int>(flow.target_entry);
        result["target_name"] = String(flow.target_name.c_str());
        result["live_target_found"] = flow.live_target_found;
        result["target_has_position"] = flow.target_has_position;
        result["target_x"] = flow.target_x;
        result["target_y"] = flow.target_y;
        result["target_z"] = flow.target_z;
        result["approach_movement_sent"] = flow.approach_movement_sent;
        result["return_movement_sent"] = flow.return_movement_sent;
        result["selection_sent"] = flow.selection_sent;
        result["attack_sent"] = flow.attack_sent;
        result["combat_response_seen"] = flow.combat_response_seen;
        result["attacker_state_update_seen"] = flow.attacker_state_update_seen;
        result["response_opcode"] = static_cast<int>(flow.response_opcode);
        result["attacker_state_update"] = attacker_state_update_dictionary(flow.attacker_state_update);
        result["hit_info"] = static_cast<int64_t>(flow.attacker_state_update.hit_info);
        result["total_damage"] = static_cast<int64_t>(flow.attacker_state_update.total_damage);
        result["overkill"] = static_cast<int64_t>(flow.attacker_state_update.overkill);
        result["sub_damage_count"] = static_cast<int>(flow.attacker_state_update.sub_damage_count);
        result["target_state"] = static_cast<int>(flow.attacker_state_update.target_state);
        result["blocked_amount"] = static_cast<int64_t>(flow.attacker_state_update.blocked_amount);
        result["visible_objects"] = visible_object_array(flow.visible_objects);
        result["visible_object_count"] = static_cast<int>(flow.visible_objects.size());
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::loot_open_probe(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t target_entry,
    String const& target_name)
{
    try
    {
        if (target_entry <= 0)
        {
            return failure("loot target entry must be positive");
        }

        acore_protocol::LootOpenProbeResult flow = acore_protocol::loot_open_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint64_t>(target_entry),
            to_std_string(target_name));

        Dictionary result;
        result["ok"] = flow.loot_open_sent && (flow.loot_response_seen || flow.loot_release_response_seen);
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["target_guid"] = guid_to_hex(flow.target_guid);
        result["target_entry"] = static_cast<int>(flow.target_entry);
        result["target_name"] = String(flow.target_name.c_str());
        result["live_target_found"] = flow.live_target_found;
        result["target_has_position"] = flow.target_has_position;
        result["target_x"] = flow.target_x;
        result["target_y"] = flow.target_y;
        result["target_z"] = flow.target_z;
        result["approach_movement_sent"] = flow.approach_movement_sent;
        result["return_movement_sent"] = flow.return_movement_sent;
        result["selection_sent"] = flow.selection_sent;
        result["loot_open_sent"] = flow.loot_open_sent;
        result["loot_response_seen"] = flow.loot_response_seen;
        result["loot_release_sent"] = flow.loot_release_sent;
        result["loot_release_response_seen"] = flow.loot_release_response_seen;
        result["loot_release_success"] = flow.loot_release_success;
        result["response_opcode"] = static_cast<int>(flow.response_opcode);
        result["loot"] = loot_response_dictionary(flow.loot);
        result["loot_parsed"] = flow.loot.parsed;
        result["loot_error"] = flow.loot.error;
        result["loot_error_code"] = static_cast<int>(flow.loot.error_code);
        result["loot_type"] = static_cast<int>(flow.loot.loot_type);
        result["gold"] = static_cast<int64_t>(flow.loot.gold);
        result["item_count"] = static_cast<int>(flow.loot.item_count);
        result["items"] = loot_item_array(flow.loot.items);
        result["visible_objects"] = visible_object_array(flow.visible_objects);
        result["visible_object_count"] = static_cast<int>(flow.visible_objects.size());
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::corpse_loot_probe(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t target_entry,
    String const& target_name)
{
    try
    {
        if (target_entry <= 0)
        {
            return failure("corpse loot target entry must be positive");
        }

        acore_protocol::CorpseLootProbeResult flow = acore_protocol::corpse_loot_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint64_t>(target_entry),
            to_std_string(target_name));

        bool const loot_window_ok = flow.loot_response_seen && !flow.loot.error;
        bool const money_ok = flow.loot.gold == 0 || flow.loot_money_notify_seen;
        bool const item_ok = flow.loot.items.empty() || flow.loot_item_removed_count > 0;

        Dictionary result;
        result["ok"] = flow.live_target_found && flow.attack_sent && flow.target_dead_seen
            && loot_window_ok && money_ok && item_ok && flow.loot_release_response_seen;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["target_guid"] = guid_to_hex(flow.target_guid);
        result["target_entry"] = static_cast<int>(flow.target_entry);
        result["target_name"] = String(flow.target_name.c_str());
        result["live_target_found"] = flow.live_target_found;
        result["target_has_position"] = flow.target_has_position;
        result["target_x"] = flow.target_x;
        result["target_y"] = flow.target_y;
        result["target_z"] = flow.target_z;
        result["target_health_seen"] = flow.target_health_seen;
        result["target_health"] = static_cast<int64_t>(flow.target_health);
        result["target_max_health_seen"] = flow.target_max_health_seen;
        result["target_max_health"] = static_cast<int64_t>(flow.target_max_health);
        result["target_dynamic_flags_seen"] = flow.target_dynamic_flags_seen;
        result["target_dynamic_flags"] = static_cast<int64_t>(flow.target_dynamic_flags);
        result["target_dead_seen"] = flow.target_dead_seen;
        result["target_lootable_seen"] = flow.target_lootable_seen;
        result["approach_movement_sent"] = flow.approach_movement_sent;
        result["return_movement_sent"] = flow.return_movement_sent;
        result["selection_sent"] = flow.selection_sent;
        result["attack_sent"] = flow.attack_sent;
        result["attack_stop_sent"] = flow.attack_stop_sent;
        result["attacker_state_updates"] = static_cast<int>(flow.attacker_state_update_count);
        result["attacker_state_update"] = attacker_state_update_dictionary(flow.attacker_state_update);
        result["total_damage"] = static_cast<int64_t>(flow.total_damage);
        result["loot_open_sent"] = flow.loot_open_sent;
        result["loot_response_seen"] = flow.loot_response_seen;
        result["loot_money_sent"] = flow.loot_money_sent;
        result["loot_money_notify_seen"] = flow.loot_money_notify_seen;
        result["loot_money_amount"] = static_cast<int64_t>(flow.loot_money_amount);
        result["loot_money_display_type"] = static_cast<int>(flow.loot_money_display_type);
        result["loot_item_pickup_sent_count"] = static_cast<int>(flow.loot_item_pickup_sent_count);
        result["loot_item_removed_count"] = static_cast<int>(flow.loot_item_removed_count);
        result["loot_release_sent"] = flow.loot_release_sent;
        result["loot_release_response_seen"] = flow.loot_release_response_seen;
        result["loot_release_success"] = flow.loot_release_success;
        result["response_opcode"] = static_cast<int>(flow.response_opcode);
        result["loot"] = loot_response_dictionary(flow.loot);
        result["loot_parsed"] = flow.loot.parsed;
        result["loot_error"] = flow.loot.error;
        result["loot_error_code"] = static_cast<int>(flow.loot.error_code);
        result["loot_type"] = static_cast<int>(flow.loot.loot_type);
        result["gold"] = static_cast<int64_t>(flow.loot.gold);
        result["item_count"] = static_cast<int>(flow.loot.item_count);
        result["items"] = loot_item_array(flow.loot.items);
        result["visible_objects"] = visible_object_array(flow.visible_objects);
        result["visible_object_count"] = static_cast<int>(flow.visible_objects.size());
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::chat_say(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    String const& message)
{
    try
    {
        acore_protocol::ChatSayResult flow = acore_protocol::chat_say(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            to_std_string(message));

        Dictionary result;
        result["ok"] = flow.message_sent && flow.echoed_message_seen;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["message"] = String(flow.message.c_str());
        result["received_message"] = String(flow.received_message.c_str());
        result["message_sent"] = flow.message_sent;
        result["chat_response_seen"] = flow.chat_response_seen;
        result["echoed_message_seen"] = flow.echoed_message_seen;
        result["response_opcode"] = static_cast<int>(flow.response_opcode);
        result["chat_type"] = static_cast<int>(flow.chat_type);
        result["language"] = static_cast<int>(flow.language);
        result["sender_guid"] = guid_to_hex(flow.sender_guid);
        result["receiver_guid"] = guid_to_hex(flow.receiver_guid);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::chat_whisper_self(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    String const& message)
{
    try
    {
        acore_protocol::ChatSayResult flow = acore_protocol::chat_whisper_self(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            to_std_string(message));

        Dictionary result;
        result["ok"] = flow.message_sent && flow.echoed_message_seen;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["message"] = String(flow.message.c_str());
        result["received_message"] = String(flow.received_message.c_str());
        result["message_sent"] = flow.message_sent;
        result["chat_response_seen"] = flow.chat_response_seen;
        result["whisper_seen"] = flow.whisper_seen;
        result["whisper_inform_seen"] = flow.whisper_inform_seen;
        result["echoed_message_seen"] = flow.echoed_message_seen;
        result["response_opcode"] = static_cast<int>(flow.response_opcode);
        result["chat_type"] = static_cast<int>(flow.chat_type);
        result["language"] = static_cast<int>(flow.language);
        result["sender_guid"] = guid_to_hex(flow.sender_guid);
        result["receiver_guid"] = guid_to_hex(flow.receiver_guid);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::spellbook(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name)
{
    try
    {
        acore_protocol::SpellbookResult flow = acore_protocol::read_initial_spellbook(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name));

        Dictionary result;
        result["ok"] = flow.initial_spells_seen && !flow.spellbook.spells.empty();
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["initial_spells_seen"] = flow.initial_spells_seen;
        result["logged_in_world"] = flow.logged_in_world;
        result["spellbook_flags"] = static_cast<int>(flow.spellbook.spellbook_flags);
        result["spell_count"] = static_cast<int>(flow.spellbook.spells.size());
        result["cooldown_count"] = static_cast<int>(flow.spellbook.cooldown_count);
        result["spells"] = spell_array(flow.spellbook.spells);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::action_buttons(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name)
{
    try
    {
        acore_protocol::ActionButtonsResult flow = acore_protocol::read_action_buttons(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name));

        Dictionary result;
        result["ok"] = flow.action_buttons_seen && flow.action_buttons.buttons.size() == MaxActionButtons;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["action_buttons_seen"] = flow.action_buttons_seen;
        result["logged_in_world"] = flow.logged_in_world;
        result["state"] = static_cast<int>(flow.action_buttons.state);
        result["slot_count"] = static_cast<int>(flow.action_buttons.buttons.size());
        result["populated_count"] = static_cast<int>(flow.action_buttons.populated_count);
        result["buttons"] = action_button_array(flow.action_buttons.buttons);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::inventory_snapshot(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name)
{
    try
    {
        acore_protocol::InventorySnapshotResult flow = acore_protocol::read_inventory_snapshot(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name));

        Dictionary result;
        result["ok"] = flow.inventory_seen && flow.inventory.slots.size() == PlayerInventorySnapshotSlots;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["inventory_seen"] = flow.inventory_seen;
        result["logged_in_world"] = flow.logged_in_world;
        result["player_guid"] = guid_to_hex(flow.inventory.player_guid);
        result["coinage_seen"] = flow.inventory.coinage_seen;
        result["coinage"] = static_cast<int64_t>(flow.inventory.coinage);
        result["slot_count"] = static_cast<int>(flow.inventory.slots.size());
        result["populated_count"] = static_cast<int>(flow.inventory.populated_count);
        result["item_detail_count"] = static_cast<int>(flow.inventory.item_detail_count);
        result["item_template_count"] = static_cast<int>(flow.inventory.item_template_count);
        result["slots"] = inventory_slot_array(flow.inventory.slots);
        result["inventory"] = inventory_dictionary(flow.inventory);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::set_action_button(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t button,
    int64_t action,
    int64_t type)
{
    try
    {
        if (button < 0 || button >= static_cast<int64_t>(MaxActionButtons))
        {
            return failure("action button must be from 0 to 143");
        }
        if (action < 0 || action >= 0x01000000)
        {
            return failure("action id must fit in 24 bits");
        }
        if (type < 0 || type > 255)
        {
            return failure("action type must be from 0 to 255");
        }

        acore_protocol::SetActionButtonProbeResult flow = acore_protocol::set_action_button_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint8_t>(button),
            static_cast<std::uint32_t>(action),
            static_cast<std::uint8_t>(type));

        Dictionary result;
        result["ok"] = flow.set_sent && flow.set_confirmed && flow.restore_sent && flow.restore_confirmed;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["button"] = static_cast<int>(flow.button);
        result["action"] = static_cast<int>(flow.action);
        result["type"] = static_cast<int>(flow.type);
        result["before_seen"] = flow.before_seen;
        result["original"] = action_button_dictionary(flow.original);
        result["original_populated"] = flow.original.populated;
        result["original_action"] = static_cast<int>(flow.original.action);
        result["original_type"] = static_cast<int>(flow.original.type);
        result["set_sent"] = flow.set_sent;
        result["set_confirmed"] = flow.set_confirmed;
        result["after_set"] = action_button_dictionary(flow.after_set);
        result["after_set_populated"] = flow.after_set.populated;
        result["after_set_action"] = static_cast<int>(flow.after_set.action);
        result["after_set_type"] = static_cast<int>(flow.after_set.type);
        result["restore_sent"] = flow.restore_sent;
        result["restore_confirmed"] = flow.restore_confirmed;
        result["after_restore"] = action_button_dictionary(flow.after_restore);
        result["after_restore_populated"] = flow.after_restore.populated;
        result["after_restore_action"] = static_cast<int>(flow.after_restore.action);
        result["after_restore_type"] = static_cast<int>(flow.after_restore.type);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::swap_inventory_slots(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t source_slot,
    int64_t destination_slot)
{
    try
    {
        if (source_slot < 0 || source_slot >= static_cast<int64_t>(PlayerInventorySnapshotSlots))
        {
            return failure("source inventory slot must be from 0 to 38");
        }
        if (destination_slot < 0 || destination_slot >= static_cast<int64_t>(PlayerInventorySnapshotSlots))
        {
            return failure("destination inventory slot must be from 0 to 38");
        }

        acore_protocol::InventorySwapProbeResult flow = acore_protocol::swap_inventory_slots_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint8_t>(source_slot),
            static_cast<std::uint8_t>(destination_slot));

        Dictionary result;
        result["ok"] = flow.swap_sent && flow.swap_confirmed && flow.restore_sent && flow.restore_confirmed;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["source_slot"] = static_cast<int>(flow.source_slot);
        result["destination_slot"] = static_cast<int>(flow.destination_slot);
        result["before_seen"] = flow.before_seen;
        result["swap_sent"] = flow.swap_sent;
        result["swap_confirmed"] = flow.swap_confirmed;
        result["restore_sent"] = flow.restore_sent;
        result["restore_confirmed"] = flow.restore_confirmed;
        result["source_before"] = inventory_slot_dictionary(flow.source_before);
        result["destination_before"] = inventory_slot_dictionary(flow.destination_before);
        result["source_after_swap"] = inventory_slot_dictionary(flow.source_after_swap);
        result["destination_after_swap"] = inventory_slot_dictionary(flow.destination_after_swap);
        result["source_after_restore"] = inventory_slot_dictionary(flow.source_after_restore);
        result["destination_after_restore"] = inventory_slot_dictionary(flow.destination_after_restore);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::split_inventory_stack(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t source_slot,
    int64_t destination_slot,
    int64_t split_count)
{
    try
    {
        if (source_slot < 0 || source_slot >= static_cast<int64_t>(PlayerInventorySnapshotSlots))
        {
            return failure("source inventory slot must be from 0 to 38");
        }
        if (destination_slot < 0 || destination_slot >= static_cast<int64_t>(PlayerInventorySnapshotSlots))
        {
            return failure("destination inventory slot must be from 0 to 38");
        }
        if (split_count <= 0 || split_count > 999)
        {
            return failure("split count must be from 1 to 999");
        }

        acore_protocol::InventorySplitProbeResult flow = acore_protocol::split_inventory_stack_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint8_t>(source_slot),
            static_cast<std::uint8_t>(destination_slot),
            static_cast<std::uint32_t>(split_count));

        Dictionary result;
        result["ok"] = flow.split_sent && flow.split_confirmed && flow.merge_sent && flow.merge_confirmed;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["source_slot"] = static_cast<int>(flow.source_slot);
        result["destination_slot"] = static_cast<int>(flow.destination_slot);
        result["split_count"] = static_cast<int>(flow.split_count);
        result["before_seen"] = flow.before_seen;
        result["split_sent"] = flow.split_sent;
        result["split_confirmed"] = flow.split_confirmed;
        result["merge_sent"] = flow.merge_sent;
        result["merge_confirmed"] = flow.merge_confirmed;
        result["source_before"] = inventory_slot_dictionary(flow.source_before);
        result["destination_before"] = inventory_slot_dictionary(flow.destination_before);
        result["source_after_split"] = inventory_slot_dictionary(flow.source_after_split);
        result["destination_after_split"] = inventory_slot_dictionary(flow.destination_after_split);
        result["source_after_merge"] = inventory_slot_dictionary(flow.source_after_merge);
        result["destination_after_merge"] = inventory_slot_dictionary(flow.destination_after_merge);
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::cast_spell(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t spell_id)
{
    try
    {
        if (spell_id <= 0)
        {
            return failure("spell id must be positive");
        }

        acore_protocol::SpellCastProbeResult flow = acore_protocol::cast_spell_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint32_t>(spell_id));

        Dictionary result;
        result["ok"] = flow.cast_sent && flow.accepted;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["spell_id"] = static_cast<int>(flow.spell_id);
        result["cast_sent"] = flow.cast_sent;
        result["logged_in_world"] = flow.logged_in_world;
        result["response_seen"] = flow.response_seen;
        result["accepted"] = flow.accepted;
        result["response"] = spell_cast_response_dictionary(flow.response);
        result["response_opcode"] = static_cast<int>(flow.response.opcode);
        result["response_spell_id"] = static_cast<int>(flow.response.spell_id);
        result["cast_count"] = static_cast<int>(flow.response.cast_count);
        result["cast_flags"] = static_cast<int64_t>(flow.response.cast_flags);
        result["fail_reason"] = static_cast<int>(flow.response.fail_reason);
        result["spell_start"] = flow.response.spell_start;
        result["spell_go"] = flow.response.spell_go;
        result["cast_failed"] = flow.response.cast_failed;
        result["spell_failure"] = flow.response.spell_failure;
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::cast_spell_at_target(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name,
    int64_t spell_id,
    int64_t target_entry,
    String const& target_name)
{
    try
    {
        if (spell_id <= 0)
        {
            return failure("spell id must be positive");
        }
        if (target_entry <= 0)
        {
            return failure("target entry must be positive");
        }

        acore_protocol::TargetedSpellCastProbeResult flow = acore_protocol::cast_spell_at_target_probe(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name),
            static_cast<std::uint32_t>(spell_id),
            static_cast<std::uint64_t>(target_entry),
            to_std_string(target_name));

        Dictionary result;
        result["ok"] = flow.cast_sent && flow.accepted;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["spell_id"] = static_cast<int>(flow.spell_id);
        result["target_guid"] = guid_to_hex(flow.target_guid);
        result["target_entry"] = static_cast<int>(flow.target_entry);
        result["target_name"] = String(flow.target_name.c_str());
        result["live_target_found"] = flow.live_target_found;
        result["selection_sent"] = flow.selection_sent;
        result["attack_sent"] = flow.attack_sent;
        result["cast_sent"] = flow.cast_sent;
        result["logged_in_world"] = flow.logged_in_world;
        result["response_seen"] = flow.response_seen;
        result["accepted"] = flow.accepted;
        result["response"] = spell_cast_response_dictionary(flow.response);
        result["response_opcode"] = static_cast<int>(flow.response.opcode);
        result["response_spell_id"] = static_cast<int>(flow.response.spell_id);
        result["cast_count"] = static_cast<int>(flow.response.cast_count);
        result["cast_flags"] = static_cast<int64_t>(flow.response.cast_flags);
        result["fail_reason"] = static_cast<int>(flow.response.fail_reason);
        result["spell_start"] = flow.response.spell_start;
        result["spell_go"] = flow.response.spell_go;
        result["cast_failed"] = flow.response.cast_failed;
        result["spell_failure"] = flow.response.spell_failure;
        result["visible_objects"] = visible_object_array(flow.visible_objects);
        result["visible_object_count"] = static_cast<int>(flow.visible_objects.size());
        result["skipped_opcodes"] = opcode_array(flow.skipped_opcodes);
        result["realm"] = realm_dictionary(flow.realm);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::create_character(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& name)
{
    try
    {
        acore_protocol::CharacterCreateResult flow = acore_protocol::create_character(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(name));

        Dictionary result;
        result["ok"] = flow.success;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["char_create_ok"] = flow.success;
        result["name"] = String(flow.name.c_str());
        result["response"] = static_cast<int>(flow.response);
        result["character_count"] = static_cast<int>(flow.characters.size());
        result["realm"] = realm_dictionary(flow.realm);
        result["characters"] = character_array(flow.characters);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::enter_world(
    String const& host,
    String const& port,
    String const& account,
    String const& password,
    String const& character_name)
{
    try
    {
        acore_protocol::EnterWorldResult flow = acore_protocol::enter_world(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password),
            to_std_string(character_name));

        Dictionary result;
        result["ok"] = true;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["world_login_ok"] = true;
        result["login_verify_ok"] = true;
        result["update_object_seen"] = flow.update.seen;
        result["realm"] = realm_dictionary(flow.realm);
        result["character"] = character_dictionary(flow.character);
        result["login"] = login_verify_dictionary(flow.login);
        result["update"] = update_dictionary(flow.update);
        result["skipped_login_opcodes"] = opcode_array(flow.skipped_login_opcodes);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}

Dictionary AcoreProtocolClient::character_flow(
    String const& host,
    String const& port,
    String const& account,
    String const& password)
{
    try
    {
        acore_protocol::CharacterFlowResult flow = acore_protocol::run_character_flow(
            to_std_string(host),
            to_std_string(port),
            to_std_string(account),
            to_std_string(password));

        Dictionary result;
        result["ok"] = true;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["char_enum_ok"] = true;
        result["character_count"] = static_cast<int>(flow.characters.size());
        result["realm"] = realm_dictionary(flow.realm);
        result["skipped_auth_opcodes"] = opcode_array(flow.skipped_auth_opcodes);
        result["skipped_character_opcodes"] = opcode_array(flow.skipped_character_opcodes);
        result["characters"] = character_array(flow.characters);
        return result;
    }
    catch (std::exception const& exc)
    {
        return failure(exc.what());
    }
}
