#pragma once

#include <nlohmann/json.hpp>
#include <stdexcept>
#include <string>
#include <vector>

#include "oep/acquisition/registry/official_source.hpp"

namespace oep::acquisition::registry {

/// Thrown when input fails WORK-PACKAGE-002's "Validation Rules". Carries
/// every violation found (not just the first) so a REST 422 response can
/// report all of them at once.
class ValidationError : public std::runtime_error {
 public:
  explicit ValidationError(std::vector<std::string> violations);

  [[nodiscard]] const std::vector<std::string>& violations() const;

 private:
  std::vector<std::string> violations_;
};

/// Parses and validates a POST /sources request body. Throws ValidationError
/// if Name, Base URL, Trust Level, or Status are missing or malformed.
/// `id`/`created_at`/`updated_at` in the request body are ignored -- the
/// repository assigns them on creation.
[[nodiscard]] OfficialSource parse_and_validate_create(const nlohmann::json& body);

/// Parses and validates a PUT /sources/{id} request body against the
/// currently stored `existing` record. Throws ValidationError if Name, Base
/// URL, Trust Level, or Status are missing/malformed, or if the body
/// attempts to change the immutable `id` or `created_at` fields.
[[nodiscard]] OfficialSource parse_and_validate_update(const nlohmann::json& body, const OfficialSource& existing);

}  // namespace oep::acquisition::registry
