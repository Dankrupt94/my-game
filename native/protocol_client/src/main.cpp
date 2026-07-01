#include "auth_crypt.h"
#include "protocol_bytes.h"
#include "protocol_flow.h"
#include "srp6.h"
#include "world_packets.h"

#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <span>
#include <stdexcept>
#include <string>

namespace
{
std::string protocol_password()
{
    char const* password = std::getenv("ACORE_PROTOCOL_PASSWORD");
    if (!password || std::string(password).empty())
    {
        throw std::runtime_error("ACORE_PROTOCOL_PASSWORD is not set");
    }
    return password;
}

int self_test()
{
    auto logon_challenge = acore_protocol::build_auth_logon_challenge("TEST");
    if (logon_challenge.size() != 38 || logon_challenge[17] != 'n' || logon_challenge[18] != 'i'
        || logon_challenge[19] != 'W' || logon_challenge[20] != 0)
    {
        throw std::runtime_error("auth logon challenge OS encoding failed");
    }

    auto client_header = build_client_header(CMSG_CHAR_ENUM, 0);
    if (hex(client_header) != "000437000000")
    {
        throw std::runtime_error("client header encoding failed");
    }

    auto server_header = build_server_header_for_test(acore_protocol::SMSG_AUTH_CHALLENGE, 40);
    if (hex(server_header) != "002aec01")
    {
        throw std::runtime_error("server header encoding failed");
    }

    ServerHeader parsed = parse_server_header(server_header);
    if (parsed.size != 42 || parsed.opcode != acore_protocol::SMSG_AUTH_CHALLENGE || parsed.header_length != 4)
    {
        throw std::runtime_error("server header parsing failed");
    }

    std::array<std::uint8_t, AuthCrypt::SessionKeyLength> session_key{};
    for (std::size_t i = 0; i < session_key.size(); ++i)
    {
        session_key[i] = static_cast<std::uint8_t>(i);
    }

    AuthCrypt crypt;
    crypt.init(session_key);
    auto encrypted = client_header;
    crypt.encrypt_client_header(encrypted);
    if (encrypted == client_header)
    {
        throw std::runtime_error("client header was not encrypted");
    }

    std::cout << "PROTOCOL_CLIENT_SELF_TEST_OK encrypted_char_enum_header="
              << hex(encrypted) << "\n";
    if (!srp6::self_test())
    {
        throw std::runtime_error("SRP6 self-test failed");
    }
    std::cout << "SRP6_SELF_TEST_OK\n";
    if (!world_packet_self_test())
    {
        throw std::runtime_error("world packet self-test failed");
    }
    std::cout << "WORLD_PACKET_SELF_TEST_OK\n";
    return 0;
}

int auth_challenge(std::string const& host, std::string const& port, std::string const& account)
{
    acore_protocol::AuthChallengeSummary challenge = acore_protocol::probe_auth_challenge(host, port, account);
    std::cout << "AUTH_CHALLENGE_OK"
              << " b_len=32"
              << " g=0x07"
              << " n_len=32"
              << " salt_len=32"
              << " security_flags=0x" << hex(std::span<const std::uint8_t>(&challenge.security_flags, 1))
              << "\n";
    return 0;
}

int auth_flow(std::string const& host, std::string const& port, std::string const& account)
{
    acore_protocol::AuthFlowResult result = acore_protocol::run_auth_flow(host, port, account, protocol_password());
    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    return 0;
}

int character_flow(std::string const& host, std::string const& port, std::string const& account)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::CharacterFlowResult result = acore_protocol::run_character_flow(
        host,
        port,
        account,
        protocol_password(),
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "WORLD_AUTH_OK\n";
    std::cout << "CHAR_ENUM_OK count=" << result.characters.size() << "\n";
    for (CharacterSummary const& character : result.characters)
    {
        std::cout << "CHAR guid=0x" << std::hex << character.guid << std::dec
                  << " name=\"" << character.name << "\""
                  << " level=" << static_cast<int>(character.level)
                  << " race=" << static_cast<int>(character.race)
                  << " class=" << static_cast<int>(character.character_class)
                  << " map=" << character.map
                  << " pos=(" << character.x << "," << character.y << "," << character.z << ")"
                  << "\n";
    }
    return 0;
}

int create_character(std::string const& host, std::string const& port, std::string const& account, std::string const& name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::CharacterCreateResult result = acore_protocol::create_character(
        host,
        port,
        account,
        protocol_password(),
        name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "CHAR_CREATE_" << (result.success ? "OK" : "FAILED")
              << " name=\"" << result.name << "\""
              << " response=0x" << hex(std::span<const std::uint8_t>(&result.response, 1))
              << "\n";
    std::cout << "CHAR_ENUM_OK count=" << result.characters.size() << "\n";
    for (CharacterSummary const& character : result.characters)
    {
        std::cout << "CHAR guid=0x" << std::hex << character.guid << std::dec
                  << " name=\"" << character.name << "\""
                  << " level=" << static_cast<int>(character.level)
                  << " race=" << static_cast<int>(character.race)
                  << " class=" << static_cast<int>(character.character_class)
                  << " map=" << character.map
                  << " pos=(" << character.x << "," << character.y << "," << character.z << ")"
                  << "\n";
    }
    return result.success ? 0 : 1;
}

int enter_world(std::string const& host, std::string const& port, std::string const& account, std::string const& character_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::EnterWorldResult result = acore_protocol::enter_world(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "WORLD_LOGIN_OK"
              << " guid=0x" << std::hex << result.character.guid << std::dec
              << " name=\"" << result.character.name << "\""
              << " level=" << static_cast<int>(result.character.level)
              << " race=" << static_cast<int>(result.character.race)
              << " class=" << static_cast<int>(result.character.character_class)
              << "\n";
    std::cout << "LOGIN_VERIFY_WORLD_OK"
              << " map=" << result.login.map
              << " pos=(" << result.login.x << "," << result.login.y << "," << result.login.z << ")"
              << " orientation=" << result.login.orientation
              << "\n";
    std::cout << "UPDATE_OBJECT_" << (result.update.seen ? "SEEN" : "MISSING")
              << " compressed=" << (result.update.compressed ? 1 : 0)
              << " blocks=" << result.update.block_count
              << " first_type=" << static_cast<int>(result.update.first_update_type)
              << " first_guid=0x" << std::hex << result.update.first_guid << std::dec
              << " contains_player=" << (result.update.contains_player_guid ? 1 : 0)
              << " visible_parse_complete=" << (result.update.visible_parse_complete ? 1 : 0)
              << " visible_objects=" << result.update.visible_objects.size()
              << "\n";
    std::size_t printed = 0;
    for (VisibleObjectSummary const& object : result.update.visible_objects)
    {
        if (printed >= 8)
        {
            break;
        }
        std::cout << "VISIBLE_OBJECT"
                  << " guid=0x" << std::hex << object.guid << std::dec
                  << " entry=" << object.entry
                  << " type=" << static_cast<int>(object.object_type)
                  << " has_position=" << (object.has_position ? 1 : 0)
                  << " pos=(" << object.x << "," << object.y << "," << object.z << ")"
                  << "\n";
        ++printed;
    }
    return 0;
}

int move_heartbeat(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& delta_x,
    std::string const& delta_y,
    std::string const& delta_orientation)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::MovementHeartbeatResult result = acore_protocol::move_heartbeat(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        std::stof(delta_x),
        std::stof(delta_y),
        std::stof(delta_orientation),
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "MOVE_STEP_SENT"
              << " guid=0x" << std::hex << result.before.guid << std::dec
              << " name=\"" << result.before.name << "\""
              << " before=(" << result.before.x << "," << result.before.y << "," << result.before.z << ")"
              << " target=(" << result.target.x << "," << result.target.y << "," << result.target.z << ")"
              << " live=(" << result.live.x << "," << result.live.y << "," << result.live.z << ")"
              << " after=(" << result.after.x << "," << result.after.y << "," << result.after.z << ")"
              << " drift=" << result.live_drift
              << " live_drift=" << result.live_drift
              << " saved_drift=" << result.saved_drift
              << " live_position_accepted=" << (result.live_position_accepted ? 1 : 0)
              << " saved_position_changed=" << (result.saved_position_changed ? 1 : 0)
              << "\n";
    return result.live_position_accepted ? 0 : 1;
}

std::uint64_t parse_guid_arg(std::string const& value)
{
    std::size_t parsed = 0;
    int const base = value.rfind("0x", 0) == 0 || value.rfind("0X", 0) == 0 ? 16 : 10;
    std::uint64_t guid = std::stoull(value, &parsed, base);
    if (parsed != value.size())
    {
        throw std::runtime_error("target guid or entry contains trailing characters");
    }
    return guid;
}

int npc_interaction(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_guid,
    std::string const& target_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::InteractionResult result = acore_protocol::interact_with_npc(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "NPC_INTERACTION_SENT"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " gossip_sent=" << (result.gossip_sent ? 1 : 0)
              << " gossip_response_seen=" << (result.gossip_response_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    std::size_t printed = 0;
    std::size_t unit_count = 0;
    for (VisibleObjectSummary const& object : result.visible_objects)
    {
        if (object.object_type == 3)
        {
            ++unit_count;
        }
    }
    std::cout << "VISIBLE_OBJECT_SUMMARY"
              << " total=" << result.visible_objects.size()
              << " units=" << unit_count
              << "\n";
    for (VisibleObjectSummary const& object : result.visible_objects)
    {
        if (printed >= 12)
        {
            break;
        }
        if (object.object_type != 3)
        {
            continue;
        }
        std::cout << "VISIBLE_OBJECT"
                  << " guid=0x" << std::hex << object.guid << std::dec
                  << " entry=" << object.entry
                  << " type=" << static_cast<int>(object.object_type)
                  << " has_position=" << (object.has_position ? 1 : 0)
                  << " pos=(" << object.x << "," << object.y << "," << object.z << ")"
                  << "\n";
        ++printed;
    }
    return result.selection_sent && result.gossip_sent && result.gossip_response_seen ? 0 : 1;
}

int combat_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_guid,
    std::string const& target_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::CombatProbeResult result = acore_protocol::combat_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "COMBAT_PROBE_SENT"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " attack_sent=" << (result.attack_sent ? 1 : 0)
              << " combat_response_seen=" << (result.combat_response_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.live_target_found && result.attack_sent && result.combat_response_seen ? 0 : 1;
}

int world_challenge(std::string const& host, std::string const& port)
{
    acore_protocol::WorldChallengeSummary summary = acore_protocol::probe_world_challenge(host, port);

    std::cout << "WORLD_CHALLENGE_OK opcode=0x1ec payload_size=40"
              << " marker=" << summary.marker
              << " seed=" << hex(std::span<const std::uint8_t>(summary.seed.data(), summary.seed.size()))
              << "\n";
    return 0;
}

void usage()
{
    std::cerr << "Usage:\n"
              << "  acore_protocol_client --self-test\n"
              << "  acore_protocol_client --auth-challenge <host> <port> <account>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --auth-flow <host> <port> <account>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --character-flow <host> <port> <account>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --create-character <host> <port> <account> <name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --enter-world <host> <port> <account> [character-name]\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --move-heartbeat <host> <port> <account> <character-name> <delta-x> <delta-y> <delta-orientation>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --npc-interaction <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --combat-probe <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  acore_protocol_client --world-challenge <host> <port>\n";
}
}

int main(int argc, char** argv)
{
    try
    {
        if (argc == 2 && std::strcmp(argv[1], "--self-test") == 0)
        {
            return self_test();
        }

        if (argc == 4 && std::strcmp(argv[1], "--world-challenge") == 0)
        {
            return world_challenge(argv[2], argv[3]);
        }

        if (argc == 5 && std::strcmp(argv[1], "--auth-challenge") == 0)
        {
            return auth_challenge(argv[2], argv[3], argv[4]);
        }

        if (argc == 5 && std::strcmp(argv[1], "--auth-flow") == 0)
        {
            return auth_flow(argv[2], argv[3], argv[4]);
        }

        if (argc == 5 && std::strcmp(argv[1], "--character-flow") == 0)
        {
            return character_flow(argv[2], argv[3], argv[4]);
        }

        if (argc == 6 && std::strcmp(argv[1], "--create-character") == 0)
        {
            return create_character(argv[2], argv[3], argv[4], argv[5]);
        }

        if ((argc == 5 || argc == 6) && std::strcmp(argv[1], "--enter-world") == 0)
        {
            return enter_world(argv[2], argv[3], argv[4], argc == 6 ? argv[5] : "");
        }

        if (argc == 9 && std::strcmp(argv[1], "--move-heartbeat") == 0)
        {
            return move_heartbeat(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--npc-interaction") == 0)
        {
            return npc_interaction(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--combat-probe") == 0)
        {
            return combat_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        usage();
        return 2;
    }
    catch (std::exception const& exc)
    {
        std::cerr << "ERROR: " << exc.what() << "\n";
        return 1;
    }
}
