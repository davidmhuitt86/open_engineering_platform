#include "oep/runtime/foundation_runtime.hpp"

#include "oep/repository/metadata.hpp"

#include <cstdint>
#include <filesystem>
#include <fstream>
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

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    metadata.repository_name = "my-workshop";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);
    return root;
}

void append_u16(std::vector<std::uint8_t>& out, std::uint16_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}
void append_u32(std::vector<std::uint8_t>& out, std::uint32_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}
void append_bytes(std::vector<std::uint8_t>& out, const std::string& text) {
    out.insert(out.end(), text.begin(), text.end());
}

std::vector<std::uint8_t> build_stored_zip(const std::vector<std::pair<std::string, std::string>>& entries) {
    std::vector<std::uint8_t> out;
    std::vector<std::uint32_t> local_header_offsets;
    for (const auto& [name, content] : entries) {
        local_header_offsets.push_back(static_cast<std::uint32_t>(out.size()));
        append_u32(out, 0x04034b50);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_bytes(out, name);
        append_bytes(out, content);
    }
    const std::uint32_t central_directory_start = static_cast<std::uint32_t>(out.size());
    for (std::size_t i = 0; i < entries.size(); ++i) {
        const auto& [name, content] = entries[i];
        append_u32(out, 0x02014b50);
        append_u16(out, 20);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, local_header_offsets[i]);
        append_bytes(out, name);
    }
    const std::uint32_t central_directory_size = static_cast<std::uint32_t>(out.size()) - central_directory_start;
    append_u32(out, 0x06054b50);
    append_u16(out, 0);
    append_u16(out, 0);
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u32(out, central_directory_size);
    append_u32(out, central_directory_start);
    append_u16(out, 0);
    return out;
}

std::filesystem::path write_temp_archive(const std::vector<std::uint8_t>& bytes, const std::string& file_name) {
    const std::filesystem::path path = std::filesystem::temp_directory_path() / "oep_trust_integration_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

// Fixture generated via Node's built-in crypto (Ed25519), matching the
// exact manifest/object bytes below. See tests/installer/package_verifier_
// tests.cpp for the corresponding module-level fixture.
constexpr const char* kManifest =
    R"({"schemaVersion":"1.0","packageId":"com.oep.demo.trusted","version":"1.0.0",)"
    R"("publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},"title":"Trust Demo Package",)"
    R"("summary":"s","description":"d","category":"demonstration","engineeringDomains":["Automotive"],)"
    R"("license":{},"dependencies":[],"capabilities":[],"repository":{},"statistics":{},"signatures":{},)"
    R"("build":{}})";
constexpr const char* kObject =
    R"({"objectId":"aaaaaaaa-4444-4000-8000-000000000001","objectType":"Component","name":"Trusted Widget",)"
    R"("description":"d","createdUtc":"2026-01-01T00:00:00Z","lastModifiedUtc":"2026-01-01T00:00:00Z",)"
    R"("version":"1.0.0","author":"a","tags":[]})";
constexpr const char* kManifestHash = "7226332deb1a9254c96ccb3efc0211e18a60f10345201d0777b3d1987e77b0d6";
constexpr const char* kObjectHash = "17c6088a8c9a4fada1e81ffc727f8d0fb8516af1f04e12225295fcf8df2ca6c0";
constexpr const char* kPublisherId = "demo-publisher";
constexpr const char* kPublicKeyHex = "677d562f1182de55225b69a27bfc77a66b45a6523565bca4ad2b5743fa31dea3";
constexpr const char* kSignatureHex =
    "2b274d664cd409adf41e6b8b19b62fcd78e104c23ec2a34ecdf0f291a6781a297c34140704f43b678ceeba8a3be191c2d0630f40"
    "4180d0b91dc773f0f4f20c09";
constexpr const char* kFingerprint = "ba7156b3d4a7036e48d12e68b88e65a1ecf1d959e97f3726744d3dbf6ba8ddc9";

std::string signature_json(const std::string& public_key_hex) {
    return std::string("{\"algorithm\":\"Ed25519\",\"publisherId\":\"") + kPublisherId + "\",\"publicKeyHex\":\"" +
           public_key_hex + "\",\"signatureHex\":\"" + kSignatureHex +
           "\",\"contentHashes\":["
           "{\"path\":\"fragment/objects/a.json\",\"sha256\":\"" +
           kObjectHash +
           "\"},"
           "{\"path\":\"manifest/package.json\",\"sha256\":\"" +
           kManifestHash + "\"}]}";
}

std::filesystem::path build_signed_archive(const std::string& file_name) {
    return write_temp_archive(build_stored_zip({
                                   {"manifest/package.json", kManifest},
                                   {"fragment/objects/a.json", kObject},
                                   {"signatures/package.sig", signature_json(kPublicKeyHex)},
                               }),
                               file_name);
}

std::filesystem::path build_unsigned_archive(const std::string& file_name) {
    return write_temp_archive(build_stored_zip({
                                   {"manifest/package.json", kManifest},
                                   {"fragment/objects/a.json", kObject},
                               }),
                               file_name);
}

oep::installer::PublisherCertificate trusted_certificate() {
    oep::installer::PublisherCertificate certificate;
    certificate.publisher_id = kPublisherId;
    certificate.publisher_name = "Demo Publisher";
    certificate.public_key_hex = kPublicKeyHex;
    certificate.issued_utc = "2026-01-01T00:00:00Z";
    certificate.expires_utc = "2030-01-01T00:00:00Z";
    certificate.issuer = "self";
    certificate.version = "1";
    return certificate;
}

