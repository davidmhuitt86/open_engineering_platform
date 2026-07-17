#include "oep/acquisition/registry/official_source.hpp"

namespace oep::acquisition::registry {

std::string to_string(TrustLevel level) {
  switch (level) {
    case TrustLevel::Blocked:
      return "blocked";
    case TrustLevel::Unknown:
      return "unknown";
    case TrustLevel::Community:
      return "community";
    case TrustLevel::VerifiedCommunity:
      return "verified_community";
    case TrustLevel::VerifiedCommercial:
      return "verified_commercial";
    case TrustLevel::Authoritative:
      return "authoritative";
  }
  return "unknown";
}

std::optional<TrustLevel> trust_level_from_string(const std::string& text) {
  if (text == "blocked") return TrustLevel::Blocked;
  if (text == "unknown") return TrustLevel::Unknown;
  if (text == "community") return TrustLevel::Community;
  if (text == "verified_community") return TrustLevel::VerifiedCommunity;
  if (text == "verified_commercial") return TrustLevel::VerifiedCommercial;
  if (text == "authoritative") return TrustLevel::Authoritative;
  return std::nullopt;
}

std::optional<TrustLevel> trust_level_from_int(int value) {
  if (value < 0 || value > 5) {
    return std::nullopt;
  }
  return static_cast<TrustLevel>(value);
}

std::string to_string(SourceStatus status) {
  switch (status) {
    case SourceStatus::Proposed:
      return "proposed";
    case SourceStatus::Approved:
      return "approved";
    case SourceStatus::Active:
      return "active";
    case SourceStatus::Suspended:
      return "suspended";
    case SourceStatus::Deprecated:
      return "deprecated";
    case SourceStatus::Archived:
      return "archived";
  }
  return "proposed";
}

std::optional<SourceStatus> source_status_from_string(const std::string& text) {
  if (text == "proposed") return SourceStatus::Proposed;
  if (text == "approved") return SourceStatus::Approved;
  if (text == "active") return SourceStatus::Active;
  if (text == "suspended") return SourceStatus::Suspended;
  if (text == "deprecated") return SourceStatus::Deprecated;
  if (text == "archived") return SourceStatus::Archived;
  return std::nullopt;
}

std::string to_string(AuthenticationType type) {
  switch (type) {
    case AuthenticationType::None:
      return "none";
    case AuthenticationType::UsernamePassword:
      return "username_password";
    case AuthenticationType::ApiKey:
      return "api_key";
    case AuthenticationType::OAuth2:
      return "oauth2";
    case AuthenticationType::ClientCertificate:
      return "client_certificate";
  }
  return "none";
}

std::optional<AuthenticationType> authentication_type_from_string(const std::string& text) {
  if (text == "none") return AuthenticationType::None;
  if (text == "username_password") return AuthenticationType::UsernamePassword;
  if (text == "api_key") return AuthenticationType::ApiKey;
  if (text == "oauth2") return AuthenticationType::OAuth2;
  if (text == "client_certificate") return AuthenticationType::ClientCertificate;
  return std::nullopt;
}

}  // namespace oep::acquisition::registry
