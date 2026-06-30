#include "arc4.h"

#include <algorithm>
#include <stdexcept>

void Arc4::init(std::span<const std::uint8_t> key)
{
    if (key.empty())
    {
        throw std::runtime_error("ARC4 key must not be empty");
    }

    for (std::size_t index = 0; index < s_.size(); ++index)
    {
        s_[index] = static_cast<std::uint8_t>(index);
    }

    std::uint8_t j = 0;
    for (std::size_t index = 0; index < s_.size(); ++index)
    {
        j = static_cast<std::uint8_t>(j + s_[index] + key[index % key.size()]);
        std::swap(s_[index], s_[j]);
    }

    i_ = 0;
    j_ = 0;
}

void Arc4::apply(std::span<std::uint8_t> data)
{
    for (std::uint8_t& byte : data)
    {
        i_ = static_cast<std::uint8_t>(i_ + 1);
        j_ = static_cast<std::uint8_t>(j_ + s_[i_]);
        std::swap(s_[i_], s_[j_]);
        std::uint8_t const k = s_[static_cast<std::uint8_t>(s_[i_] + s_[j_])];
        byte = static_cast<std::uint8_t>(byte ^ k);
    }
}