void test_unsigned_package_still_installs_by_default(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "unsigned_default");
    const std::filesystem::path archive = build_unsigned_archive("unsigned-default.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(result.success, "an unsigned package still installs by default (WP-REP-001-003 behavior preserved): " +
                               result.error);
    check(result.trust_status == "Unsigned", "the install result reports Unsigned trust status");

    const oep::runtime::RuntimeInstalledPackageResult installed =
        runtime.get_installed_package("com.oep.demo.trusted");
    check(installed.success && installed.installed && installed.entry.trust_status == "Unsigned",
          "the Repository Registry entry records Unsigned trust status");

    runtime.shutdown();
}

void test_signed_but_untrusted_publisher_is_rejected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "unknown_publisher");
    const std::filesystem::path archive = build_signed_archive("unknown-publisher.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(!result.success, "a signed package from an untrusted publisher is rejected");
    check(result.trust_status == "UnknownPublisher", "the rejection reports UnknownPublisher trust status");

    // Trust verification runs BEFORE any Repository Transaction begins
    // (this Work Package's explicit requirement): no transaction should
    // ever have been journaled for a trust-rejected install.
    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    check(history.success && history.records.empty(),
          "no transaction is journaled when trust verification rejects an install before any transaction begins");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.empty(), "nothing was created for a trust-rejected install");

    runtime.shutdown();
}

void test_trusted_signed_package_installs(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "trusted");
    const std::filesystem::path archive = build_signed_archive("trusted.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    check(runtime.trust_add_certificate(trusted_certificate()).success, "adding the trusted certificate succeeds");

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(result.success, "a package signed by a trusted publisher installs: " + result.error);
    check(result.trust_status == "Trusted", "the install result reports Trusted");
    check(result.objects_created == 1, "the trusted install created its object");

    const oep::runtime::RuntimeInstalledPackageResult installed =
        runtime.get_installed_package("com.oep.demo.trusted");
    check(installed.success && installed.installed && installed.entry.trust_status == "Trusted",
          "the Repository Registry entry records Trusted trust status");
    check(installed.entry.trust_fingerprint == kFingerprint,
          "the Repository Registry entry records the certificate fingerprint");

    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    check(history.success && history.records.size() == 1,
          "a trusted install proceeds through exactly one Repository Transaction, as normal");

    runtime.shutdown();
}

void test_revoked_publisher_is_rejected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "revoked");
    const std::filesystem::path archive = build_signed_archive("revoked.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    runtime.trust_add_certificate(trusted_certificate());
    check(runtime.trust_revoke_certificate(kPublisherId).success, "revoking the certificate succeeds");

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(!result.success, "a package from a revoked publisher is rejected");
    check(result.trust_status == "RevokedCertificate", "the rejection reports RevokedCertificate");

    runtime.shutdown();
}

void test_policy_requires_signatures_rejects_unsigned(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "policy_strict");
    const std::filesystem::path archive = build_unsigned_archive("policy-strict.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    check(runtime.trust_set_policy(true).success, "set_policy(true) succeeds");

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(!result.success, "an unsigned package is rejected when the trust policy requires signatures");
    check(result.error.find("requires signed packages") != std::string::npos,
          "the rejection explains the policy requirement");

    runtime.shutdown();
}

void test_trust_store_runtime_queries(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "trust_queries");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    oep::runtime::RuntimeTrustPolicyResult policy = runtime.trust_get_policy();
    check(policy.success && !policy.require_signatures, "the default trust policy does not require signatures");

    check(runtime.trust_add_certificate(trusted_certificate()).success, "trust_add_certificate succeeds");
    const oep::runtime::RuntimeCertificateResult found = runtime.trust_get_certificate(kPublisherId);
    check(found.success && found.found && found.certificate.publisher_name == "Demo Publisher",
          "trust_get_certificate finds the added certificate");

    const oep::runtime::RuntimeCertificateListResult listed = runtime.trust_list_certificates();
    check(listed.success && listed.certificates.size() == 1, "trust_list_certificates lists the added certificate");

    check(runtime.trust_revoke_certificate(kPublisherId).success, "trust_revoke_certificate succeeds");
    const oep::runtime::RuntimeCertificateResult revoked = runtime.trust_get_certificate(kPublisherId);
    check(revoked.success && revoked.found && revoked.certificate.revoked,
          "the certificate is kept, marked revoked, after trust_revoke_certificate");

    runtime.shutdown();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_trust_integration_runtime_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_unsigned_package_still_installs_by_default(scratch_dir);
    test_signed_but_untrusted_publisher_is_rejected(scratch_dir);
    test_trusted_signed_package_installs(scratch_dir);
    test_revoked_publisher_is_rejected(scratch_dir);
    test_policy_requires_signatures_rejects_unsigned(scratch_dir);
    test_trust_store_runtime_queries(scratch_dir);

    std::filesystem::remove_all(scratch_dir);
    std::filesystem::remove_all(std::filesystem::temp_directory_path() / "oep_trust_integration_tests");

    if (g_failures == 0) {
        std::cout << "All trust integration (FoundationRuntime) tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " trust integration test(s) failed.\n";
    return 1;
}
