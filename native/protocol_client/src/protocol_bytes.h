#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

struct ServerHeader
{
    std::uint32_t size = 0;
    std::uint16_t opcode = 0;
    std::size_t header_length = 0;
};

std::vector<std::uint8_t> build_client_header(std::uint32_t opcode, std::size_t payload_size);
std::vector<std::uint8_t> build_server_header_for_test(std::uint16_t opcode, std::size_t payload_size);
ServerHeader parse_server_header(std::span<const std::uint8_t> header);
std::string hex(std::span<const std::uint8_t> bytes);
