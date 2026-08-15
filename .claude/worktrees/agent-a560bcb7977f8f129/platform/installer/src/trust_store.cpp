#include "oep/installer/trust_store.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <sstream>
#include <system_error>

#include "oep/installer/sha256.hpp"
#include "oep/repository/json_value.hpp"
#include "oep/repository/timestamp.hpp"

namespace oep::installer {

namespace {

namespace json = oep::repository::json;

std::string read_string_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

bool read_bool_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return found != nullptr && found->is_bool() && found->as_bool();
}

bool is_valid_public_key_hex(const std::string& hex) {
    if (hex.size() != 64) {
        return false;
    }
    for (const char c : hex) {
        const bool is_hex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
        if (!is_hex) return false;
    }
    return true;
}

std::vector<std::uint8_t> hex_to_bytes(const std::string& hex) {
    auto nibble = [](char c) -> std::uint8_t {
        if (c >= '0' && c <= '9') return static_cast<std::uint8_t>(c - '0');
        if (c >= 'a' && c <= 'f') return static_cast<std::uint8_t>(c - 'a' + 10);
        return static_cast<std::uint8_t>(c - 'A' + 10);
    };
    std::vector<std::uint8_t> bytes;
    for (std::size_t i = 0; i + 1 < hex.size(); i += 2) {
        bytes.push_back(static_cast<std::uint8_t>((nibble(hex[i]) << 4) | nibble(hex[i + 1])));
    }
    return bytes;
}

json::Value to_json(const PublisherCertificate& certificate) {
    json::Object fields;
    fields.emplace_back("publisherId", json::Value::string(certificate.publisher_id));
    fields.emplace_back("publisherName", json::Value::string(certificate.publisher_name));
    fields.emplace_back("publicKeyHex", json::Value::string(certificate.public_key_hex));
    fields.emplace_back("issuedUtc", json::Value::string(certificate.issued_utc));
    fields.emplace_back("expiresUtc", json::Value::string(certificate.expires_utc));
    fields.emplace_back("issuer", json::Value::string(certificate.issuer));
    fields.emplace_back("version", json::Value::string(certificate.version));
    fields.emplace_back("fingerprint", json::Value::string(certificate.fingerprint));
    fields.emplace_back("revoked", json::Value::boolean(certificate.revoked));
    fields.emplace_back("revokedUtc", json::Value::string(certificate.revoked_utc));
    return json::Value::object(std::move(fields));
}

struct ParsedCertificate {
    bool success = false;
    std::string error;
    PublisherCertificate certificate;
};

ParsedCertificate read_certificate_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'", {}};
    }
    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();

    const json::ParseResult parsed = json::parse(contents_stream.str());
    if (!parsed.success) {
        return {false, "invalid JSON in '" + path.string() + "': " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "'" + path.string() + "' must contain a JSON object", {}};
    }

    PublisherCertificate certificate;
    certificate.publisher_id = read_string_field(parsed.value, "publisherId");
    certificate.publisher_name = read_string_field(parsed.value, "publisherName");
    certificate.public_key_hex = read_string_field(parsed.value, "publicKeyHex");
    certificate.issued_utc = read_string_field(parsed.value, "issuedUtc");
    certificate.expires_utc = read_string_field(parsed.value, "expiresUtc");
    certificate.issuer = read_string_field(parsed.value, "issuer");
    certificate.version = read_string_field(parsed.value, "version");
    certificate.fingerprint = read_string_field(parsed.value, "fingerprint");
    certificate.revoked = read_bool_field(parsed.value, "revoked");
    certificate.revoked_utc = read_string_field(parsed.value, "revokedUtc");
    return {true, "", certificate};
}

TrustStoreResult write_certificate_file(const std::filesystem::path& path,
                                         const PublisherCertificate& certificate) {
    std::error_code error_code;
    std::filesystem::create_directories(path.parent_path(), error_code);
    if (error_code) {
        return {false, "could not create '" + path.parent_path().string() + "': " + error_code.message()};
    }
    const std::string serialized = json::serialize(to_json(certificate));
    const std::filesystem::path temp_path = path.string() + ".tmp";
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file) {
            return {false, "could not open '" + temp_path.string() + "' for writing"};
        }
        file << serialized;
    }
    std::filesystem::rename(temp_path, path, error_code);
    if (error_code) {
        std::filesystem::remove(temp_path, error_code);
        return {false, "could not finalize '" + path.string() + "': " + error_code.message()};
    }
    return {true, ""};
}

std::string to_lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(),
                    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

} // namespace

TrustStore::TrustStore(std::filesystem::path trust_root) : trust_root_(std::move(trust_root)) {}

std::filesystem::path TrustStore::path_for(const std::string& publisher_id) const {
    return trust_root_ / (publisher_id + ".json");
}

