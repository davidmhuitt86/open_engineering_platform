#include "oep/acquisition/downloads/validation.hpp"

namespace oep::acquisition::downloads {

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

StartDownloadRequest parse_and_validate_start(const nlohmann::json& body) {
  std::vector<std::string> violations;
  StartDownloadRequest request;

  request.job_id = get_string(body, "job_id");
  if (request.job_id.empty()) {
    violations.emplace_back("Job ID is required.");
  }

  request.connector_id = get_string(body, "connector_id");
  if (request.connector_id.empty()) {
    violations.emplace_back("Connector ID is required.");
  }

  request.source_uri = get_string(body, "source_uri");
  if (request.source_uri.empty()) {
    violations.emplace_back("Source URI is required.");
  }

  request.file_name = get_string(body, "file_name");

  if (!violations.empty()) {
    throw ValidationError(std::move(violations));
  }

  return request;
}

}  // namespace oep::acquisition::downloads
