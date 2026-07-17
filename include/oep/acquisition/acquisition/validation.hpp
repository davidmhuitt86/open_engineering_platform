#pragma once

#include <nlohmann/json.hpp>
#include <stdexcept>
#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_job.hpp"

namespace oep::acquisition::acquisition {

/// Thrown when input fails WORK_PACKAGE-003's "Validation Rules". Carries
/// every violation found (not just the first) so a REST 422 response can
/// report all of them at once.
class ValidationError : public std::runtime_error {
 public:
  explicit ValidationError(std::vector<std::string> violations);

  [[nodiscard]] const std::vector<std::string>& violations() const;

 private:
  std::vector<std::string> violations_;
};

/// Parses and validates a POST /jobs request body. Throws ValidationError
/// if Name, Source ID, or Priority are missing or malformed. `status` is
/// never accepted from the client -- WORK_PACKAGE-003: "Jobs shall remain
/// in the Created state unless explicitly changed through the API" (that
/// explicit change is a subsequent PUT, not the initial POST) -- and
/// `started_at`/`completed_at`/`error_message` are always null on create
/// (a job cannot have already started before it exists).
[[nodiscard]] AcquisitionJob parse_and_validate_create(const nlohmann::json& body);

/// Parses and validates a PUT /jobs/{id} request body against the
/// currently stored `existing` record. Throws ValidationError if Name,
/// Source ID, Status, or Priority are missing/malformed, or if the body
/// attempts to change the immutable `id` or `created_at` fields.
[[nodiscard]] AcquisitionJob parse_and_validate_update(const nlohmann::json& body, const AcquisitionJob& existing);

}  // namespace oep::acquisition::acquisition
