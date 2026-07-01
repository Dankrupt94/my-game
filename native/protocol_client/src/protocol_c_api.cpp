#include "protocol_c_api.h"

#include "protocol_flow.h"

#include <cstdint>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace
{
int copy_to_output(std::string const& json, char* output, std::size_t output_size)
{
    if (!output || output_size == 0)
    {
        return ACORE_PROTOCOL_BRIDGE_INVALID_ARGUMENT;
    }

    if (json.size() + 1 > output_size)
    {
        output[0] = '\0';
        return ACORE_PROTOCOL_BRIDGE_BUFFER_TOO_SMALL;
    }

    std::memcpy(output, json.c_str(), json.size() + 1);
    return ACORE_PROTOCOL_BRIDGE_OK;
}

std::string json_escape(std::string const& value)
{
    std::ostringstream out;
    for (unsigned char ch : value)
    {
        switch (ch)
        {
            case '"':
                out << "\\\"";
                break;
            case '\\':
                out << "\\\\";
                break;
            case '\b':
                out << "\\b";
                break;
            case '\f':
                out << "\\f";
                break;
            case '\n':
                out << "\\n";
                break;
            case '\r':
                out << "\\r";
                break;
            case '\t':
                out << "\\t";
                break;
            default:
                if (ch < 0x20)
                {
                    out << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(ch);
                }
                else
                {
                    out << static_cast<char>(ch);
                }
                break;
        }
    }
    return out.str();
}

std::string quoted(std::string const& value)
{
    return "\"" + json_escape(value) + "\"";
}

std::string error_json(std::string const& message)
{
    return "{\"ok\":false,\"error\":" + quoted(message) + "}";
}

std::string opcode_array_json(std::vector<std::uint16_t> const& opcodes)
{
    std::ostringstream out;
    out << "[";
    for (std::size_t i = 0; i < opcodes.size(); ++i)
    {
        if (i != 0)
        {
            out << ",";
        }
        out << opcodes[i];
    }
    out << "]";
    return out.str();
}

std::string character_guid_hex(std::uint64_t guid)
{
    std::ostringstream out;
    out << "0x" << std::hex << guid;
    return out.str();
}

std::string character_flow_json(acore_protocol::CharacterFlowResult const& result)
{
    std::ostringstream out;
    out << "{"
        << "\"ok\":true,"
        << "\"auth_flow_ok\":true,"
        << "\"world_auth_ok\":true,"
        << "\"char_enum_ok\":true,"
        << "\"character_count\":" << result.characters.size() << ","
        << "\"realm\":{"
        << "\"name\":" << quoted(result.realm.name) << ","
        << "\"endpoint\":" << quoted(result.realm.endpoint) << ","
        << "\"realm_id\":" << result.realm.realm_id << ","
        << "\"type\":" << static_cast<int>(result.realm.realm_type) << ","
        << "\"lock\":" << static_cast<int>(result.realm.lock) << ","
        << "\"flags\":" << static_cast<int>(result.realm.flags) << ","
        << "\"character_count\":" << static_cast<int>(result.realm.character_count) << ","
        << "\"timezone\":" << static_cast<int>(result.realm.timezone)
        << "},"
        << "\"skipped_auth_opcodes\":" << opcode_array_json(result.skipped_auth_opcodes) << ","
        << "\"skipped_character_opcodes\":" << opcode_array_json(result.skipped_character_opcodes) << ","
        << "\"characters\":[";

    for (std::size_t i = 0; i < result.characters.size(); ++i)
    {
        CharacterSummary const& character = result.characters[i];
        if (i != 0)
        {
            out << ",";
        }
        out << "{"
            << "\"guid\":" << quoted(character_guid_hex(character.guid)) << ","
            << "\"name\":" << quoted(character.name) << ","
            << "\"level\":" << static_cast<int>(character.level) << ","
            << "\"race\":" << static_cast<int>(character.race) << ","
            << "\"class\":" << static_cast<int>(character.character_class) << ","
            << "\"map\":" << character.map << ","
            << "\"x\":" << character.x << ","
            << "\"y\":" << character.y << ","
            << "\"z\":" << character.z
            << "}";
    }

    out << "]}";
    return out.str();
}
}

extern "C"
{
int acore_protocol_bridge_self_test_json(char* output, std::size_t output_size)
{
    try
    {
        auto challenge = acore_protocol::build_auth_logon_challenge("TEST");
        if (challenge.size() != 38)
        {
            throw std::runtime_error("unexpected auth logon challenge size");
        }

        return copy_to_output(
            "{\"ok\":true,\"logon_challenge_size\":38,\"bridge\":\"acore_protocol_bridge\"}",
            output,
            output_size);
    }
    catch (std::exception const& exc)
    {
        int const copied = copy_to_output(error_json(exc.what()), output, output_size);
        return copied == ACORE_PROTOCOL_BRIDGE_OK ? ACORE_PROTOCOL_BRIDGE_ERROR : copied;
    }
}

int acore_protocol_bridge_character_flow_json(
    char const* host,
    char const* port,
    char const* account,
    char const* password,
    char* output,
    std::size_t output_size)
{
    if (!host || !port || !account || !password)
    {
        int const copied = copy_to_output(error_json("host, port, account, and password are required"), output, output_size);
        return copied == ACORE_PROTOCOL_BRIDGE_OK ? ACORE_PROTOCOL_BRIDGE_INVALID_ARGUMENT : copied;
    }

    try
    {
        acore_protocol::CharacterFlowResult result = acore_protocol::run_character_flow(host, port, account, password);
        return copy_to_output(character_flow_json(result), output, output_size);
    }
    catch (std::exception const& exc)
    {
        int const copied = copy_to_output(error_json(exc.what()), output, output_size);
        return copied == ACORE_PROTOCOL_BRIDGE_OK ? ACORE_PROTOCOL_BRIDGE_ERROR : copied;
    }
}
}
