#pragma once

#include <nlohmann/json.hpp>
#include <stdexcept>
#include <string>
#include <vector>

namespace oep::acquisition::vault {

/// Thrown when input fails WORK_PACKAGE-009's "Validation Rules". Carries
/// every violation found (not just the first) so a REST `422` response
/// can report all of them at once.
class ValidationError : public std::runtime_error {
 public:
  explicit ValidationError(std::vector<std::string> violations);

  [[nodiscard]] const std::vector<std::string>& violations() const;

 private:
  std::vector<std::string> violations_;
};

/// The (already-validated) fields a `POST /vault` request body supplies.
/// Everything else in the Vault Model (`verification_id`,
/// `download_session_id`, `source_id`, `vault_path`, `sha256_hash`,
/// `mime_type`, `file_size_bytes`, `status`, `published_at`) is derived by
/// `ReferenceVaultService` from the referenced Metadata/Verification/
/// Download chain, not accepted from the client.
struct PublishArtifactRequest {
  std::string metadata_id;
};

/// Parses and validates a `POST /vault` request body. Throws
/// ValidationError if `metadata_id` is missing.
[[nodiscard]] PublishArtifactRequest parse_and_validate_publish(const nlohmann::json& body);

}  // namespace oep::acquisition::vault
