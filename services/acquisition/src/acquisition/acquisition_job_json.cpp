#include "oep/acquisition/acquisition/acquisition_job_json.hpp"

namespace oep::acquisition::acquisition {

namespace {

nlohmann::json optional_to_json(const std::optional<std::string>& value) {
  if (!value.has_value()) {
    return nullptr;
  }
  return *value;
}

}  // namespace

nlohmann::json to_json(const AcquisitionJob& job) {
  return nlohmann::json{
      {"id", job.id},
      {"source_id", job.source_id},
      {"name", job.name},
      {"description", job.description},
      {"status", to_string(job.status)},
      {"priority", static_cast<int>(job.priority)},
      {"requested_by", job.requested_by},
      {"created_at", job.created_at},
      {"updated_at", job.updated_at},
      {"started_at", optional_to_json(job.started_at)},
      {"completed_at", optional_to_json(job.completed_at)},
      {"error_message", optional_to_json(job.error_message)},
  };
}

}  // namespace oep::acquisition::acquisition