TrustStoreResult TrustStore::add_certificate(const PublisherCertificate& certificate) const {
    if (certificate.publisher_id.empty()) {
        return {false, "a publisher certificate must have a publisherId"};
    }
    if (!is_valid_public_key_hex(certificate.public_key_hex)) {
        return {false, "publicKeyHex must be exactly 64 hex characters (a raw 32-byte Ed25519 public key)"};
    }

    const std::filesystem::path path = path_for(certificate.publisher_id);
    std::error_code error_code;
    if (std::filesystem::exists(path, error_code)) {
        return {false, "publisher '" + certificate.publisher_id +
                            "' already has a trusted certificate; certificate renewal is not part of this Work Package"};
    }

    PublisherCertificate stored = certificate;
    stored.public_key_hex = to_lower(stored.public_key_hex);
    // The fingerprint is always computed locally from the key itself,
    // never trusted from input (PKG-005 §7).
    stored.fingerprint = sha256_hex(hex_to_bytes(stored.public_key_hex));
    stored.revoked = false;
    stored.revoked_utc.clear();
    return write_certificate_file(path, stored);
}

GetCertificateResult TrustStore::get_certificate(const std::string& publisher_id) const {
    const std::filesystem::path path = path_for(publisher_id);
    std::error_code error_code;
    if (!std::filesystem::exists(path, error_code)) {
        return {true, "", false, {}};
    }
    const ParsedCertificate parsed = read_certificate_file(path);
    if (!parsed.success) {
        return {false, parsed.error, false, {}};
    }
    return {true, "", true, parsed.certificate};
}

ListCertificatesResult TrustStore::list_certificates() const {
    std::vector<PublisherCertificate> certificates;

    std::error_code error_code;
    if (!std::filesystem::exists(trust_root_, error_code)) {
        return {true, "", certificates};
    }
    for (const std::filesystem::directory_entry& entry :
         std::filesystem::directory_iterator(trust_root_, error_code)) {
        if (!entry.is_regular_file() || entry.path().extension() != ".json" ||
            entry.path().filename() == "policy.json") {
            continue;
        }
        const ParsedCertificate parsed = read_certificate_file(entry.path());
        if (parsed.success) {
            certificates.push_back(parsed.certificate);
        }
    }
    if (error_code) {
        return {false, "could not enumerate '" + trust_root_.string() + "': " + error_code.message(), {}};
    }

    std::sort(certificates.begin(), certificates.end(),
              [](const PublisherCertificate& a, const PublisherCertificate& b) {
                  return a.publisher_id < b.publisher_id;
              });
    return {true, "", certificates};
}

TrustStoreResult TrustStore::revoke_certificate(const std::string& publisher_id) const {
    const std::filesystem::path path = path_for(publisher_id);
    std::error_code error_code;
    if (!std::filesystem::exists(path, error_code)) {
        return {false, "publisher '" + publisher_id + "' has no trusted certificate to revoke"};
    }
    const ParsedCertificate parsed = read_certificate_file(path);
    if (!parsed.success) {
        return {false, parsed.error};
    }
    PublisherCertificate revoked = parsed.certificate;
    if (revoked.revoked) {
        return {false, "publisher '" + publisher_id + "' is already revoked"};
    }
    revoked.revoked = true;
    revoked.revoked_utc = oep::repository::current_timestamp_utc();
    return write_certificate_file(path, revoked);
}

TrustPolicyResult TrustStore::get_policy() const {
    const std::filesystem::path path = trust_root_ / "policy.json";
    std::error_code error_code;
    if (!std::filesystem::exists(path, error_code)) {
        return {true, "", false}; // default: signatures not required
    }
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'", false};
    }
    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();
    const json::ParseResult parsed = json::parse(contents_stream.str());
    if (!parsed.success || !parsed.value.is_object()) {
        return {false, "invalid trust policy file '" + path.string() + "'", false};
    }
    return {true, "", read_bool_field(parsed.value, "requireSignatures")};
}

TrustStoreResult TrustStore::set_policy(bool require_signatures) const {
    std::error_code error_code;
    std::filesystem::create_directories(trust_root_, error_code);
    if (error_code) {
        return {false, "could not create '" + trust_root_.string() + "': " + error_code.message()};
    }
    json::Object fields;
    fields.emplace_back("requireSignatures", json::Value::boolean(require_signatures));
    const std::string serialized = json::serialize(json::Value::object(std::move(fields)));
    const std::filesystem::path path = trust_root_ / "policy.json";
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    if (!file) {
        return {false, "could not open '" + path.string() + "' for writing"};
    }
    file << serialized;
    return {true, ""};
}

} // namespace oep::installer
