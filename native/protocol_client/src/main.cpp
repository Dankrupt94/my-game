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

int trainer_list_probe(
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
    acore_protocol::TrainerListProbeResult result = acore_protocol::trainer_list_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "TRAINER_LIST_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " trainer_list_sent=" << (result.trainer_list_sent ? 1 : 0)
              << " trainer_list_response_seen=" << (result.trainer_list_response_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " trainer_type=" << result.trainer_list.trainer_type
              << " spell_count=" << result.trainer_list.spell_count
              << " greeting=\"" << result.trainer_list.greeting << "\""
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    std::size_t printed = 0;
    for (TrainerSpellSummary const& spell : result.trainer_list.spells)
    {
        if (printed >= 40)
        {
            break;
        }
        std::cout << "TRAINER_SPELL"
                  << " spell_id=" << spell.spell_id
                  << " usable=" << static_cast<int>(spell.usable)
                  << " money_cost=" << spell.money_cost
                  << " req_level=" << static_cast<int>(spell.req_level)
                  << " req_skill_line=" << spell.req_skill_line
                  << " req_skill_rank=" << spell.req_skill_rank
                  << " req_ability_1=" << spell.req_ability[0]
                  << " req_ability_2=" << spell.req_ability[1]
                  << " req_ability_3=" << spell.req_ability[2]
                  << "\n";
        ++printed;
    }
    return result.live_target_found && result.selection_sent && result.trainer_list_sent
        && result.trainer_list_response_seen && result.trainer_list.spell_count > 0 ? 0 : 1;
}

int questgiver_list_probe(
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
    acore_protocol::QuestGiverListProbeResult result = acore_protocol::questgiver_list_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "QUESTGIVER_LIST_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " questgiver_hello_sent=" << (result.questgiver_hello_sent ? 1 : 0)
              << " quest_list_response_seen=" << (result.quest_list_response_seen ? 1 : 0)
              << " gossip_fallback_seen=" << (result.gossip_fallback_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " greeting=\"" << result.quest_list.greeting << "\""
              << " quest_count=" << result.quest_list.quest_count
              << " gossip_menu_id=" << result.gossip.menu_id
              << " gossip_quest_count=" << result.gossip.quest_count
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    std::size_t printed = 0;
    for (QuestGiverQuestSummary const& quest : result.quest_list.quests)
    {
        if (printed >= 40)
        {
            break;
        }
        // Quest IDs/icons/levels/flags only. Titles are proprietary text and are
        // deliberately not printed or committed.
        std::cout << "QUESTGIVER_QUEST"
                  << " quest_id=" << quest.quest_id
                  << " icon=" << quest.quest_icon
                  << " level=" << quest.quest_level
                  << " flags=" << quest.quest_flags
                  << " repeatable=" << static_cast<int>(quest.repeatable)
                  << "\n";
        ++printed;
    }
    std::size_t gossip_printed = 0;
    for (GossipQuestItemSummary const& quest : result.gossip.quests)
    {
        if (gossip_printed >= 40)
        {
            break;
        }
        // Quest ids/levels/flags only; titles are proprietary and are not printed.
        std::cout << "GOSSIP_QUEST"
                  << " quest_id=" << quest.quest_id
                  << " icon=" << quest.quest_icon
                  << " level=" << quest.quest_level
                  << " flags=" << quest.quest_flags
                  << " repeatable=" << static_cast<int>(quest.repeatable)
                  << "\n";
        ++gossip_printed;
    }

    // Live AzerothCore quest givers answer CMSG_QUESTGIVER_HELLO with gossip-embedded
    // quests (SMSG_GOSSIP_MESSAGE); the standalone SMSG_QUESTGIVER_QUEST_LIST is rarer.
    // Success means the quest giver was reached and returned offered quests via either
    // path. Both parsers are also covered by --self-test.
    return result.live_target_found && result.selection_sent && result.questgiver_hello_sent
        && ((result.quest_list_response_seen && result.quest_list.quest_count > 0)
            || (result.gossip_fallback_seen && result.gossip.quest_count > 0)) ? 0 : 1;
}

int questgiver_details_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_selector,
    std::string const& quest_id,
    std::string const& target_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::QuestGiverDetailsProbeResult result = acore_protocol::questgiver_details_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_selector),
        static_cast<std::uint32_t>(std::stoul(quest_id)),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "QUESTGIVER_DETAILS_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " query_quest_id=" << result.query_quest_id
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " questgiver_hello_sent=" << (result.questgiver_hello_sent ? 1 : 0)
              << " query_quest_sent=" << (result.query_quest_sent ? 1 : 0)
              << " details_response_seen=" << (result.details_response_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " details_quest_id=" << result.details.quest_id
              << " reward_choice_count=" << result.details.reward_choice_count
              << " reward_item_count=" << result.details.reward_item_count
              << " money_reward=" << result.details.money_reward
              << " xp_reward=" << result.details.xp_reward
              << " reward_spell=" << result.details.reward_spell
              << "\n";
    // Reward item ids/counts only; quest text is never printed.
    for (QuestRewardItemSummary const& item : result.details.reward_items)
    {
        std::cout << "QUEST_REWARD_ITEM item_id=" << item.item_id << " count=" << item.item_count << "\n";
    }
    for (QuestRewardItemSummary const& item : result.details.reward_choice_items)
    {
        std::cout << "QUEST_CHOICE_ITEM item_id=" << item.item_id << " count=" << item.item_count << "\n";
    }
    return result.live_target_found && result.query_quest_sent && result.details_response_seen
        && result.details.quest_id == result.query_quest_id ? 0 : 1;
}

int questgiver_accept_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_selector,
    std::string const& quest_id,
    std::string const& target_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::QuestGiverAcceptProbeResult result = acore_protocol::questgiver_accept_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_selector),
        static_cast<std::uint32_t>(std::stoul(quest_id)),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "QUESTGIVER_ACCEPT_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " quest_id=" << result.quest_id
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " questgiver_hello_sent=" << (result.questgiver_hello_sent ? 1 : 0)
              << " accept_sent=" << (result.accept_sent ? 1 : 0)
              << " quest_in_log_after_accept=" << (result.quest_in_log_after_accept ? 1 : 0)
              << " accepted_slot=" << result.accepted_slot
              << " remove_sent=" << (result.remove_sent ? 1 : 0)
              << " quest_removed_after_remove=" << (result.quest_removed_after_remove ? 1 : 0)
              << " accept_response_opcode=0x" << std::hex << result.accept_response_opcode << std::dec
              << "\n";
    return result.live_target_found && result.accept_sent && result.quest_in_log_after_accept
        && result.remove_sent && result.quest_removed_after_remove ? 0 : 1;
}

