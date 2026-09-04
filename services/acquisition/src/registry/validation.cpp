#include "oep/acquisition/registry/validation.hpp"

namespace oep::acquisition::registry {

namespace {

std::string get_string(const nlohmann::json& body, const char* key) {
  if (body.contains(key) && body.at(key).is_string()) {
    return body.at(key).get<std::string>();
  }
  return {};
}

/// Validates the fields WORK-PACKAGE-002 requires regardless of whether
/// this is a create or an update, appending any violation found to
/// `violations`. Returns the parsed trust level / status so callers don't
/// need to re-parse them.
void validate_common_fields(const nlohmann::json& body, std::vector<std::string>& violations,
                             OfficialSource& out) {
  out.name = get_string(body, "name");
  if (out.name.empty()) {
    violations.emplace_back("Name is required.");
  }

  out.base_url = get_string(body, "base_url");
  if (out.base_url.empty()) {
    violations.emplace_back("Base URL is required.");
  }

  if (!body.contains("trust_level") || !body.at("trust_level").is_number_integer()) {
    violations.emplace_back("Trust Level is required.");
  } else if (const auto level = trust_level_from_int(body.at("trust_level").get<int>()); level.has_value()) {
    out.trust_level = *level;
  } else {
    violations.emplace_back("Trust Level must be an integer between 0 and 5.");
  }

  if (!body.contains("status") || !body.at("status").is_string()) {
    violations.emplace_back("Status is required.");
  } else if (const auto status = source_status_from_string(body.at("status").get<std::string>());
             status.has_value()) {
    out.status = *status;
  } else {
    violations.emplace_back(
        "Status must be one of: proposed, approved, active, suspended, deprecated, archived.");
  }

  if (body.contains("authentication_type") && body.at("authentication_type").is_string()) {
    if (const auto auth = authentication_type_from_string(body.at("authentication_type").get<std::string>());
        auth.has_value()) {
      out.authentication_type = *auth;
    } else {
      violations.emplace_back(
          "Authentication Type must be one of: none, username_password, api_key, oauth2, client_certificate.");
    }
  }

  out.organization = get_string(body, "organization");
  out.description = get_string(body, "description");
  out.country = get_string(body, "country");
  out.language = get_string(body, "language");
  out.category = get_string(body, "category");
}

}  // namespace

ValidationError::ValidationError(std::vector<std::string> violations)
    : std::runtime_error("Validation failed"), violations_(std::move(violations)) {}

const std::vector<std::string>& ValidationError::violations() const {
  return violations_;
}

OfficialSource parse_and_validate_create(const nlohmann::json& body) {
  std::vector<std::string> violations;
  OfficialSource source;
  validate_common_fields(body, violations, source);

  if (!violations.empty()) {
    throw ValidationError(std::move(violations));
  }

  // Assigned by the repository on INSERT.
  source.id.clear();
  source.created_at.clear();
  source.updated_at.clear();
  return source;
}

OfficialSource parse_and_validate_update(const nlohmann::json& body, const OfficialSource& existing) {
  std::vector<std::string> violations;
  OfficialSource source;
  validate_common_fields(body, violations, source);

  if (const std::string id = get_string(body, "id"); !id.empty() && id != existing.id) {
    violations.emplace_back("id is immutable and cannot be changed.");
  }
  if (const std::string created_at = get_string(body, "created_at");
      !created_at.empty() && created_at != existing.created_at) {
    violations.emplace_back("created_at is immutable and cannot be changed.");
  }

  if (!violations.empty()) {
    throw ValidationError(std::move(violations));
  }

  source.id = existing.id;
  source.created_at = existing.created_at;
  source.updated_at.clear();  // Assigned by the repository on UPDATE.
  return source;
}

}  // namespace oep::acquisition::registry
