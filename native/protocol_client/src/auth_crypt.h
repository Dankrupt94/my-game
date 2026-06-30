#pragma once

#include "arc4.h"

#include <array>
#include <cstdint>
#include <span>
#include <vector>

class AuthCrypt
{
public:
    static constexpr std::size_t SessionKeyLength = 40;

    void init(std::span<const std::uint8_t, SessionKeyLength> session_key);
    void encrypt_client_header(std::span<std::uint8_t> header);
    void decrypt_server_header(std::span<std::uint8_t> header);
    [[nodiscard]] bool initialized() const { return initialized_; }

private:
    Arc4 client_encrypt_;
    Arc4 server_decrypt_;
    bool initialized_ = false;
};

std::array<std::uint8_t, 20> hmac_sha1(
    std::span<const std::uint8_t> key,
    std::span<const std::uint8_t> data);
