#include "oep/acquisition/acquisition/validation.hpp"

namespace oep::acquisition::acquisition {

namespace {

std::string get_string(const nlohmann::json& body, const char* key) {
  if (body.contains(key) && body.at(key).is_string()) {
    return body.at(key).get<std::string>();
  }
  return {};
}

std::optional<std::string> get_optional_string(const nlohmann::json& body, const char* key) {
  if (!body.contains(key) || body.at(key).is_null()) {
    return std::nullopt;
  }
  if (body.at(key).is_string()) {
    return body.at(key).get<std::string>();
  }
  return std::nullopt;
}

/// Validates the fields WORK_PACKAGE-003 requires regardless of whether
/// this is a create or an update (Name, Source ID, Priority), appending
/// any violation found to `violations`.
void validate_name_source_priority(const nlohmann::json& body, std::vector<std::string>& violations,
                                    AcquisitionJob& out) {
  out.name = get_string(body, "name");
  if (out.name.empty()) {
    violations.emplace_back("Name is required.");
  }

  out.source_id = get_string(body, "source_id");
  if (out.source_id.empty()) {
    violations.emplace_back("Source ID is required.");
  }

  if (!body.contains("priority") || !body.at("priority").is_number_integer()) {
    violations.emplace_back("Priority is required.");
  } else if (const auto priority = job_priority_from_int(body.at("priority").get<int>()); priority.has_value()) {
    out.priority = *priority;
  } else {
    violations.emplace_back("Priority must be an integer between 0 and 3.");
  }

  out.description = get_string(body, "description");
  out.requested_by = get_string(body, "requested_by");
}

}  // namespace

ValidationError::ValidationError(std::vector<std::string> violations)
    : std::runtime_error("Validation failed"), violations_(std::move(violations)) {}

const std::vector<std::string>& ValidationError::violations() const {
  return violations_;
}

AcquisitionJob parse_and_validate_create(const nlohmann::json& body) {
  std::vector<std::string> violations;
  AcquisitionJob job;
  validate_name_source_priority(body, violations, job);

  if (!violations.empty()) {
    throw ValidationError(std::move(violations));
  }

  // Assigned by the repository on INSERT.
  job.id.clear();
  job.created_at.clear();
  job.updated_at.clear();
  // Never client-settable on create -- see header comment.
  job.status = JobStatus::Created;
  job.started_at.reset();
  job.completed_at.reset();
  job.error_message.reset();
  return job;
}

AcquisitionJob parse_and_validate_update(const nlohmann::json& body, const AcquisitionJob& existing) {
  std::vector<std::string> violations;
  AcquisitionJob job;
  validate_name_source_priority(body, violations, job);

  if (!body.contains("status") || !body.at("status").is_string()) {
    violations.emplace_back("Status is required.");
  } else if (const auto status = job_status_from_string(body.at("status").get<std::string>());
             status.has_value()) {
    job.status = *status;
  } else {
    violations.emplace_back("Status must be one of: created, queued, running, completed, failed, cancelled.");
  }

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

  job.id = existing.id;
  job.created_at = existing.created_at;
  job.updated_at.clear();  // Assigned by the repository on UPDATE.
  job.started_at = get_optional_string(body, "started_at");
  job.completed_at = get_optional_string(body, "completed_at");
  job.error_message = get_optional_string(body, "error_message");
  return job;
}

}  // namespace oep::acquisition::acquisition
