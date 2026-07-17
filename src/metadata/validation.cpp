#include "oep/acquisition/metadata/validation.hpp"

namespace oep::acquisition::metadata {

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

CreateMetadataRequest parse_and_validate_create(const nlohmann::json& body) {
  std::vector<std::string> violations;
  CreateMetadataRequest request;

  request.verification_id = get_string(body, "verification_id");
  if (request.verification_id.empty()) {
    violations.emplace_back("Verification ID is required.");
  }

  if (!violations.empty()) {
    throw ValidationError(std::move(violations));
  }

  return request;
}

}  // namespace oep::acquisition::metadata
