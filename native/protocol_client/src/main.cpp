#include "auth_crypt.h"
#include "protocol_bytes.h"
#include "protocol_flow.h"
#include "srp6.h"
#include "world_packets.h"

#include <cstdlib>
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

        usage();
        return 2;
    }
    catch (std::exception const& exc)
    {
        std::cerr << "ERROR: " << exc.what() << "\n";
        return 1;
    }
}
