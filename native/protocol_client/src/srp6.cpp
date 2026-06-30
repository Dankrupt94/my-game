#include "srp6.h"

#include <openssl/bn.h>
#include <openssl/evp.h>

#include <algorithm>
#include <cctype>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string_view>
#include <vector>

namespace srp6
{
namespace
{
using BnPtr = std::unique_ptr<BIGNUM, decltype(&BN_free)>;
using CtxPtr = std::unique_ptr<BN_CTX, decltype(&BN_CTX_free)>;
using MdPtr = std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)>;

BnPtr make_bn()
{
    return BnPtr(BN_new(), BN_free);
}

CtxPtr make_ctx()
{
    return CtxPtr(BN_CTX_new(), BN_CTX_free);
}

BnPtr bn_from_le(std::span<const std::uint8_t> bytes)
{
    return BnPtr(BN_lebin2bn(bytes.data(), static_cast<int>(bytes.size()), nullptr), BN_free);
}

BnPtr bn_from_hex(char const* hex)
{
    BIGNUM* raw = nullptr;
    if (BN_hex2bn(&raw, hex) == 0)
    {
        throw std::runtime_error("BN_hex2bn failed");
    }
    return BnPtr(raw, BN_free);
}

template <std::size_t Size>
std::array<std::uint8_t, Size> bn_to_le(BIGNUM const* bn)
{
    std::array<std::uint8_t, Size> bytes{};
    if (BN_bn2lebinpad(bn, bytes.data(), Size) != static_cast<int>(Size))
    {
        throw std::runtime_error("BN_bn2lebinpad failed");
    }
    return bytes;
}

std::string upper_latin(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::toupper(ch));
    });
    return value;
}

Proof sha1(std::initializer_list<std::span<const std::uint8_t>> parts)
{
    MdPtr ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!ctx || EVP_DigestInit_ex(ctx.get(), EVP_sha1(), nullptr) != 1)
    {
        throw std::runtime_error("SHA1 init failed");
    }

    for (auto part : parts)
    {
        if (EVP_DigestUpdate(ctx.get(), part.data(), part.size()) != 1)
        {
            throw std::runtime_error("SHA1 update failed");
        }
    }

    Proof digest{};
    unsigned int len = 0;
    if (EVP_DigestFinal_ex(ctx.get(), digest.data(), &len) != 1 || len != digest.size())
    {
        throw std::runtime_error("SHA1 final failed");
    }

    return digest;
}

Proof sha1_text(std::string_view one, std::string_view two, std::string_view three)
{
    return sha1({
        std::span<const std::uint8_t>(reinterpret_cast<std::uint8_t const*>(one.data()), one.size()),
        std::span<const std::uint8_t>(reinterpret_cast<std::uint8_t const*>(two.data()), two.size()),
        std::span<const std::uint8_t>(reinterpret_cast<std::uint8_t const*>(three.data()), three.size()),
    });
}

BnPtr modulus()
{
    return bn_from_hex("894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7");
}

BnPtr generator()
{
    auto g = make_bn();
    BN_set_word(g.get(), 7);
    return g;
}

BnPtr multiplier()
{
    auto k = make_bn();
    BN_set_word(k.get(), 3);
    return k;
}

BnPtr mod_exp(BIGNUM const* base, BIGNUM const* exponent, BIGNUM const* mod)
{
    auto result = make_bn();
    auto ctx = make_ctx();
    if (BN_mod_exp(result.get(), base, exponent, mod, ctx.get()) != 1)
    {
        throw std::runtime_error("BN_mod_exp failed");
    }
    return result;
}

EphemeralKey calculate_x(std::string username, std::string password, Salt const& salt)
{
    username = upper_latin(std::move(username));
    password = upper_latin(std::move(password));
    Proof inner = sha1_text(username, ":", password);
    Proof x = sha1({salt, inner});
    EphemeralKey out{};
    static_assert(out.size() >= x.size());
    std::copy(x.begin(), x.end(), out.begin());
    return out;
}

SessionKey sha1_interleave(EphemeralKey const& S)
{
    std::array<std::uint8_t, EphemeralKeyLength / 2> even{};
    std::array<std::uint8_t, EphemeralKeyLength / 2> odd{};
    for (std::size_t i = 0; i < even.size(); ++i)
    {
        even[i] = S[2 * i];
        odd[i] = S[2 * i + 1];
    }

    std::size_t p = 0;
    while (p < S.size() && S[p] == 0)
    {
        ++p;
    }
    if ((p & 1) != 0)
    {
        ++p;
    }
    p /= 2;

    Proof hash0 = sha1({std::span<const std::uint8_t>(even.data() + p, even.size() - p)});
    Proof hash1 = sha1({std::span<const std::uint8_t>(odd.data() + p, odd.size() - p)});

    SessionKey K{};
    for (std::size_t i = 0; i < hash0.size(); ++i)
    {
        K[2 * i] = hash0[i];
        K[2 * i + 1] = hash1[i];
    }
    return K;
}

Proof calculate_M(std::string username, Salt const& salt, EphemeralKey const& A, EphemeralKey const& B, SessionKey const& K)
{
    username = upper_latin(std::move(username));
    auto N_le = bn_to_le<EphemeralKeyLength>(modulus().get());
    std::array<std::uint8_t, 1> g_bytes{7};
    Proof n_hash = sha1({N_le});
    Proof g_hash = sha1({g_bytes});
    Proof ng_hash{};
    for (std::size_t i = 0; i < ng_hash.size(); ++i)
    {
        ng_hash[i] = static_cast<std::uint8_t>(n_hash[i] ^ g_hash[i]);
    }

    Proof username_hash = sha1({
        std::span<const std::uint8_t>(reinterpret_cast<std::uint8_t const*>(username.data()), username.size()),
    });
    return sha1({ng_hash, username_hash, salt, A, B, K});
}
}

