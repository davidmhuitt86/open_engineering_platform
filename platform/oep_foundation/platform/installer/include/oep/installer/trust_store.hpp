#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace oep::installer {

// One trusted publisher certificate (PKG-005 §7), as stored in the
// Trust Store. `fingerprint` is the SHA-256 hex digest of the raw
// 32-byte Ed25519 public key — computed by the Trust Store itself on
// add, never taken from input.
struct PublisherCertificate {
    std::string publisher_id;
    std::string publisher_name;
    std::string public_key_hex; // 64 hex chars = raw 32-byte Ed25519 public key
    std::string issued_utc;
    std::string expires_utc; // empty = never expires (documented leniency)
    std::string issuer;
    std::string version;
    std::string fingerprint;
    bool revoked = false;
    std::string revoked_utc;
};

struct TrustStoreResult {
    bool success = false;
    std::string error;
};

struct GetCertificateResult {
    bool success = false;
    std::string error;
    bool found = false;
    PublisherCertificate certificate; // meaningful only when found is true
};

struct ListCertificatesResult {
    bool success = false;
    std::string error;
    std::vector<PublisherCertificate> certificates;
};

struct TrustPolicyResult {
    bool success = false;
    std::string error;
    bool require_signatures = false;
};

// The per-repository Trust Store (WP-REP-004, PKG-005): trusted
// publisher certificates persisted one JSON file per publisher under
// `<repository>/settings/trust/` — inside the `settings/` directory
// OEP-SPEC-002 §5 already reserves — plus a policy file
// (`settings/trust/policy.json`).
//
// Entirely offline (PKG-005 §3: "Verification shall never require
// access to the Engineering Exchange"): certificates are added and
// revoked locally by explicit user action; there is no certificate
// authority chain, online revocation feed, or enterprise policy service
// — those are PKG-005 §13/§14 capabilities deferred beyond WP-REP-004.
// Revocation here marks the local record revoked (the certificate file
// is kept, per PKG-005 §12/§13's retained-status model — this is not
// package uninstall, which remains out of scope).
class TrustStore {
public:
    explicit TrustStore(std::filesystem::path trust_root);

    // Adds (trusts) a publisher certificate. Validates publisher_id and
    // the public key (exactly 64 hex chars), computes the fingerprint,
    // and rejects a publisher that already has a certificate — renewal/
    // replacement is deferred with update functionality.
    TrustStoreResult add_certificate(const PublisherCertificate& certificate) const;

    GetCertificateResult get_certificate(const std::string& publisher_id) const;

    // Sorted by publisher_id (deterministic).
    ListCertificatesResult list_certificates() const;

    // Marks the publisher's certificate revoked (kept on disk with
    // revoked = true, per PKG-005's retained-trust-history model).
    TrustStoreResult revoke_certificate(const std::string& publisher_id) const;

    // Trust policy: when require_signatures is true, unsigned packages
    // are rejected at install; when false (the default), unsigned
    // packages install with their status recorded as "Unsigned" —
    // matching the platform's current unsigned-by-default posture while
    // letting a repository opt into strictness.
    TrustPolicyResult get_policy() const;
    TrustStoreResult set_policy(bool require_signatures) const;

private:
    std::filesystem::path trust_root_;
    std::filesystem::path path_for(const std::string& publisher_id) const;
};

} // namespace oep::installer
