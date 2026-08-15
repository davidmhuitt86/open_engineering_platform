#include "oep/installer/package_verifier.hpp"

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
    const std::filesystem::path path =
        std::filesystem::temp_directory_path() / "oep_package_verifier_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

// Fixture data generated once via Node's built-in crypto (node:crypto
// Ed25519), so this from-scratch verifier is cross-checked against a
// real, independent Ed25519 implementation rather than only its own
// signing (which does not exist — Foundation never signs, see
// ed25519.hpp). Content: manifest/package.json = {"a":1},
// fragment/objects/o.json = {"b":2}.
constexpr const char* kManifestContent = R"({"a":1})";
constexpr const char* kObjectContent = R"({"b":2})";
constexpr const char* kObjectHash = "0ab1a6d394cd30195f0642b67ae1180c375ffadf5dd7f39c390668b5fdb6da93";
constexpr const char* kManifestHash = "015abd7f5cc57a2dd94b7590f04ad8084273905ee33ec5cebeae62276a97f862";
constexpr const char* kPublicKeyHex = "99c4ac9e6560c3a1e4bfd6a20e5ab6513aa77eea9233c01fe296e8b17f106cff";
constexpr const char* kSignatureHex =
    "6cffe0d091516cd4b7a56c166e831bd68069ab33f280f3c84cd6f69411b5c2485e246556d0c405214f06b0e148680614017e55f6"
    "5c42b0b99d73f444ef532507";
constexpr const char* kPublisherId = "com.pub.verifier-tests";

std::string signature_json(const std::string& public_key_hex, const std::string& signature_hex) {
    return std::string("{\"algorithm\":\"Ed25519\",\"publisherId\":\"") + kPublisherId + "\",\"publicKeyHex\":\"" +
           public_key_hex + "\",\"signatureHex\":\"" + signature_hex +
           "\",\"contentHashes\":["
           "{\"path\":\"fragment/objects/o.json\",\"sha256\":\"" +
           kObjectHash +
           "\"},"
           "{\"path\":\"manifest/package.json\",\"sha256\":\"" +
           kManifestHash + "\"}]}";
}

oep::installer::TrustStore build_trust_store_with_signer(const std::filesystem::path& root, bool revoked = false) {
    std::filesystem::remove_all(root);
    oep::installer::TrustStore store(root);
    oep::installer::PublisherCertificate certificate;
    certificate.publisher_id = kPublisherId;
    certificate.publisher_name = "Verifier Test Publisher";
    certificate.public_key_hex = kPublicKeyHex;
    certificate.issued_utc = "2026-01-01T00:00:00Z";
    certificate.expires_utc = "2030-01-01T00:00:00Z";
    certificate.issuer = "self";
    certificate.version = "1";
    store.add_certificate(certificate);
    if (revoked) {
        store.revoke_certificate(kPublisherId);
    }
    return store;
}

void test_trusted_signed_package(const std::filesystem::path& scratch_dir) {
    const oep::installer::TrustStore trust_store =
        build_trust_store_with_signer(scratch_dir / "trust_trusted");
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"fragment/objects/o.json", kObjectContent},
            {"signatures/package.sig", signature_json(kPublicKeyHex, kSignatureHex)},
        }),
        "trusted.oep");

    const oep::installer::TrustVerification result = oep::installer::verify_package_trust(archive, trust_store);
    check(result.success, "verification completes for a well-formed signed archive: " + result.error);
    check(result.state == oep::installer::TrustState::Trusted, "a correctly signed, trusted package is Trusted");
    check(result.publisher_id == kPublisherId, "the result names the correct publisher");
    check(!result.fingerprint.empty(), "the result carries the certificate fingerprint");
}

void test_unsigned_package(const std::filesystem::path& scratch_dir) {
    const oep::installer::TrustStore trust_store = build_trust_store_with_signer(scratch_dir / "trust_unsigned");
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"fragment/objects/o.json", kObjectContent},
        }),
        "unsigned.oep");

    const oep::installer::TrustVerification result = oep::installer::verify_package_trust(archive, trust_store);
    check(result.success, "verification completes for an unsigned archive");
    check(result.state == oep::installer::TrustState::Unsigned, "an archive with no signature block is Unsigned");
}

void test_unknown_publisher(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path trust_root = scratch_dir / "trust_empty";
    std::filesystem::remove_all(trust_root);
    const oep::installer::TrustStore empty_trust_store(trust_root); // no certificates added
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"fragment/objects/o.json", kObjectContent},
            {"signatures/package.sig", signature_json(kPublicKeyHex, kSignatureHex)},
        }),
        "unknown-publisher.oep");

    const oep::installer::TrustVerification result =
        oep::installer::verify_package_trust(archive, empty_trust_store);
    check(result.success, "verification completes when the publisher is unknown");
    check(result.state == oep::installer::TrustState::UnknownPublisher,
          "a signed package from an untrusted publisher is UnknownPublisher");
}

