#pragma once

#include <array>
#include <cstdint>
#include <vector>

namespace oep::installer {

// A hand-rolled SHA-512 (FIPS 180-4), consistent with this codebase's
// no-third-party-dependency convention and structured exactly like the
// existing sha256.cpp. Exists because Ed25519 (RFC 8032, WP-REP-004's
// Trust & Signing subsystem) is defined over SHA-512 — it is not used
// for package hashing (that remains SHA-256, see sha256.hpp).
//
// Verified against FIPS/NIST test vectors in tests/installer/
// sha512_tests.cpp.
std::array<std::uint8_t, 64> sha512(const std::vector<std::uint8_t>& data);

} // namespace oep::installer