int questgiver_reward_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_selector,
    std::string const& quest_id,
    std::string const& target_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::QuestGiverRewardProbeResult result = acore_protocol::questgiver_reward_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_selector),
        static_cast<std::uint32_t>(std::stoul(quest_id)),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "QUESTGIVER_REWARD_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " quest_id=" << result.quest_id
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " questgiver_hello_sent=" << (result.questgiver_hello_sent ? 1 : 0)
              << " accept_sent=" << (result.accept_sent ? 1 : 0)
              << " quest_in_log_after_accept=" << (result.quest_in_log_after_accept ? 1 : 0)
              << " accepted_slot=" << result.accepted_slot
              << " complete_request_sent=" << (result.complete_request_sent ? 1 : 0)
              << " offer_reward_seen=" << (result.offer_reward_seen ? 1 : 0)
              << " request_items_seen=" << (result.request_items_seen ? 1 : 0)
              << " quest_invalid_seen=" << (result.quest_invalid_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " reward_choice_count=" << result.offer_reward.reward_choice_count
              << " reward_item_count=" << result.offer_reward.reward_item_count
              << " money_reward=" << result.offer_reward.money_reward
              << " xp_reward=" << result.offer_reward.xp_reward
              << " reward_spell=" << result.offer_reward.reward_spell
              << " remove_sent=" << (result.remove_sent ? 1 : 0)
              << " quest_removed_after_remove=" << (result.quest_removed_after_remove ? 1 : 0)
              << "\n";
    // Reward item ids/counts only; quest/reward text is never printed.
    for (QuestRewardItemSummary const& item : result.offer_reward.reward_items)
    {
        std::cout << "QUEST_REWARD_ITEM item_id=" << item.item_id << " count=" << item.item_count << "\n";
    }
    for (QuestRewardItemSummary const& item : result.offer_reward.reward_choice_items)
    {
        std::cout << "QUEST_CHOICE_ITEM item_id=" << item.item_id << " count=" << item.item_count << "\n";
    }
    // Success = we reached the completion screen (offer reward or request items)
    // and left the character quest log restored.
    return result.live_target_found && result.complete_request_sent
        && (result.offer_reward_seen || result.request_items_seen)
        && result.quest_removed_after_remove ? 0 : 1;
}

int questgiver_turnin_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_selector,
    std::string const& quest_id,
    std::string const& target_name,
    std::string const& reward_index)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::QuestGiverTurninProbeResult result = acore_protocol::questgiver_turnin_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_selector),
        static_cast<std::uint32_t>(std::stoul(quest_id)),
        static_cast<std::uint32_t>(std::stoul(reward_index)),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "QUESTGIVER_TURNIN_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " quest_id=" << result.quest_id
              << " reward_index=" << result.reward_index
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " quest_in_log_before=" << (result.quest_in_log_before ? 1 : 0)
              << " quest_slot_before=" << result.quest_slot_before
              << " questgiver_hello_sent=" << (result.questgiver_hello_sent ? 1 : 0)
              << " complete_request_sent=" << (result.complete_request_sent ? 1 : 0)
              << " offer_reward_seen=" << (result.offer_reward_seen ? 1 : 0)
              << " choose_reward_sent=" << (result.choose_reward_sent ? 1 : 0)
              << " quest_complete_seen=" << (result.quest_complete_seen ? 1 : 0)
              << " quest_removed_from_log=" << (result.quest_removed_from_log ? 1 : 0)
              << " complete_quest_id=" << result.quest_complete.quest_id
              << " complete_xp=" << result.quest_complete.xp_reward
              << " complete_money=" << result.quest_complete.money_reward
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << "\n";
    // Turn-in succeeds when the reward screen showed, we chose a reward, and the
    // server confirmed completion and cleared the quest from the log.
    return result.live_target_found && result.offer_reward_seen && result.choose_reward_sent
        && result.quest_complete_seen && result.quest_removed_from_log ? 0 : 1;
}

int trainer_buy_spell_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_guid,
    std::string const& target_name,
    std::string const& spell_id)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::TrainerBuySpellProbeResult result = acore_protocol::trainer_buy_spell_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        static_cast<std::uint32_t>(std::stoul(spell_id)),
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "TRAINER_BUY_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " spell_id=" << result.spell_id
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " trainer_list_sent=" << (result.trainer_list_sent ? 1 : 0)
              << " trainer_list_response_seen=" << (result.trainer_list_response_seen ? 1 : 0)
              << " spell_count=" << result.trainer_list.spell_count
              << " buy_spell_sent=" << (result.buy_spell_sent ? 1 : 0)
              << " buy_response_seen=" << (result.buy_response_seen ? 1 : 0)
              << " buy_succeeded=" << (result.buy_response.succeeded ? 1 : 0)
              << " buy_failed=" << (result.buy_response.failed ? 1 : 0)
              << " failure_reason=" << result.buy_response.failure_reason
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.live_target_found && result.selection_sent && result.trainer_list_response_seen
        && result.buy_spell_sent && result.buy_response_seen ? 0 : 1;
}

