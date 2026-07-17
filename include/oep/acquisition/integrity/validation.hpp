#pragma once

#include <nlohmann/json.hpp>
#include <stdexcept>
#include <string>
#include <vector>

namespace oep::acquisition::integrity {

/// Thrown when input fails WORK_PACKAGE-007's "Validation Rules". Carries
/// every violation found (not just the first) so a REST `422` response can
/// report all of them at once.
class ValidationError : public std::runtime_error {
 public:
  explicit ValidationError(std::vector<std::string> violations);

  [[nodiscard]] const std::vector<std::string>& violations() const;

 private:
  std::vector<std::string> violations_;
};

/// The (already-validated) fields a `POST /verifications` request body
/// supplies. Everything else in the Verification Model (`status`,
/// `sha256_hash`, `file_size_bytes`, `verified_at`, `error_message`) is
/// computed by `IntegrityVerificationService`, not accepted from the
/// client.
struct CreateVerificationRequest {
  std::string download_session_id;
};

/// Parses and validates a `POST /verifications` request body. Throws
/// ValidationError if `download_session_id` is missing.
[[nodiscard]] CreateVerificationRequest parse_and_validate_create(const nlohmann::json& body);

}  // namespace oep::acquisition::integrity
