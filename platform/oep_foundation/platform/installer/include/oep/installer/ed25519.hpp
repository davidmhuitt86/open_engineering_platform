#pragma once

#include <array>
#include <cstdint>
#include <vector>

namespace oep::installer {

// Ed25519 signature VERIFICATION (RFC 8032), hand-rolled per this
// codebase's no-third-party-dependency convention — the required
// algorithm for .oep package trust, per PKG-005 §8.
//
// Deliberately verify-only: Foundation never signs anything and never
// holds a private key. Signing lives on the publisher side
// (`@oep-exchange/signing`, which uses Node's built-in crypto — Ed25519
// keys/signatures are interoperable by construction, and both sides are
// cross-checked against RFC 8032's published test vectors in
// tests/installer/ed25519_tests.cpp).
//
// Implementation notes (readability over speed, per the Coding
// Philosophy): field arithmetic is plain 8×32-bit-limb schoolbook math
// modulo 2^255-19, point arithmetic uses extended twisted-Edwards
// coordinates with one unified addition formula, and scalar
// multiplication is simple double-and-add. Verification handles only
// PUBLIC data (message, public key, signature), so constant-time
// execution is not a requirement here — that matters for signing/secret
// keys, which this module never touches.
//
// Returns true iff `signature` is a valid Ed25519 signature over
// `message` by `public_key`. Rejects malformed points, a signature
// scalar S >= the group order L, and — trivially — any bit flip in
// message, key, or signature.
bool ed25519_verify(const std::vector<std::uint8_t>& message, const std::array<std::uint8_t, 32>& public_key,
                     const std::array<std::uint8_t, 64>& signature);

} // namespace oep::installer