int vendor_list_probe(
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
    acore_protocol::VendorListProbeResult result = acore_protocol::vendor_list_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "VENDOR_LIST_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " vendor_list_sent=" << (result.vendor_list_sent ? 1 : 0)
              << " vendor_list_response_seen=" << (result.vendor_list_response_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " item_count=" << static_cast<int>(result.vendor_list.item_count)
              << " error_code=" << static_cast<int>(result.vendor_list.error_code)
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    std::size_t printed = 0;
    for (VendorItemSummary const& item : result.vendor_list.items)
    {
        if (printed >= 80)
        {
            break;
        }
        std::cout << "VENDOR_ITEM"
                  << " vendor_slot=" << item.vendor_slot
                  << " item_id=" << item.item_id
                  << " display_id=" << item.display_id
                  << " left_in_stock=" << item.left_in_stock
                  << " buy_price=" << item.buy_price
                  << " max_durability=" << item.max_durability
                  << " buy_count=" << item.buy_count
                  << " extended_cost=" << item.extended_cost
                  << "\n";
        ++printed;
    }
    return result.live_target_found && result.selection_sent && result.vendor_list_sent
        && result.vendor_list_response_seen && result.vendor_list.item_count > 0 ? 0 : 1;
}

int vendor_buy_sell_probe(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& target_guid,
    std::string const& target_name,
    std::string const& vendor_slot,
    std::string const& item_id,
    std::string const& count)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::VendorBuySellProbeResult result = acore_protocol::vendor_buy_sell_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        static_cast<std::uint32_t>(std::stoul(vendor_slot)),
        static_cast<std::uint32_t>(std::stoul(item_id)),
        static_cast<std::uint32_t>(std::stoul(count)),
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "VENDOR_BUY_SELL_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " vendor_slot=" << result.vendor_slot
              << " item_id=" << result.item_id
              << " count=" << result.count
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " vendor_list_sent=" << (result.vendor_list_sent ? 1 : 0)
              << " vendor_list_response_seen=" << (result.vendor_list_response_seen ? 1 : 0)
              << " inventory_before_seen=" << (result.inventory_before_seen ? 1 : 0)
              << " inventory_after_buy_seen=" << (result.inventory_after_buy_seen ? 1 : 0)
              << " inventory_after_sell_seen=" << (result.inventory_after_sell_seen ? 1 : 0)
              << " buy_sent=" << (result.buy_sent ? 1 : 0)
              << " buy_response_seen=" << (result.buy_response_seen ? 1 : 0)
              << " buy_succeeded=" << (result.buy_response.succeeded ? 1 : 0)
              << " buy_failed=" << (result.buy_response.failed ? 1 : 0)
              << " buy_response_opcode=0x" << std::hex << result.buy_response_opcode << std::dec
              << " buy_failure_reason=" << static_cast<int>(result.buy_response.failure_reason)
              << " bought_item_found=" << (result.bought_item_found ? 1 : 0)
              << " bought_slot=" << static_cast<int>(result.bought_slot_after_buy.slot)
              << " bought_guid=0x" << std::hex << result.bought_slot_after_buy.item_guid << std::dec
              << " sell_sent=" << (result.sell_sent ? 1 : 0)
              << " sell_error_seen=" << (result.sell_error_seen ? 1 : 0)
              << " sell_error_reason=" << static_cast<int>(result.sell_error.reason)
              << " sell_confirmed=" << (result.sell_confirmed ? 1 : 0)
              << " roundtrip_confirmed=" << (result.roundtrip_confirmed ? 1 : 0)
              << " before_coinage=" << result.inventory_before.coinage
              << " after_buy_coinage=" << result.inventory_after_buy.coinage
              << " after_sell_coinage=" << result.inventory_after_sell.coinage
              << " buy_coinage_delta=" << result.buy_coinage_delta
              << " sell_coinage_delta=" << result.sell_coinage_delta
              << " roundtrip_coinage_delta=" << result.roundtrip_coinage_delta
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.roundtrip_confirmed ? 0 : 1;
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
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " target_pos=(" << result.target_x << "," << result.target_y << "," << result.target_z << ")"
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " attack_sent=" << (result.attack_sent ? 1 : 0)
              << " combat_response_seen=" << (result.combat_response_seen ? 1 : 0)
              << " attacker_state_update_seen=" << (result.attacker_state_update_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " hit_info=0x" << std::hex << result.attacker_state_update.hit_info << std::dec
              << " total_damage=" << result.attacker_state_update.total_damage
              << " overkill=" << result.attacker_state_update.overkill
              << " sub_damage_count=" << static_cast<int>(result.attacker_state_update.sub_damage_count)
              << " target_state=" << static_cast<int>(result.attacker_state_update.target_state)
              << " blocked_amount=" << result.attacker_state_update.blocked_amount
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.live_target_found && result.attack_sent && result.attacker_state_update_seen ? 0 : 1;
}

int loot_open_probe(
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
    acore_protocol::LootOpenProbeResult result = acore_protocol::loot_open_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "LOOT_OPEN_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " target_pos=(" << result.target_x << "," << result.target_y << "," << result.target_z << ")"
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " loot_open_sent=" << (result.loot_open_sent ? 1 : 0)
              << " loot_response_seen=" << (result.loot_response_seen ? 1 : 0)
              << " loot_release_sent=" << (result.loot_release_sent ? 1 : 0)
              << " loot_release_response_seen=" << (result.loot_release_response_seen ? 1 : 0)
              << " loot_release_success=" << (result.loot_release_success ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " loot_parsed=" << (result.loot.parsed ? 1 : 0)
              << " loot_error=" << (result.loot.error ? 1 : 0)
              << " loot_error_code=" << static_cast<int>(result.loot.error_code)
              << " loot_type=" << static_cast<int>(result.loot.loot_type)
              << " gold=" << result.loot.gold
              << " item_count=" << static_cast<int>(result.loot.item_count)
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    for (LootItemSummary const& item : result.loot.items)
    {
        std::cout << "LOOT_ITEM"
                  << " slot=" << static_cast<int>(item.slot)
                  << " item_id=" << item.item_id
                  << " count=" << item.count
                  << " display_id=" << item.display_id
                  << " random_suffix=" << item.random_suffix
                  << " random_property_id=" << item.random_property_id
                  << " slot_type=" << static_cast<int>(item.slot_type)
                  << "\n";
    }

    return result.loot_open_sent && (result.loot_response_seen || result.loot_release_response_seen) ? 0 : 1;
}

int corpse_loot_probe(
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
    acore_protocol::CorpseLootProbeResult result = acore_protocol::corpse_loot_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "CORPSE_LOOT_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.target_has_position ? 1 : 0)
              << " target_pos=(" << result.target_x << "," << result.target_y << "," << result.target_z << ")"
              << " target_health_seen=" << (result.target_health_seen ? 1 : 0)
              << " target_health=" << result.target_health
              << " target_max_health_seen=" << (result.target_max_health_seen ? 1 : 0)
              << " target_max_health=" << result.target_max_health
              << " target_dynamic_flags_seen=" << (result.target_dynamic_flags_seen ? 1 : 0)
              << " target_dynamic_flags=0x" << std::hex << result.target_dynamic_flags << std::dec
              << " target_dead_seen=" << (result.target_dead_seen ? 1 : 0)
              << " target_lootable_seen=" << (result.target_lootable_seen ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " approach_movement_sent=" << (result.approach_movement_sent ? 1 : 0)
              << " return_movement_sent=" << (result.return_movement_sent ? 1 : 0)
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " attack_sent=" << (result.attack_sent ? 1 : 0)
              << " attack_stop_sent=" << (result.attack_stop_sent ? 1 : 0)
              << " attacker_state_updates=" << result.attacker_state_update_count
              << " total_damage=" << result.total_damage
              << " loot_open_sent=" << (result.loot_open_sent ? 1 : 0)
              << " loot_response_seen=" << (result.loot_response_seen ? 1 : 0)
              << " loot_money_sent=" << (result.loot_money_sent ? 1 : 0)
              << " loot_money_notify_seen=" << (result.loot_money_notify_seen ? 1 : 0)
              << " loot_money_amount=" << result.loot_money_amount
              << " loot_item_pickup_sent_count=" << result.loot_item_pickup_sent_count
              << " loot_item_removed_count=" << result.loot_item_removed_count
              << " loot_release_sent=" << (result.loot_release_sent ? 1 : 0)
              << " loot_release_response_seen=" << (result.loot_release_response_seen ? 1 : 0)
              << " loot_release_success=" << (result.loot_release_success ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " loot_parsed=" << (result.loot.parsed ? 1 : 0)
              << " loot_error=" << (result.loot.error ? 1 : 0)
              << " loot_error_code=" << static_cast<int>(result.loot.error_code)
              << " loot_type=" << static_cast<int>(result.loot.loot_type)
              << " gold=" << result.loot.gold
              << " item_count=" << static_cast<int>(result.loot.item_count)
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    for (LootItemSummary const& item : result.loot.items)
    {
        std::cout << "CORPSE_LOOT_ITEM"
                  << " slot=" << static_cast<int>(item.slot)
                  << " item_id=" << item.item_id
                  << " count=" << item.count
                  << " display_id=" << item.display_id
                  << " random_suffix=" << item.random_suffix
                  << " random_property_id=" << item.random_property_id
                  << " slot_type=" << static_cast<int>(item.slot_type)
                  << "\n";
    }

    bool const loot_window_ok = result.loot_response_seen && !result.loot.error;
    bool const money_ok = result.loot.gold == 0 || result.loot_money_notify_seen;
    bool const item_ok = result.loot.items.empty() || result.loot_item_removed_count > 0;
    return result.live_target_found && result.attack_sent && result.target_dead_seen
        && loot_window_ok && money_ok && item_ok && result.loot_release_response_seen ? 0 : 1;
}

int chat_say(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& message)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::ChatSayResult result = acore_protocol::chat_say(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        message,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "CHAT_SAY_SENT"
              << " character=\"" << result.character.name << "\""
              << " message_sent=" << (result.message_sent ? 1 : 0)
              << " chat_response_seen=" << (result.chat_response_seen ? 1 : 0)
              << " echoed_message_seen=" << (result.echoed_message_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " chat_type=" << static_cast<int>(result.chat_type)
              << " language=" << result.language
              << " sender_guid=0x" << std::hex << result.sender_guid
              << " receiver_guid=0x" << result.receiver_guid << std::dec
              << " sent_len=" << result.message.size()
              << " received_len=" << result.received_message.size()
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.message_sent && result.echoed_message_seen ? 0 : 1;
}

int chat_whisper_self(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& message)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::ChatSayResult result = acore_protocol::chat_whisper_self(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        message,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "CHAT_WHISPER_SELF_SENT"
              << " character=\"" << result.character.name << "\""
              << " message_sent=" << (result.message_sent ? 1 : 0)
              << " chat_response_seen=" << (result.chat_response_seen ? 1 : 0)
              << " whisper_seen=" << (result.whisper_seen ? 1 : 0)
              << " whisper_inform_seen=" << (result.whisper_inform_seen ? 1 : 0)
              << " echoed_message_seen=" << (result.echoed_message_seen ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response_opcode << std::dec
              << " chat_type=" << static_cast<int>(result.chat_type)
              << " language=" << result.language
              << " sender_guid=0x" << std::hex << result.sender_guid
              << " receiver_guid=0x" << result.receiver_guid << std::dec
              << " sent_len=" << result.message.size()
              << " received_len=" << result.received_message.size()
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.message_sent && result.echoed_message_seen ? 0 : 1;
}

int spellbook(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::SpellbookResult result = acore_protocol::read_initial_spellbook(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "SPELLBOOK_SEEN"
              << " character=\"" << result.character.name << "\""
              << " initial_spells_seen=" << (result.initial_spells_seen ? 1 : 0)
              << " logged_in_world=" << (result.logged_in_world ? 1 : 0)
              << " flags=" << static_cast<int>(result.spellbook.spellbook_flags)
              << " spell_count=" << result.spellbook.spells.size()
              << " cooldown_count=" << result.spellbook.cooldown_count
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";

    for (InitialSpellSummary const& spell : result.spellbook.spells)
    {
        std::cout << "SPELL"
                  << " id=" << spell.spell_id
                  << " slot=" << spell.slot
                  << "\n";
    }
    return result.initial_spells_seen && !result.spellbook.spells.empty() ? 0 : 1;
}

int action_buttons(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::ActionButtonsResult result = acore_protocol::read_action_buttons(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "ACTION_BUTTONS_SEEN"
              << " character=\"" << result.character.name << "\""
              << " action_buttons_seen=" << (result.action_buttons_seen ? 1 : 0)
              << " logged_in_world=" << (result.logged_in_world ? 1 : 0)
              << " state=" << static_cast<int>(result.action_buttons.state)
              << " slot_count=" << result.action_buttons.buttons.size()
              << " populated_count=" << result.action_buttons.populated_count
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";

    std::size_t printed = 0;
    for (ActionButtonSummary const& button : result.action_buttons.buttons)
    {
        if (!button.populated)
        {
            continue;
        }
        if (printed >= 36)
        {
            break;
        }
        std::cout << "ACTION_BUTTON"
                  << " button=" << static_cast<int>(button.button)
                  << " action=" << button.action
                  << " type=" << static_cast<int>(button.type)
                  << " packed=0x" << std::hex << button.packed << std::dec
                  << "\n";
        ++printed;
    }
    return result.action_buttons_seen && result.action_buttons.buttons.size() == MaxActionButtons ? 0 : 1;
}

char const* inventory_section_name(std::uint8_t section)
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

int inventory_snapshot(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name)
{
    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::InventorySnapshotResult result = acore_protocol::read_inventory_snapshot(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "INVENTORY_SNAPSHOT"
              << " character=\"" << result.character.name << "\""
              << " inventory_seen=" << (result.inventory_seen ? 1 : 0)
              << " logged_in_world=" << (result.logged_in_world ? 1 : 0)
              << " player_guid=0x" << std::hex << result.inventory.player_guid << std::dec
              << " coinage_seen=" << (result.inventory.coinage_seen ? 1 : 0)
              << " coinage=" << result.inventory.coinage
              << " slot_count=" << result.inventory.slots.size()
              << " populated_count=" << result.inventory.populated_count
              << " item_detail_count=" << result.inventory.item_detail_count
              << " item_template_count=" << result.inventory.item_template_count
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";

    for (InventorySlotSummary const& slot : result.inventory.slots)
    {
        std::cout << "INVENTORY_SLOT"
                  << " slot=" << static_cast<int>(slot.slot)
                  << " section=" << inventory_section_name(slot.section)
                  << " field_seen=" << (slot.field_seen ? 1 : 0)
                  << " populated=" << (slot.populated ? 1 : 0)
                  << " item_guid=0x" << std::hex << slot.item_guid << std::dec
                  << " item_entry=" << slot.item_entry
                  << " stack_count=" << slot.stack_count
                  << " durability=" << slot.durability
                  << " max_durability=" << slot.max_durability
                  << " item_detail_seen=" << (slot.item_detail_seen ? 1 : 0)
                  << " item_template_seen=" << (slot.item_template_seen ? 1 : 0)
                  << " item_name=\"" << slot.item_name << "\""
                  << "\n";
    }
    return result.inventory_seen && result.inventory.slots.size() == PlayerInventorySnapshotSlots ? 0 : 1;
}

std::uint8_t parse_inventory_slot_arg(std::string const& value, char const* name)
{
    std::size_t parsed = 0;
    unsigned long slot = std::stoul(value, &parsed, 10);
    if (parsed != value.size() || slot >= PlayerInventorySnapshotSlots)
    {
        throw std::runtime_error(std::string(name) + " must be an integer from 0 to 38");
    }
    return static_cast<std::uint8_t>(slot);
}

void print_swap_slot(std::string const& prefix, InventorySlotSummary const& slot)
{
    std::cout << " " << prefix << "_populated=" << (slot.populated ? 1 : 0)
              << " " << prefix << "_guid=0x" << std::hex << slot.item_guid << std::dec
              << " " << prefix << "_entry=" << slot.item_entry
              << " " << prefix << "_stack=" << slot.stack_count
              << " " << prefix << "_name=\"" << slot.item_name << "\"";
}

int loot_inventory_handoff_probe(
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
    acore_protocol::LootInventoryHandoffResult result = acore_protocol::loot_inventory_handoff_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "LOOT_INVENTORY_PROBE"
              << " character=\"" << result.character.name << "\""
              << " target_guid=0x" << std::hex << result.corpse_loot.target_guid << std::dec
              << " target_entry=" << result.corpse_loot.target_entry
              << " target_name=\"" << result.corpse_loot.target_name << "\""
              << " live_target_found=" << (result.corpse_loot.live_target_found ? 1 : 0)
              << " target_has_position=" << (result.corpse_loot.target_has_position ? 1 : 0)
              << " target_health_seen=" << (result.corpse_loot.target_health_seen ? 1 : 0)
              << " target_health=" << result.corpse_loot.target_health
              << " target_max_health_seen=" << (result.corpse_loot.target_max_health_seen ? 1 : 0)
              << " target_max_health=" << result.corpse_loot.target_max_health
              << " target_dynamic_flags_seen=" << (result.corpse_loot.target_dynamic_flags_seen ? 1 : 0)
              << " target_dynamic_flags=0x" << std::hex << result.corpse_loot.target_dynamic_flags << std::dec
              << " target_dead_seen=" << (result.corpse_loot.target_dead_seen ? 1 : 0)
              << " target_lootable_seen=" << (result.corpse_loot.target_lootable_seen ? 1 : 0)
              << " selection_sent=" << (result.corpse_loot.selection_sent ? 1 : 0)
              << " attack_sent=" << (result.corpse_loot.attack_sent ? 1 : 0)
              << " attack_stop_sent=" << (result.corpse_loot.attack_stop_sent ? 1 : 0)
              << " attacker_state_updates=" << result.corpse_loot.attacker_state_update_count
              << " total_damage=" << result.corpse_loot.total_damage
              << " loot_open_sent=" << (result.corpse_loot.loot_open_sent ? 1 : 0)
              << " loot_response_seen=" << (result.corpse_loot.loot_response_seen ? 1 : 0)
              << " loot_error=" << (result.corpse_loot.loot.error ? 1 : 0)
              << " loot_item_pickup_sent_count=" << result.corpse_loot.loot_item_pickup_sent_count
              << " loot_item_removed_count=" << result.corpse_loot.loot_item_removed_count
              << " loot_release_sent=" << (result.corpse_loot.loot_release_sent ? 1 : 0)
              << " loot_release_response_seen=" << (result.corpse_loot.loot_release_response_seen ? 1 : 0)
              << " loot_release_success=" << (result.corpse_loot.loot_release_success ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.corpse_loot.response_opcode << std::dec
              << " item_count=" << static_cast<int>(result.corpse_loot.loot.item_count)
              << " gold=" << result.corpse_loot.loot.gold
              << " inventory_before_seen=" << (result.inventory_before_seen ? 1 : 0)
              << " inventory_after_seen=" << (result.inventory_after_seen ? 1 : 0)
              << " before_populated=" << result.inventory_before.populated_count
              << " after_populated=" << result.inventory_after.populated_count
              << " before_coinage=" << result.inventory_before.coinage
              << " after_coinage=" << result.inventory_after.coinage
              << " coinage_delta=" << result.coinage_delta
              << " changed_slots=" << result.changed_slot_count
              << " added_slots=" << result.added_slot_count
              << " removed_slots=" << result.removed_slot_count
              << " stack_changed_slots=" << result.stack_changed_slot_count
              << " handoff_confirmed=" << (result.handoff_confirmed ? 1 : 0)
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";

    for (InventorySlotSummary const& slot : result.changed_slots)
    {
        std::cout << "LOOT_INVENTORY_CHANGED_SLOT"
                  << " slot=" << static_cast<int>(slot.slot)
                  << " section=" << inventory_section_name(slot.section)
                  << " populated=" << (slot.populated ? 1 : 0)
                  << " item_guid=0x" << std::hex << slot.item_guid << std::dec
                  << " item_entry=" << slot.item_entry
                  << " stack_count=" << slot.stack_count
                  << " item_detail_seen=" << (slot.item_detail_seen ? 1 : 0)
                  << " item_template_seen=" << (slot.item_template_seen ? 1 : 0)
                  << " item_name=\"" << slot.item_name << "\""
                  << "\n";
    }

    return result.handoff_confirmed ? 0 : 1;
}

std::uint32_t parse_split_count_arg(std::string const& value)
{
    std::size_t parsed = 0;
    unsigned long count = std::stoul(value, &parsed, 10);
    if (parsed != value.size() || count == 0 || count > 999)
    {
        throw std::runtime_error("split count must be an integer from 1 to 999");
    }
    return static_cast<std::uint32_t>(count);
}

int swap_inventory_slots(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& source_slot_text,
    std::string const& destination_slot_text)
{
    std::uint8_t const source_slot = parse_inventory_slot_arg(source_slot_text, "source slot");
    std::uint8_t const destination_slot = parse_inventory_slot_arg(destination_slot_text, "destination slot");

    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::InventorySwapProbeResult result = acore_protocol::swap_inventory_slots_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        source_slot,
        destination_slot,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "INVENTORY_SWAP_PROBE"
              << " character=\"" << result.character.name << "\""
              << " source_slot=" << static_cast<int>(result.source_slot)
              << " destination_slot=" << static_cast<int>(result.destination_slot)
              << " before_seen=" << (result.before_seen ? 1 : 0)
              << " swap_sent=" << (result.swap_sent ? 1 : 0)
              << " swap_confirmed=" << (result.swap_confirmed ? 1 : 0)
              << " restore_sent=" << (result.restore_sent ? 1 : 0)
              << " restore_confirmed=" << (result.restore_confirmed ? 1 : 0)
              << " skipped=" << result.skipped_opcodes.size();
    print_swap_slot("source_before", result.source_before);
    print_swap_slot("destination_before", result.destination_before);
    print_swap_slot("source_after_swap", result.source_after_swap);
    print_swap_slot("destination_after_swap", result.destination_after_swap);
    print_swap_slot("source_after_restore", result.source_after_restore);
    print_swap_slot("destination_after_restore", result.destination_after_restore);
    std::cout << "\n";

    return result.swap_sent && result.swap_confirmed && result.restore_sent && result.restore_confirmed ? 0 : 1;
}

int split_inventory_stack(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& source_slot_text,
    std::string const& destination_slot_text,
    std::string const& split_count_text)
{
    std::uint8_t const source_slot = parse_inventory_slot_arg(source_slot_text, "source slot");
    std::uint8_t const destination_slot = parse_inventory_slot_arg(destination_slot_text, "destination slot");
    std::uint32_t const split_count = parse_split_count_arg(split_count_text);

    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::InventorySplitProbeResult result = acore_protocol::split_inventory_stack_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        source_slot,
        destination_slot,
        split_count,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "INVENTORY_SPLIT_PROBE"
              << " character=\"" << result.character.name << "\""
              << " source_slot=" << static_cast<int>(result.source_slot)
              << " destination_slot=" << static_cast<int>(result.destination_slot)
              << " split_count=" << result.split_count
              << " before_seen=" << (result.before_seen ? 1 : 0)
              << " split_sent=" << (result.split_sent ? 1 : 0)
              << " split_confirmed=" << (result.split_confirmed ? 1 : 0)
              << " merge_sent=" << (result.merge_sent ? 1 : 0)
              << " merge_confirmed=" << (result.merge_confirmed ? 1 : 0)
              << " skipped=" << result.skipped_opcodes.size();
    print_swap_slot("source_before", result.source_before);
    print_swap_slot("destination_before", result.destination_before);
    print_swap_slot("source_after_split", result.source_after_split);
    print_swap_slot("destination_after_split", result.destination_after_split);
    print_swap_slot("source_after_merge", result.source_after_merge);
    print_swap_slot("destination_after_merge", result.destination_after_merge);
    std::cout << "\n";

    return result.split_sent && result.split_confirmed && result.merge_sent && result.merge_confirmed ? 0 : 1;
}

int set_action_button(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& button_text,
    std::string const& action_text,
    std::string const& type_text)
{
    std::size_t parsed = 0;
    unsigned long button_value = std::stoul(button_text, &parsed, 10);
    if (parsed != button_text.size() || button_value >= MaxActionButtons)
    {
        throw std::runtime_error("button must be an integer from 0 to 143");
    }
    parsed = 0;
    unsigned long action_value = std::stoul(action_text, &parsed, 10);
    if (parsed != action_text.size() || action_value >= 0x01000000ul)
    {
        throw std::runtime_error("action must be an integer below 16777216");
    }
    parsed = 0;
    unsigned long type_value = std::stoul(type_text, &parsed, 10);
    if (parsed != type_text.size() || type_value > 255)
    {
        throw std::runtime_error("type must be an integer from 0 to 255");
    }

    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::SetActionButtonProbeResult result = acore_protocol::set_action_button_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        static_cast<std::uint8_t>(button_value),
        static_cast<std::uint32_t>(action_value),
        static_cast<std::uint8_t>(type_value),
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "SET_ACTION_BUTTON_PROBE"
              << " character=\"" << result.character.name << "\""
              << " button=" << static_cast<int>(result.button)
              << " action=" << result.action
              << " type=" << static_cast<int>(result.type)
              << " before_seen=" << (result.before_seen ? 1 : 0)
              << " original_populated=" << (result.original.populated ? 1 : 0)
              << " original_action=" << result.original.action
              << " original_type=" << static_cast<int>(result.original.type)
              << " original_packed=0x" << std::hex << result.original.packed << std::dec
              << " set_sent=" << (result.set_sent ? 1 : 0)
              << " set_confirmed=" << (result.set_confirmed ? 1 : 0)
              << " after_set_populated=" << (result.after_set.populated ? 1 : 0)
              << " after_set_action=" << result.after_set.action
              << " after_set_type=" << static_cast<int>(result.after_set.type)
              << " after_set_packed=0x" << std::hex << result.after_set.packed << std::dec
              << " restore_sent=" << (result.restore_sent ? 1 : 0)
              << " restore_confirmed=" << (result.restore_confirmed ? 1 : 0)
              << " after_restore_populated=" << (result.after_restore.populated ? 1 : 0)
              << " after_restore_action=" << result.after_restore.action
              << " after_restore_type=" << static_cast<int>(result.after_restore.type)
              << " after_restore_packed=0x" << std::hex << result.after_restore.packed << std::dec
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.set_sent && result.set_confirmed && result.restore_sent && result.restore_confirmed ? 0 : 1;
}

int cast_spell(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& spell_id_text)
{
    std::size_t parsed = 0;
    std::uint32_t const spell_id = static_cast<std::uint32_t>(std::stoul(spell_id_text, &parsed, 10));
    if (parsed != spell_id_text.size())
    {
        throw std::runtime_error("spell id contains trailing characters");
    }

    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::SpellCastProbeResult result = acore_protocol::cast_spell_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        spell_id,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "SPELL_CAST_PROBE"
              << " character=\"" << result.character.name << "\""
              << " spell_id=" << result.spell_id
              << " cast_sent=" << (result.cast_sent ? 1 : 0)
              << " logged_in_world=" << (result.logged_in_world ? 1 : 0)
              << " response_seen=" << (result.response_seen ? 1 : 0)
              << " accepted=" << (result.accepted ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response.opcode << std::dec
              << " response_spell_id=" << result.response.spell_id
              << " cast_count=" << static_cast<int>(result.response.cast_count)
              << " cast_flags=0x" << std::hex << result.response.cast_flags << std::dec
              << " fail_reason=" << static_cast<int>(result.response.fail_reason)
              << " spell_start=" << (result.response.spell_start ? 1 : 0)
              << " spell_go=" << (result.response.spell_go ? 1 : 0)
              << " cast_failed=" << (result.response.cast_failed ? 1 : 0)
              << " spell_failure=" << (result.response.spell_failure ? 1 : 0)
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.cast_sent && result.accepted ? 0 : 1;
}

int cast_spell_target(
    std::string const& host,
    std::string const& port,
    std::string const& account,
    std::string const& character_name,
    std::string const& spell_id_text,
    std::string const& target_guid,
    std::string const& target_name)
{
    std::size_t parsed = 0;
    std::uint32_t const spell_id = static_cast<std::uint32_t>(std::stoul(spell_id_text, &parsed, 10));
    if (parsed != spell_id_text.size())
    {
        throw std::runtime_error("spell id contains trailing characters");
    }

    acore_protocol::FlowOptions options{
        .trace_world_packets = std::getenv("ACORE_PROTOCOL_TRACE") != nullptr,
    };
    acore_protocol::TargetedSpellCastProbeResult result = acore_protocol::cast_spell_at_target_probe(
        host,
        port,
        account,
        protocol_password(),
        character_name,
        spell_id,
        parse_guid_arg(target_guid),
        target_name,
        options);

    std::cout << acore_protocol::format_auth_flow_ok(result.realm) << "\n";
    std::cout << "TARGETED_SPELL_CAST_PROBE"
              << " character=\"" << result.character.name << "\""
              << " spell_id=" << result.spell_id
              << " target_guid=0x" << std::hex << result.target_guid << std::dec
              << " target_entry=" << result.target_entry
              << " target_name=\"" << result.target_name << "\""
              << " live_target_found=" << (result.live_target_found ? 1 : 0)
              << " visible_objects=" << result.visible_objects.size()
              << " selection_sent=" << (result.selection_sent ? 1 : 0)
              << " attack_sent=" << (result.attack_sent ? 1 : 0)
              << " cast_sent=" << (result.cast_sent ? 1 : 0)
              << " logged_in_world=" << (result.logged_in_world ? 1 : 0)
              << " response_seen=" << (result.response_seen ? 1 : 0)
              << " accepted=" << (result.accepted ? 1 : 0)
              << " response_opcode=0x" << std::hex << result.response.opcode << std::dec
              << " response_spell_id=" << result.response.spell_id
              << " cast_count=" << static_cast<int>(result.response.cast_count)
              << " cast_flags=0x" << std::hex << result.response.cast_flags << std::dec
              << " fail_reason=" << static_cast<int>(result.response.fail_reason)
              << " spell_start=" << (result.response.spell_start ? 1 : 0)
              << " spell_go=" << (result.response.spell_go ? 1 : 0)
              << " cast_failed=" << (result.response.cast_failed ? 1 : 0)
              << " spell_failure=" << (result.response.spell_failure ? 1 : 0)
              << " skipped=" << result.skipped_opcodes.size()
              << "\n";
    return result.cast_sent && result.accepted ? 0 : 1;
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
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --trainer-list <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --trainer-buy <host> <port> <account> <character-name> <target-guid-or-entry> <target-name> <spell-id>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --combat-probe <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --loot-open-probe <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --corpse-loot-probe <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --loot-inventory-handoff <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --chat-say <host> <port> <account> <character-name> <message>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --chat-whisper-self <host> <port> <account> <character-name> <message>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --spellbook <host> <port> <account> <character-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --action-buttons <host> <port> <account> <character-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --inventory-snapshot <host> <port> <account> <character-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --swap-inventory-slots <host> <port> <account> <character-name> <source-slot> <destination-slot>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --split-inventory-stack <host> <port> <account> <character-name> <source-slot> <destination-slot> <count>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --set-action-button <host> <port> <account> <character-name> <button> <action> <type>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --cast-spell <host> <port> <account> <character-name> <spell-id>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --cast-spell-target <host> <port> <account> <character-name> <spell-id> <target-guid-or-entry> <target-name>\n"
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

        if (argc == 8 && std::strcmp(argv[1], "--trainer-list") == 0)
        {
            return trainer_list_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--questgiver-list") == 0)
        {
            return questgiver_list_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 9 && std::strcmp(argv[1], "--questgiver-details") == 0)
        {
            return questgiver_details_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        }

        if (argc == 9 && std::strcmp(argv[1], "--questgiver-accept") == 0)
        {
            return questgiver_accept_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        }

        if (argc == 9 && std::strcmp(argv[1], "--questgiver-reward") == 0)
        {
            return questgiver_reward_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        }

        if ((argc == 9 || argc == 10) && std::strcmp(argv[1], "--questgiver-turnin") == 0)
        {
            std::string reward_index = argc == 10 ? argv[9] : "0";
            return questgiver_turnin_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8], reward_index);
        }

        if (argc == 9 && std::strcmp(argv[1], "--trainer-buy") == 0)
        {
            return trainer_buy_spell_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--vendor-list") == 0)
        {
            return vendor_list_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 11 && std::strcmp(argv[1], "--vendor-buy-sell") == 0)
        {
            return vendor_buy_sell_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8], argv[9], argv[10]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--combat-probe") == 0)
        {
            return combat_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--loot-open-probe") == 0)
        {
            return loot_open_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--corpse-loot-probe") == 0)
        {
            return corpse_loot_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--loot-inventory-handoff") == 0)
        {
            return loot_inventory_handoff_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 7 && std::strcmp(argv[1], "--chat-say") == 0)
        {
            return chat_say(argv[2], argv[3], argv[4], argv[5], argv[6]);
        }

        if (argc == 7 && std::strcmp(argv[1], "--chat-whisper-self") == 0)
        {
            return chat_whisper_self(argv[2], argv[3], argv[4], argv[5], argv[6]);
        }

        if (argc == 6 && std::strcmp(argv[1], "--spellbook") == 0)
        {
            return spellbook(argv[2], argv[3], argv[4], argv[5]);
        }

        if (argc == 6 && std::strcmp(argv[1], "--action-buttons") == 0)
        {
            return action_buttons(argv[2], argv[3], argv[4], argv[5]);
        }

        if (argc == 6 && std::strcmp(argv[1], "--inventory-snapshot") == 0)
        {
            return inventory_snapshot(argv[2], argv[3], argv[4], argv[5]);
        }

        if (argc == 8 && std::strcmp(argv[1], "--swap-inventory-slots") == 0)
        {
            return swap_inventory_slots(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
        }

        if (argc == 9 && std::strcmp(argv[1], "--split-inventory-stack") == 0)
        {
            return split_inventory_stack(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        }

        if (argc == 9 && std::strcmp(argv[1], "--set-action-button") == 0)
        {
            return set_action_button(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
        }

        if (argc == 7 && std::strcmp(argv[1], "--cast-spell") == 0)
        {
            return cast_spell(argv[2], argv[3], argv[4], argv[5], argv[6]);
        }

        if (argc == 9 && std::strcmp(argv[1], "--cast-spell-target") == 0)
        {
            return cast_spell_target(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8]);
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