RegistrationData make_registration_data(std::string username, std::string password, Salt salt)
{
    EphemeralKey x_bytes = calculate_x(std::move(username), std::move(password), salt);
    auto x = bn_from_le(x_bytes);
    auto g = generator();
    auto N = modulus();
    auto v = mod_exp(g.get(), x.get(), N.get());
    return {salt, bn_to_le<EphemeralKeyLength>(v.get())};
}

EphemeralKey compute_server_B(EphemeralKey const& verifier, EphemeralKey const& server_private_b)
{
    auto N = modulus();
    auto g = generator();
    auto b = bn_from_le(server_private_b);
    auto v = bn_from_le(verifier);
    auto gb = mod_exp(g.get(), b.get(), N.get());
    auto result = make_bn();
    auto ctx = make_ctx();
    if (BN_mul_word(v.get(), 3) != 1)
    {
        throw std::runtime_error("BN_mul_word failed");
    }
    if (BN_mod_add(result.get(), gb.get(), v.get(), N.get(), ctx.get()) != 1)
    {
        throw std::runtime_error("BN_mod_add failed");
    }
    return bn_to_le<EphemeralKeyLength>(result.get());
}

ClientProof compute_client_proof(
    std::string username,
    std::string password,
    Salt const& salt,
    EphemeralKey const& B,
    EphemeralKey const& client_private_a)
{
    auto N = modulus();
    auto g = generator();
    auto k = multiplier();
    auto a = bn_from_le(client_private_a);
    auto B_bn = bn_from_le(B);
    auto A_bn = mod_exp(g.get(), a.get(), N.get());
    EphemeralKey A = bn_to_le<EphemeralKeyLength>(A_bn.get());

    EphemeralKey x_bytes = calculate_x(username, password, salt);
    auto x = bn_from_le(x_bytes);
    auto gx = mod_exp(g.get(), x.get(), N.get());

    auto kgx = make_bn();
    auto base = make_bn();
    auto ctx = make_ctx();
    if (BN_mod_mul(kgx.get(), k.get(), gx.get(), N.get(), ctx.get()) != 1)
    {
        throw std::runtime_error("BN_mod_mul failed");
    }
    if (BN_mod_sub(base.get(), B_bn.get(), kgx.get(), N.get(), ctx.get()) != 1)
    {
        throw std::runtime_error("BN_mod_sub failed");
    }

    Proof u_hash = sha1({A, B});
    auto u = bn_from_le(u_hash);
    auto ux = make_bn();
    auto exponent = make_bn();
    if (BN_mul(ux.get(), u.get(), x.get(), ctx.get()) != 1)
    {
        throw std::runtime_error("BN_mul failed");
    }
    if (BN_add(exponent.get(), a.get(), ux.get()) != 1)
    {
        throw std::runtime_error("BN_add failed");
    }

    auto S_bn = mod_exp(base.get(), exponent.get(), N.get());
    EphemeralKey S = bn_to_le<EphemeralKeyLength>(S_bn.get());
    SessionKey K = sha1_interleave(S);
    Proof M = calculate_M(username, salt, A, B, K);
    Proof M2 = sha1({A, M, K});
    return {A, M, M2, K};
}

Proof compute_server_M2(
    std::string username,
    Salt const& salt,
    EphemeralKey const& verifier,
    EphemeralKey const& server_private_b,
    EphemeralKey const& A,
    Proof const& client_M,
    SessionKey* out_key)
{
    auto N = modulus();
    auto A_bn = bn_from_le(A);
    auto v = bn_from_le(verifier);
    auto b = bn_from_le(server_private_b);
    EphemeralKey B = compute_server_B(verifier, server_private_b);

    Proof u_hash = sha1({A, B});
    auto u = bn_from_le(u_hash);
    auto vu = mod_exp(v.get(), u.get(), N.get());
    auto avu = make_bn();
    auto ctx = make_ctx();
    if (BN_mod_mul(avu.get(), A_bn.get(), vu.get(), N.get(), ctx.get()) != 1)
    {
        throw std::runtime_error("BN_mod_mul failed");
    }

    auto S_bn = mod_exp(avu.get(), b.get(), N.get());
    EphemeralKey S = bn_to_le<EphemeralKeyLength>(S_bn.get());
    SessionKey K = sha1_interleave(S);
    Proof expected_M = calculate_M(username, salt, A, B, K);
    if (expected_M != client_M)
    {
        throw std::runtime_error("SRP client proof mismatch");
    }

    if (out_key)
    {
        *out_key = K;
    }
    return sha1({A, client_M, K});
}

bool self_test()
{
    Salt salt{};
    EphemeralKey client_private{};
    EphemeralKey server_private{};
    for (std::size_t i = 0; i < salt.size(); ++i)
    {
        salt[i] = static_cast<std::uint8_t>(0x10 + i);
        client_private[i] = static_cast<std::uint8_t>(0x30 + i);
        server_private[i] = static_cast<std::uint8_t>(0x70 + i);
    }

    RegistrationData reg = make_registration_data("TEST", "PASSWORD", salt);
    EphemeralKey B = compute_server_B(reg.verifier, server_private);
    ClientProof client = compute_client_proof("TEST", "PASSWORD", salt, B, client_private);

    SessionKey server_key{};
    Proof server_M2 = compute_server_M2("TEST", salt, reg.verifier, server_private, client.A, client.M, &server_key);
    return server_M2 == client.M2 && server_key == client.K;
}
}
