#include "oep/acquisition/integrity/validation.hpp"

namespace oep::acquisition::integrity {

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

CreateVerificationRequest parse_and_validate_create(const nlohmann::json& body) {
  std::vector<std::string> violations;
  CreateVerificationRequest request;

  request.download_session_id = get_string(body, "download_session_id");
  if (request.download_session_id.empty()) {
    violations.emplace_back("Download Session ID is required.");
  }

  if (!violations.empty()) {
    throw ValidationError(std::move(violations));
  }

  return request;
}

}  // namespace oep::acquisition::integrity