void test_revoked_publisher(const std::filesystem::path& scratch_dir) {
    const oep::installer::TrustStore trust_store =
        build_trust_store_with_signer(scratch_dir / "trust_revoked", /*revoked=*/true);
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"fragment/objects/o.json", kObjectContent},
            {"signatures/package.sig", signature_json(kPublicKeyHex, kSignatureHex)},
        }),
        "revoked.oep");

    const oep::installer::TrustVerification result = oep::installer::verify_package_trust(archive, trust_store);
    check(result.success, "verification completes for a revoked publisher");
    check(result.state == oep::installer::TrustState::RevokedCertificate,
          "a package from a revoked publisher is RevokedCertificate");
}

void test_tampered_content_after_signing(const std::filesystem::path& scratch_dir) {
    const oep::installer::TrustStore trust_store = build_trust_store_with_signer(scratch_dir / "trust_tampered");
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"fragment/objects/o.json", R"({"b":999})"}, // tampered after signing
            {"signatures/package.sig", signature_json(kPublicKeyHex, kSignatureHex)},
        }),
        "tampered.oep");

    const oep::installer::TrustVerification result = oep::installer::verify_package_trust(archive, trust_store);
    check(result.success, "verification completes for a tampered archive");
    check(result.state == oep::installer::TrustState::Tampered,
          "content that no longer matches its signed hash is Tampered");
}

void test_extra_unsigned_entry_is_tampered(const std::filesystem::path& scratch_dir) {
    const oep::installer::TrustStore trust_store = build_trust_store_with_signer(scratch_dir / "trust_extra");
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"fragment/objects/o.json", kObjectContent},
            {"fragment/objects/smuggled.json", R"({"c":3})"}, // not in the signed hash list
            {"signatures/package.sig", signature_json(kPublicKeyHex, kSignatureHex)},
        }),
        "extra-entry.oep");

    const oep::installer::TrustVerification result = oep::installer::verify_package_trust(archive, trust_store);
    check(result.success, "verification completes for an archive with an unsigned extra entry");
    check(result.state == oep::installer::TrustState::Tampered,
          "an archive entry outside signatures/ that isn't covered by the signature is Tampered");
}

void test_tampered_signature_bytes(const std::filesystem::path& scratch_dir) {
    const oep::installer::TrustStore trust_store = build_trust_store_with_signer(scratch_dir / "trust_badsig");
    std::string bad_signature_hex = kSignatureHex;
    bad_signature_hex[0] = bad_signature_hex[0] == '6' ? '7' : '6'; // flip a hex nibble
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"fragment/objects/o.json", kObjectContent},
            {"signatures/package.sig", signature_json(kPublicKeyHex, bad_signature_hex)},
        }),
        "bad-signature.oep");

    const oep::installer::TrustVerification result = oep::installer::verify_package_trust(archive, trust_store);
    check(result.success, "verification completes for a corrupted signature");
    check(result.state == oep::installer::TrustState::InvalidSignature,
          "a signature that fails to verify is InvalidSignature");
}

void test_unsupported_algorithm_is_rejected(const std::filesystem::path& scratch_dir) {
    const oep::installer::TrustStore trust_store = build_trust_store_with_signer(scratch_dir / "trust_algo");
    const std::string bad_algorithm_json =
        std::string("{\"algorithm\":\"RSA\",\"publisherId\":\"") + kPublisherId +
        "\",\"publicKeyHex\":\"" + kPublicKeyHex + "\",\"signatureHex\":\"" + kSignatureHex +
        "\",\"contentHashes\":[]}";
    const std::filesystem::path archive = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kManifestContent},
            {"signatures/package.sig", bad_algorithm_json},
        }),
        "bad-algorithm.oep");

    const oep::installer::TrustVerification result = oep::installer::verify_package_trust(archive, trust_store);
    check(result.success, "verification completes for an unsupported algorithm");
    check(result.state == oep::installer::TrustState::InvalidSignature,
          "PKG-005 §8: an unknown mandatory algorithm (non-Ed25519) is rejected as InvalidSignature");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_package_verifier_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_trusted_signed_package(scratch_dir);
    test_unsigned_package(scratch_dir);
    test_unknown_publisher(scratch_dir);
    test_revoked_publisher(scratch_dir);
    test_tampered_content_after_signing(scratch_dir);
    test_extra_unsigned_entry_is_tampered(scratch_dir);
    test_tampered_signature_bytes(scratch_dir);
    test_unsupported_algorithm_is_rejected(scratch_dir);

    std::filesystem::remove_all(scratch_dir);
    std::filesystem::remove_all(std::filesystem::temp_directory_path() / "oep_package_verifier_tests");

    if (g_failures == 0) {
        std::cout << "All package_verifier tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " package_verifier test(s) failed.\n";
    return 1;
}
