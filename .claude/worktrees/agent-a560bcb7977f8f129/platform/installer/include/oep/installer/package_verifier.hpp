#pragma once

#include <filesystem>
#include <string>

#include "oep/installer/trust_store.hpp"

namespace oep::installer {

// The trust states a package can resolve to (the WP-REP-004 subset of
// PKG-005 §12; the omitted states — Verified, Enterprise Trusted,
// Corrupted, Untrusted — belong to certificate-authority chains,
// enterprise policy services, and repair capabilities deferred beyond
// this Work Package).
enum class TrustState {
    Trusted,             // signed, hashes intact, signature valid, publisher trusted
    Unsigned,            // no signatures/package.sig entry in the archive
    UnknownPublisher,    // signed, but the publisher has no Trust Store certificate
    ExpiredCertificate,  // the publisher's certificate has expired
    RevokedCertificate,  // the publisher's certificate is locally revoked
    InvalidSignature,    // structure/algorithm/key/signature check failed
    Tampered,            // an archive entry's content does not match its signed hash
};

std::string to_string(TrustState state);

struct TrustVerification {
    // Operational success of the verification *process* — false only
    // when the archive itself could not be opened/read. A package that
    // fails trust (Tampered, InvalidSignature, ...) still reports
    // success = true, with the outcome in `state`.
    bool success = false;
    std::string error;

    TrustState state = TrustState::Unsigned;
    std::string publisher_id;  // from the signature block, when present
    std::string fingerprint;   // the trusted certificate's fingerprint, when found
    std::string detail;        // human-readable explanation of the state
};

// Verifies a .oep archive's trust before installation (WP-REP-004,
// PKG-005 §11), fully offline, against the repository's own Trust Store:
//
//   structure -> content hashes -> certificate -> signature -> state
//
// The signature block is `signatures/package.sig` (JSON): the signing
// algorithm ("Ed25519" — anything else is rejected, per PKG-005 §8),
// the publisher id, the raw public key (hex), a content-hash list
// covering EVERY archive entry outside `signatures/` (PKG-005 §9/§10:
// manifest, Repository Fragment, assets, indexes, metadata, licenses —
// nothing in the payload is exempt), and an Ed25519 signature over the
// canonical serialization of that list (sorted by path, one
// `<path>\n<sha256>\n` pair per entry). Produced by
// `@oep-exchange/signing`'s `oep-sign` tool; verified here with the
// hand-rolled RFC 8032 implementation (ed25519.hpp).
TrustVerification verify_package_trust(const std::filesystem::path& archive_path, const TrustStore& trust_store);

} // namespace oep::installer
