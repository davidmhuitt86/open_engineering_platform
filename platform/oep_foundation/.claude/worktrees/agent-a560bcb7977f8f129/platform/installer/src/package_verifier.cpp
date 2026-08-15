#include "oep/installer/package_verifier.hpp"

#include <algorithm>
#include <map>
#include <optional>

#include "oep/installer/ed25519.hpp"
#include "oep/installer/sha256.hpp"
#include "oep/installer/zip_reader.hpp"
#include "oep/repository/json_value.hpp"
#include "oep/repository/timestamp.hpp"

namespace oep::installer {

namespace {

namespace json = oep::repository::json;

constexpr const char* kSignatureEntryPath = "signatures/package.sig";
constexpr const char* kSignaturesPrefix = "signatures/";

std::string read_string_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

std::optional<std::vector<std::uint8_t>> hex_to_bytes(const std::string& hex) {
    if (hex.size() % 2 != 0) {
        return std::nullopt;
    }
    auto nibble = [](char c) -> int {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return -1;
    };
    std::vector<std::uint8_t> bytes;
    for (std::size_t i = 0; i + 1 < hex.size(); i += 2) {
        const int high = nibble(hex[i]);
        const int low = nibble(hex[i + 1]);
        if (high < 0 || low < 0) {
            return std::nullopt;
        }
        bytes.push_back(static_cast<std::uint8_t>((high << 4) | low));
    }
    return bytes;
}

std::string to_lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return c >= 'A' && c <= 'Z' ? static_cast<char>(c - 'A' + 'a') : static_cast<char>(c);
    });
    return value;
}

TrustVerification failed_state(TrustState state, const std::string& publisher_id, const std::string& detail) {
    TrustVerification result;
    result.success = true;
    result.state = state;
    result.publisher_id = publisher_id;
    result.detail = detail;
    return result;
}

} // namespace

std::string to_string(TrustState state) {
    switch (state) {
        case TrustState::Trusted: return "Trusted";
        case TrustState::Unsigned: return "Unsigned";
        case TrustState::UnknownPublisher: return "UnknownPublisher";
        case TrustState::ExpiredCertificate: return "ExpiredCertificate";
        case TrustState::RevokedCertificate: return "RevokedCertificate";
        case TrustState::InvalidSignature: return "InvalidSignature";
        case TrustState::Tampered: return "Tampered";
    }
    return "InvalidSignature";
}

