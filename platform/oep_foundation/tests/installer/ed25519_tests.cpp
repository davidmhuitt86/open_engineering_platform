#include "oep/installer/ed25519.hpp"

#include <array>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

std::uint8_t nibble(char c) {
    if (c >= '0' && c <= '9') return static_cast<std::uint8_t>(c - '0');
    if (c >= 'a' && c <= 'f') return static_cast<std::uint8_t>(c - 'a' + 10);
    return static_cast<std::uint8_t>(c - 'A' + 10);
}

std::vector<std::uint8_t> hex_to_bytes(const std::string& hex) {
    std::vector<std::uint8_t> bytes;
    for (std::size_t i = 0; i + 1 < hex.size(); i += 2) {
        bytes.push_back(static_cast<std::uint8_t>((nibble(hex[i]) << 4) | nibble(hex[i + 1])));
    }
    return bytes;
}

std::array<std::uint8_t, 32> key_from_hex(const std::string& hex) {
    std::array<std::uint8_t, 32> key{};
    const std::vector<std::uint8_t> bytes = hex_to_bytes(hex);
    for (std::size_t i = 0; i < 32; ++i) key[i] = bytes[i];
    return key;
}

std::array<std::uint8_t, 64> sig_from_hex(const std::string& hex) {
    std::array<std::uint8_t, 64> sig{};
    const std::vector<std::uint8_t> bytes = hex_to_bytes(hex);
    for (std::size_t i = 0; i < 64; ++i) sig[i] = bytes[i];
    return sig;
}

// RFC 8032 §7.1 published test vectors — the authoritative correctness
// reference for this from-scratch implementation.
void test_rfc8032_vector_1_empty_message() {
    const auto pk = key_from_hex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
    const auto sig = sig_from_hex(
        "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
    check(oep::installer::ed25519_verify({}, pk, sig), "RFC 8032 TEST 1 (empty message) verifies");
}

void test_rfc8032_vector_2_one_byte() {
    const auto pk = key_from_hex("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c");
    const auto sig = sig_from_hex(
        "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da"
        "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00");
    check(oep::installer::ed25519_verify({0x72}, pk, sig), "RFC 8032 TEST 2 (one-byte message) verifies");
}

void test_rfc8032_vector_3_two_bytes() {
    const auto pk = key_from_hex("fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025");
    const auto sig = sig_from_hex(
        "6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac"
        "18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a");
    check(oep::installer::ed25519_verify({0xaf, 0x82}, pk, sig), "RFC 8032 TEST 3 (two-byte message) verifies");
}

void test_tampered_message_is_rejected() {
    const auto pk = key_from_hex("fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025");
    const auto sig = sig_from_hex(
        "6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac"
        "18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a");
    check(!oep::installer::ed25519_verify({0xaf, 0x83}, pk, sig), "a single flipped message bit is rejected");
}

void test_tampered_signature_is_rejected() {
    const auto pk = key_from_hex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
    auto sig = sig_from_hex(
        "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
    sig[0] ^= 0x01;
    check(!oep::installer::ed25519_verify({}, pk, sig), "a single flipped signature bit is rejected");
}

void test_wrong_public_key_is_rejected() {
    const auto pk = key_from_hex("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c");
    const auto sig = sig_from_hex(
        "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
    check(!oep::installer::ed25519_verify({}, pk, sig), "a valid signature under a different key is rejected");
}

void test_oversized_scalar_is_rejected() {
    // S >= L must be rejected outright (RFC 8032 malleability check):
    // set S to all-0xFF.
    const auto pk = key_from_hex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
    auto sig = sig_from_hex(
        "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
    for (std::size_t i = 32; i < 64; ++i) sig[i] = 0xFF;
    check(!oep::installer::ed25519_verify({}, pk, sig), "a signature scalar S >= L is rejected");
}

} // namespace

int main() {
    test_rfc8032_vector_1_empty_message();
    test_rfc8032_vector_2_one_byte();
    test_rfc8032_vector_3_two_bytes();
    test_tampered_message_is_rejected();
    test_tampered_signature_is_rejected();
    test_wrong_public_key_is_rejected();
    test_oversized_scalar_is_rejected();

    if (g_failures == 0) {
        std::cout << "All ed25519 tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " ed25519 test(s) failed.\n";
    return 1;
}
