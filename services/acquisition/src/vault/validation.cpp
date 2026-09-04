#include "oep/acquisition/vault/validation.hpp"

namespace oep::acquisition::vault {

namespace {

std::string get_string(const nlohmann::json& body, const char* key) {
  if (body.contains(key) && body.at(key).is_string()) {
    return body.at(key).get<std::string>();
  }
  return {};
}

}  // namespace

ValidationError::ValidationError(std::vector<std::string> violations)
    : std::runtime_error("Validation failed"), violations_(std::move(violations)) {}

const std::vector<std::string>& ValidationError::violations() const {
  return violations_;
}

PublishArtifactRequest parse_and_validate_publish(const nlohmann::json& body) {
  std::vector<std::string> violations;
  PublishArtifactRequest request;

  request.metadata_id = get_string(body, "metadata_id");
  if (request.metadata_id.empty()) {
    violations.emplace_back("Metadata ID is required.");
  }

  if (!violations.empty()) {
    throw ValidationError(std::move(violations));
  }

  return request;
}

}  // namespace oep::acquisition::vault