TrustVerification verify_package_trust(const std::filesystem::path& archive_path, const TrustStore& trust_store) {
    TrustVerification result;

    std::string error;
    std::optional<ZipReader> reader = ZipReader::open(archive_path, error);
    if (!reader.has_value()) {
        result.error = error;
        return result;
    }

    if (!reader->has_entry(kSignatureEntryPath)) {
        return failed_state(TrustState::Unsigned, "",
                            "the archive contains no '" + std::string(kSignatureEntryPath) + "' signature block");
    }

    const std::optional<std::string> signature_json = reader->read_text(kSignatureEntryPath, error);
    if (!signature_json.has_value()) {
        result.error = error;
        return result;
    }

    const json::ParseResult parsed = json::parse(*signature_json);
    if (!parsed.success || !parsed.value.is_object()) {
        return failed_state(TrustState::InvalidSignature, "", "the signature block is not valid JSON");
    }

    const std::string algorithm = read_string_field(parsed.value, "algorithm");
    const std::string publisher_id = read_string_field(parsed.value, "publisherId");
    const std::string public_key_hex = to_lower(read_string_field(parsed.value, "publicKeyHex"));
    const std::string signature_hex = read_string_field(parsed.value, "signatureHex");

    // PKG-005 §8: Ed25519 is required; implementations shall reject
    // unknown mandatory algorithms rather than skipping verification.
    if (algorithm != "Ed25519") {
        return failed_state(TrustState::InvalidSignature, publisher_id,
                            "unsupported signing algorithm '" + algorithm + "' (only Ed25519 is supported)");
    }
    if (publisher_id.empty()) {
        return failed_state(TrustState::InvalidSignature, "", "the signature block names no publisherId");
    }

    // Collect the signed content-hash list.
    const json::Value* content_hashes = parsed.value.find("contentHashes");
    if (content_hashes == nullptr || !content_hashes->is_array()) {
        return failed_state(TrustState::InvalidSignature, publisher_id,
                            "the signature block has no contentHashes list");
    }
    std::map<std::string, std::string> signed_hashes; // path -> sha256 (sorted by path)
    for (const json::Value& entry : content_hashes->as_array()) {
        if (!entry.is_object()) {
            return failed_state(TrustState::InvalidSignature, publisher_id, "malformed contentHashes entry");
        }
        const std::string path = read_string_field(entry, "path");
        const std::string sha256 = to_lower(read_string_field(entry, "sha256"));
        if (path.empty() || sha256.size() != 64) {
            return failed_state(TrustState::InvalidSignature, publisher_id, "malformed contentHashes entry");
        }
        signed_hashes[path] = sha256;
    }

    // PKG-005 §9/§10: every archive entry outside signatures/ must be
    // covered by the signed hash list, and every listed entry must exist
    // and match. Any mismatch or omission is tampering.
    for (const std::string& name : reader->entry_names()) {
        if (name.compare(0, std::string(kSignaturesPrefix).size(), kSignaturesPrefix) == 0) {
            continue;
        }
        const auto listed = signed_hashes.find(name);
        if (listed == signed_hashes.end()) {
            return failed_state(TrustState::Tampered, publisher_id,
                                "archive entry '" + name + "' is not covered by the package signature");
        }
        const std::optional<std::vector<std::uint8_t>> bytes = reader->read_bytes(name, error);
        if (!bytes.has_value()) {
            result.error = error;
            return result;
        }
        if (sha256_hex(*bytes) != listed->second) {
            return failed_state(TrustState::Tampered, publisher_id,
                                "archive entry '" + name + "' does not match its signed hash");
        }
    }
    for (const auto& [path, hash] : signed_hashes) {
        (void)hash;
        if (!reader->has_entry(path)) {
            return failed_state(TrustState::Tampered, publisher_id,
                                "signed entry '" + path + "' is missing from the archive");
        }
    }

    // Certificate checks against the Trust Store (offline, PKG-005 §3).
    const GetCertificateResult certificate = trust_store.get_certificate(publisher_id);
    if (!certificate.success) {
        result.error = certificate.error;
        return result;
    }
    if (!certificate.found) {
        return failed_state(TrustState::UnknownPublisher, publisher_id,
                            "publisher '" + publisher_id + "' has no certificate in this repository's Trust Store");
    }
    result.fingerprint = certificate.certificate.fingerprint;
    if (certificate.certificate.revoked) {
        TrustVerification revoked = failed_state(TrustState::RevokedCertificate, publisher_id,
                                                  "publisher '" + publisher_id + "' is revoked");
        revoked.fingerprint = certificate.certificate.fingerprint;
        return revoked;
    }
    if (!certificate.certificate.expires_utc.empty() &&
        certificate.certificate.expires_utc < oep::repository::current_timestamp_utc()) {
        TrustVerification expired =
            failed_state(TrustState::ExpiredCertificate, publisher_id,
                         "publisher '" + publisher_id + "' certificate expired " +
                             certificate.certificate.expires_utc);
        expired.fingerprint = certificate.certificate.fingerprint;
        return expired;
    }
    if (to_lower(certificate.certificate.public_key_hex) != public_key_hex) {
        TrustVerification mismatch = failed_state(
            TrustState::InvalidSignature, publisher_id,
            "the signature's public key does not match publisher '" + publisher_id + "' trusted certificate");
        mismatch.fingerprint = certificate.certificate.fingerprint;
        return mismatch;
    }

    // Signature verification over the canonical content-hash payload:
    // entries sorted by path (std::map iteration order), one
    // `<path>\n<sha256>\n` pair per entry.
    std::string payload;
    for (const auto& [path, hash] : signed_hashes) {
        payload += path;
        payload += '\n';
        payload += hash;
        payload += '\n';
    }

    const std::optional<std::vector<std::uint8_t>> public_key_bytes = hex_to_bytes(public_key_hex);
    const std::optional<std::vector<std::uint8_t>> signature_bytes = hex_to_bytes(to_lower(signature_hex));
    if (!public_key_bytes.has_value() || public_key_bytes->size() != 32 || !signature_bytes.has_value() ||
        signature_bytes->size() != 64) {
        TrustVerification malformed = failed_state(TrustState::InvalidSignature, publisher_id,
                                                    "malformed public key or signature encoding");
        malformed.fingerprint = certificate.certificate.fingerprint;
        return malformed;
    }
    std::array<std::uint8_t, 32> public_key{};
    std::array<std::uint8_t, 64> signature{};
    std::copy(public_key_bytes->begin(), public_key_bytes->end(), public_key.begin());
    std::copy(signature_bytes->begin(), signature_bytes->end(), signature.begin());

    if (!ed25519_verify(std::vector<std::uint8_t>(payload.begin(), payload.end()), public_key, signature)) {
        TrustVerification invalid = failed_state(TrustState::InvalidSignature, publisher_id,
                                                  "the Ed25519 signature does not verify");
        invalid.fingerprint = certificate.certificate.fingerprint;
        return invalid;
    }

    result.success = true;
    result.state = TrustState::Trusted;
    result.publisher_id = publisher_id;
    result.detail = "signed by trusted publisher '" + publisher_id + "'";
    return result;
}

} // namespace oep::installer
