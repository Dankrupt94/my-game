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

    std::size_t printed = 0;
    for (InitialSpellSummary const& spell : result.spellbook.spells)
    {
        if (printed >= 24)
        {
            break;
        }
        std::cout << "SPELL"
                  << " id=" << spell.spell_id
                  << " slot=" << spell.slot
                  << "\n";
        ++printed;
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
                  << "\n";
    }
    return result.inventory_seen && result.inventory.slots.size() == PlayerInventorySnapshotSlots ? 0 : 1;
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
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --combat-probe <host> <port> <account> <character-name> <target-guid-or-entry> <target-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --chat-say <host> <port> <account> <character-name> <message>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --chat-whisper-self <host> <port> <account> <character-name> <message>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --spellbook <host> <port> <account> <character-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --action-buttons <host> <port> <account> <character-name>\n"
              << "  ACORE_PROTOCOL_PASSWORD=... acore_protocol_client --inventory-snapshot <host> <port> <account> <character-name>\n"
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

        if (argc == 8 && std::strcmp(argv[1], "--combat-probe") == 0)
        {
            return combat_probe(argv[2], argv[3], argv[4], argv[5], argv[6], argv[7]);
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
