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
