#include "oep/installer/trust_store.hpp"

#include <filesystem>
#include <iostream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

oep::installer::PublisherCertificate sample_certificate(const std::string& publisher_id) {
    oep::installer::PublisherCertificate certificate;
    certificate.publisher_id = publisher_id;
    certificate.publisher_name = "Sample Publisher";
    certificate.public_key_hex = "99c4ac9e6560c3a1e4bfd6a20e5ab6513aa77eea9233c01fe296e8b17f106cff";
    certificate.issued_utc = "2026-01-01T00:00:00Z";
    certificate.expires_utc = "2030-01-01T00:00:00Z";
    certificate.issuer = "self";
    certificate.version = "1";
    return certificate;
}

void test_add_then_get(const oep::installer::TrustStore& store) {
    const oep::installer::TrustStoreResult added = store.add_certificate(sample_certificate("com.pub.a"));
    check(added.success, "add_certificate succeeds for a valid certificate: " + added.error);

    const oep::installer::GetCertificateResult found = store.get_certificate("com.pub.a");
    check(found.success && found.found, "get_certificate finds the added publisher");
    check(found.certificate.publisher_name == "Sample Publisher", "the certificate round-trips its fields");
    check(found.certificate.fingerprint == "c55f2e3c2a0bab7801235ab525b729adfaba656c080fc8812ccc96e3af55e106",
          "the fingerprint is computed locally as sha256 of the raw public key");
    check(!found.certificate.revoked, "a freshly added certificate is not revoked");
}

void test_add_rejects_invalid_input(const oep::installer::TrustStore& store) {
    oep::installer::PublisherCertificate no_id = sample_certificate("");
    check(!store.add_certificate(no_id).success, "a certificate without a publisherId is rejected");

    oep::installer::PublisherCertificate bad_key = sample_certificate("com.pub.badkey");
    bad_key.public_key_hex = "not-hex";
    check(!store.add_certificate(bad_key).success, "a certificate with a malformed public key is rejected");

    check(store.add_certificate(sample_certificate("com.pub.dup")).success, "first add for a publisher succeeds");
    check(!store.add_certificate(sample_certificate("com.pub.dup")).success,
          "a second certificate for the same publisher is rejected (renewal is out of scope)");
}

void test_get_reports_not_found(const oep::installer::TrustStore& store) {
    const oep::installer::GetCertificateResult found = store.get_certificate("com.pub.never-added");
    check(found.success && !found.found, "an unknown publisher reports not-found, not an error");
}

void test_revoke(const oep::installer::TrustStore& store) {
    store.add_certificate(sample_certificate("com.pub.revoked"));
    const oep::installer::TrustStoreResult revoked = store.revoke_certificate("com.pub.revoked");
    check(revoked.success, "revoke_certificate succeeds for a trusted publisher");

    const oep::installer::GetCertificateResult found = store.get_certificate("com.pub.revoked");
    check(found.success && found.found && found.certificate.revoked,
          "the revoked certificate is kept, marked revoked");
    check(!found.certificate.revoked_utc.empty(), "revocation records when it happened");

    check(!store.revoke_certificate("com.pub.revoked").success, "revoking twice is rejected");
    check(!store.revoke_certificate("com.pub.never-added").success, "revoking an unknown publisher is rejected");
}

void test_list_is_sorted_and_excludes_policy(const oep::installer::TrustStore& store) {
    store.set_policy(true); // writes policy.json into the same directory
    const oep::installer::ListCertificatesResult listed = store.list_certificates();
    check(listed.success, "list_certificates succeeds");
    bool sorted = true;
    for (std::size_t i = 1; i < listed.certificates.size(); ++i) {
        if (listed.certificates[i - 1].publisher_id > listed.certificates[i].publisher_id) sorted = false;
    }
    check(sorted, "list_certificates is sorted by publisher id");
    for (const oep::installer::PublisherCertificate& certificate : listed.certificates) {
        check(!certificate.publisher_id.empty(), "policy.json is never misread as a certificate");
    }
}

void test_policy_round_trip() {
    const std::filesystem::path root = std::filesystem::temp_directory_path() / "oep_trust_store_tests_policy";
    std::filesystem::remove_all(root);
    const oep::installer::TrustStore store(root);

    oep::installer::TrustPolicyResult policy = store.get_policy();
    check(policy.success && !policy.require_signatures, "the default policy does not require signatures");

    check(store.set_policy(true).success, "set_policy(true) succeeds");
    policy = store.get_policy();
    check(policy.success && policy.require_signatures, "the policy round-trips require_signatures = true");

    check(store.set_policy(false).success, "set_policy(false) succeeds");
    policy = store.get_policy();
    check(policy.success && !policy.require_signatures, "the policy round-trips require_signatures = false");

    std::filesystem::remove_all(root);
}

} // namespace

int main() {
    const std::filesystem::path root = std::filesystem::temp_directory_path() / "oep_trust_store_tests";
    std::filesystem::remove_all(root);
    const oep::installer::TrustStore store(root);

    test_add_then_get(store);
    test_add_rejects_invalid_input(store);
    test_get_reports_not_found(store);
    test_revoke(store);
    test_list_is_sorted_and_excludes_policy(store);
    test_policy_round_trip();

    std::filesystem::remove_all(root);

    if (g_failures == 0) {
        std::cout << "All TrustStore tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " TrustStore test(s) failed.\n";
    return 1;
}
