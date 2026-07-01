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
}
