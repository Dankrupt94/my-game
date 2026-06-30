#include "protocol_bytes.h"

#include <iomanip>
#include <sstream>
#include <stdexcept>

std::vector<std::uint8_t> build_client_header(std::uint32_t opcode, std::size_t payload_size)
{
    std::uint32_t const size = static_cast<std::uint32_t>(payload_size + 4);
    if (size > 0xFFFF)
    {
        throw std::runtime_error("client packet too large for 2-byte header");
    }

    return {
        static_cast<std::uint8_t>((size >> 8) & 0xFF),
        static_cast<std::uint8_t>(size & 0xFF),
        static_cast<std::uint8_t>(opcode & 0xFF),
        static_cast<std::uint8_t>((opcode >> 8) & 0xFF),
        static_cast<std::uint8_t>((opcode >> 16) & 0xFF),
        static_cast<std::uint8_t>((opcode >> 24) & 0xFF),
    };
}

std::vector<std::uint8_t> build_server_header_for_test(std::uint16_t opcode, std::size_t payload_size)
{
    if (payload_size > 0x7FFFFF - 2)
    {
        throw std::runtime_error("server packet too large for 3-byte header");
    }

    std::uint32_t const size = static_cast<std::uint32_t>(payload_size + 2);
    if (size > 0x7FFF)
    {
        return {
            static_cast<std::uint8_t>(0x80 | ((size >> 16) & 0xFF)),
            static_cast<std::uint8_t>((size >> 8) & 0xFF),
            static_cast<std::uint8_t>(size & 0xFF),
            static_cast<std::uint8_t>(opcode & 0xFF),
            static_cast<std::uint8_t>((opcode >> 8) & 0xFF),
        };
    }

    return {
        static_cast<std::uint8_t>((size >> 8) & 0xFF),
        static_cast<std::uint8_t>(size & 0xFF),
        static_cast<std::uint8_t>(opcode & 0xFF),
        static_cast<std::uint8_t>((opcode >> 8) & 0xFF),
    };
}

ServerHeader parse_server_header(std::span<const std::uint8_t> header)
{
    if (header.size() != 4 && header.size() != 5)
    {
        throw std::runtime_error("server header must be 4 or 5 bytes");
    }

    ServerHeader parsed;
    bool const large = (header[0] & 0x80) != 0;
    if (large)
    {
        if (header.size() != 5)
        {
            throw std::runtime_error("large server header requires 5 bytes");
        }

        parsed.size = (static_cast<std::uint32_t>(header[0] & 0x7F) << 16)
            | (static_cast<std::uint32_t>(header[1]) << 8)
            | static_cast<std::uint32_t>(header[2]);
        parsed.opcode = static_cast<std::uint16_t>(header[3])
            | static_cast<std::uint16_t>(header[4] << 8);
        parsed.header_length = 5;
        return parsed;
    }

    if (header.size() != 4)
    {
        throw std::runtime_error("normal server header requires 4 bytes");
    }

    parsed.size = (static_cast<std::uint32_t>(header[0]) << 8)
        | static_cast<std::uint32_t>(header[1]);
    parsed.opcode = static_cast<std::uint16_t>(header[2])
        | static_cast<std::uint16_t>(header[3] << 8);
    parsed.header_length = 4;
    return parsed;
}

std::string hex(std::span<const std::uint8_t> bytes)
{
    std::ostringstream out;
    out << std::hex << std::setfill('0');
    for (std::uint8_t byte : bytes)
    {
        out << std::setw(2) << static_cast<int>(byte);
    }
    return out.str();
}
