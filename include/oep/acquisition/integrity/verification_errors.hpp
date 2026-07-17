#pragma once

#include <stdexcept>
#include <string>

namespace oep::acquisition::integrity {

/// Thrown by `IntegrityVerificationService::verify` when `download_session_id`
/// does not reference an existing Download Session (WORK_PACKAGE-007
/// Validation Rules: "Download session shall exist"). Distinct from the
/// remaining Validation Rules ("Downloaded artifact shall exist", "Artifact
/// shall not be empty", "Missing files shall fail verification", "Corrupt
/// files shall fail verification"), which do NOT throw -- those describe
/// properties of the artifact a download session already points to, and are
/// recorded as a Failed Verification outcome instead, mirroring how
/// `downloads::DownloadService` records a connector fetch failure as a
/// terminal Download state rather than throwing. See README.md
/// "Implementation Decisions".
class UnknownDownloadSessionError : public std::runtime_error {
 public:
  explicit UnknownDownloadSessionError(const std::string& download_session_id)
      : std::runtime_error("download_session_id does not reference an existing Download Session: " +
                            download_session_id) {}
};

}  // namespace oep::acquisition::integrity
