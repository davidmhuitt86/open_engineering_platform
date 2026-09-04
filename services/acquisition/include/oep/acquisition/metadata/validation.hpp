#pragma once

#include <nlohmann/json.hpp>
#include <stdexcept>
#include <string>
#include <vector>

namespace oep::acquisition::metadata {

/// Thrown when input fails WORK_PACKAGE-008's "Validation Rules". Carries
/// every violation found (not just the first) so a REST `422` response
/// can report all of them at once.
class ValidationError : public std::runtime_error {
 public:
  explicit ValidationError(std::vector<std::string> violations);

  [[nodiscard]] const std::vector<std::string>& violations() const;

 private:
  std::vector<std::string> violations_;
};

/// The (already-validated) fields a `POST /metadata` request body
/// supplies. Everything else in the Metadata Model (`file_name`,
/// `file_extension`, `mime_type`, `file_size_bytes`, `sha256_hash`,
/// timestamps, `status`, `error_message`) is computed by
/// `MetadataExtractionService`, not accepted from the client.
struct CreateMetadataRequest {
  std::string verification_id;
};

/// Parses and validates a `POST /metadata` request body. Throws
/// ValidationError if `verification_id` is missing.
[[nodiscard]] CreateMetadataRequest parse_and_validate_create(const nlohmann::json& body);

}  // namespace oep::acquisition::metadata
