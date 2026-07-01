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
}

void AcoreProtocolClient::_bind_methods()
{
    ClassDB::bind_method(D_METHOD("self_test"), &AcoreProtocolClient::self_test);
    ClassDB::bind_method(
        D_METHOD("character_flow", "host", "port", "account", "password"),
        &AcoreProtocolClient::character_flow);
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
