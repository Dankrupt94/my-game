#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string>

namespace srp6
{
constexpr std::size_t SaltLength = 32;
constexpr std::size_t EphemeralKeyLength = 32;
constexpr std::size_t ProofLength = 20;
constexpr std::size_t SessionKeyLength = 40;

using Salt = std::array<std::uint8_t, SaltLength>;
using EphemeralKey = std::array<std::uint8_t, EphemeralKeyLength>;
using Proof = std::array<std::uint8_t, ProofLength>;
using SessionKey = std::array<std::uint8_t, SessionKeyLength>;

struct RegistrationData
{
    Salt salt{};
    EphemeralKey verifier{};
};

struct ClientProof
{
    EphemeralKey A{};
    Proof M{};
    Proof M2{};
    SessionKey K{};
};

RegistrationData make_registration_data(
    std::string username,
    std::string password,
    Salt salt);

ClientProof compute_client_proof(
    std::string username,
    std::string password,
    Salt const& salt,
    EphemeralKey const& B,
    EphemeralKey const& client_private_a);

EphemeralKey compute_server_B(EphemeralKey const& verifier, EphemeralKey const& server_private_b);
Proof compute_server_M2(
    std::string username,
    Salt const& salt,
    EphemeralKey const& verifier,
    EphemeralKey const& server_private_b,
    EphemeralKey const& A,
    Proof const& client_M,
    SessionKey* out_key);

bool self_test();
}
