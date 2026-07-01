#pragma once

#include <cstddef>

#if defined(_WIN32)
#define ACORE_PROTOCOL_API __declspec(dllexport)
#else
#define ACORE_PROTOCOL_API __attribute__((visibility("default")))
#endif

extern "C"
{
enum AcoreProtocolBridgeStatus
{
    ACORE_PROTOCOL_BRIDGE_OK = 0,
    ACORE_PROTOCOL_BRIDGE_ERROR = 1,
    ACORE_PROTOCOL_BRIDGE_BUFFER_TOO_SMALL = 2,
    ACORE_PROTOCOL_BRIDGE_INVALID_ARGUMENT = 3,
};

ACORE_PROTOCOL_API int acore_protocol_bridge_self_test_json(char* output, std::size_t output_size);

ACORE_PROTOCOL_API int acore_protocol_bridge_character_flow_json(
    char const* host,
    char const* port,
    char const* account,
    char const* password,
    char* output,
    std::size_t output_size);
}
