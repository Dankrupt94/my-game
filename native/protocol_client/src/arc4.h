#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

class Arc4
{
public:
    void init(std::span<const std::uint8_t> key);
    void apply(std::span<std::uint8_t> data);

private:
    std::array<std::uint8_t, 256> s_{};
    std::uint8_t i_ = 0;
    std::uint8_t j_ = 0;
};
