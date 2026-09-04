#pragma once

#include <nlohmann/json.hpp>
#include <stdexcept>
#include <string>
#include <vector>

namespace oep::acquisition::downloads {

/// Thrown when input fails WORK_PACKAGE-006's "Validation Rules". Carries
/// every violation found (not just the first) so a REST `422` response
/// can report all of them at once.
class ValidationError : public std::runtime_error {
 public:
  explicit ValidationError(std::vector<std::string> violations);

  [[nodiscard]] const std::vector<std::string>& violations() const;

 private:
  std::vector<std::string> violations_;
};

/// The (already-validated) fields a `POST /downloads` request body
/// supplies. Everything else in the Download Model (`local_storage_path`,
/// `file_name` if not client-supplied, `mime_type`, `file_size_bytes`,
/// `status`, `progress_percentage`, timestamps) is computed by
/// `DownloadService`, not accepted from the client.
struct StartDownloadRequest {
  std::string job_id;
  std::string connector_id;
  std::string source_uri;
  // Empty means DownloadService derives one from source_uri.
  std::string file_name;
};

/// Parses and validates a `POST /downloads` request body. Throws
/// ValidationError if `job_id`, `connector_id`, or `source_uri` are
/// missing.
[[nodiscard]] StartDownloadRequest parse_and_validate_start(const nlohmann::json& body);

}  // namespace oep::acquisition::downloads
