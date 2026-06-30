#include "auth_crypt.h"

#include <openssl/hmac.h>
#include <openssl/evp.h>

#include <array>
#include <stdexcept>

std::array<std::uint8_t, 20> hmac_sha1(
    std::span<const std::uint8_t> key,
    std::span<const std::uint8_t> data)
{
    std::array<std::uint8_t, 20> digest{};
    unsigned int digest_len = 0;
    unsigned char* result = HMAC(
        EVP_sha1(),
        key.data(),
        static_cast<int>(key.size()),
        data.data(),
        data.size(),
        digest.data(),
        &digest_len);

    if (!result || digest_len != digest.size())
    {
        throw std::runtime_error("HMAC-SHA1 failed");
    }

    return digest;
}

void AuthCrypt::init(std::span<const std::uint8_t, SessionKeyLength> session_key)
{
    static constexpr std::array<std::uint8_t, 16> server_encryption_key{
        0xCC, 0x98, 0xAE, 0x04, 0xE8, 0x97, 0xEA, 0xCA,
        0x12, 0xDD, 0xC0, 0x93, 0x42, 0x91, 0x53, 0x57,
    };
    static constexpr std::array<std::uint8_t, 16> server_decryption_key{
        0xC2, 0xB3, 0x72, 0x3C, 0xC6, 0xAE, 0xD9, 0xB5,
        0x34, 0x3C, 0x53, 0xEE, 0x2F, 0x43, 0x67, 0xCE,
    };

    // From the client point of view, server_decryption_key encrypts outbound
    // client headers and server_encryption_key decrypts inbound server headers.
    auto client_encrypt_key = hmac_sha1(server_decryption_key, session_key);
    auto server_decrypt_key = hmac_sha1(server_encryption_key, session_key);

    client_encrypt_.init(client_encrypt_key);
    server_decrypt_.init(server_decrypt_key);

    std::array<std::uint8_t, 1024> drop{};
    client_encrypt_.apply(drop);
    drop.fill(0);
    server_decrypt_.apply(drop);

    initialized_ = true;
}

void AuthCrypt::encrypt_client_header(std::span<std::uint8_t> header)
{
    if (!initialized_)
    {
        throw std::runtime_error("AuthCrypt is not initialized");
    }

    client_encrypt_.apply(header);
}

void AuthCrypt::decrypt_server_header(std::span<std::uint8_t> header)
{
    if (!initialized_)
    {
        throw std::runtime_error("AuthCrypt is not initialized");
    }

    server_decrypt_.apply(header);
}
