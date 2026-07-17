#pragma once

#include <optional>
#include <string>

namespace oep::acquisition::registry {

/// WORK-PACKAGE-002 "Trust Levels" -- numeric so ordering/filtering is
/// natural (`trust_level >= 3`), with Level 5 the most trusted.
enum class TrustLevel {
  Blocked = 0,
  Unknown = 1,
  Community = 2,
  VerifiedCommunity = 3,
  VerifiedCommercial = 4,
  Authoritative = 5,
};

/// WORK-PACKAGE-002 "Source Status" lifecycle.
enum class SourceStatus {
  Proposed,
  Approved,
  Active,
  Suspended,
  Deprecated,
  Archived,
};

/// WORK-PACKAGE-002 "Authentication Types" -- enumeration only, no
/// authentication is actually implemented against these sources.
enum class AuthenticationType {
  None,
  UsernamePassword,
  ApiKey,
  OAuth2,
  ClientCertificate,
};

[[nodiscard]] std::string to_string(TrustLevel level);
[[nodiscard]] std::optional<TrustLevel> trust_level_from_string(const std::string& text);
[[nodiscard]] std::optional<TrustLevel> trust_level_from_int(int value);

[[nodiscard]] std::string to_string(SourceStatus status);
[[nodiscard]] std::optional<SourceStatus> source_status_from_string(const std::string& text);

[[nodiscard]] std::string to_string(AuthenticationType type);
[[nodiscard]] std::optional<AuthenticationType> authentication_type_from_string(const std::string& text);

/// The Official Source Registry's domain entity (WORK-PACKAGE-002).
///
/// `id` is the externally-visible UUID (the REST API's `/sources/{id}`
/// path segment and the JSON body's "id" field) -- distinct from the
/// database's internal surrogate primary key, which never leaves the
/// Repository layer. `id` is empty for a not-yet-created source (the
/// database assigns it on INSERT); it is immutable afterward.
struct OfficialSource {
  std::string id;
  std::string name;
  std::string organization;
  std::string base_url;
  std::string description;
  std::string country;
  std::string language;
  std::string category;
  TrustLevel trust_level = TrustLevel::Unknown;
  SourceStatus status = SourceStatus::Proposed;
  AuthenticationType authentication_type = AuthenticationType::None;
  // ISO-8601 UTC, e.g. "2026-07-17T12:00:00Z". Empty for a not-yet-created
  // source; assigned by the database and immutable afterward.
  std::string created_at;
  std::string updated_at;
};

}  // namespace oep::acquisition::registry
