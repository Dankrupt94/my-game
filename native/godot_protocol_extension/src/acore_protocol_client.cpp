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

Array action_button_array(std::vector<ActionButtonSummary> const& buttons)
{
    Array values;
    for (ActionButtonSummary const& button : buttons)
    {
        Dictionary value;
        value["button"] = static_cast<int>(button.button);
        value["action"] = static_cast<int>(button.action);
        value["type"] = static_cast<int>(button.type);
        value["packed"] = static_cast<int64_t>(button.packed);
        value["populated"] = button.populated;
        values.append(value);
    }
    return values;
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
        D_METHOD("cast_spell", "host", "port", "account", "password", "character_name", "spell_id"),
        &AcoreProtocolClient::cast_spell);
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
        result["ok"] = flow.live_target_found && flow.attack_sent && flow.combat_response_seen;
        result["auth_flow_ok"] = true;
        result["world_auth_ok"] = true;
        result["character"] = character_dictionary(flow.character);
        result["target_guid"] = guid_to_hex(flow.target_guid);
        result["target_entry"] = static_cast<int>(flow.target_entry);
        result["target_name"] = String(flow.target_name.c_str());
        result["live_target_found"] = flow.live_target_found;
        result["selection_sent"] = flow.selection_sent;
        result["attack_sent"] = flow.attack_sent;
        result["combat_response_seen"] = flow.combat_response_seen;
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
