#pragma once

#include <stdexcept>
#include <string>

namespace oep::acquisition::metadata {

/// Thrown by `MetadataExtractionService::extract` when `verification_id`
/// does not reference an existing Verification (WORK_PACKAGE-008
/// Validation Rules: "Verification shall exist"). Mirrors
/// `integrity::UnknownDownloadSessionError` -- a property of the request
/// itself, known immediately by looking the id up, unlike "Artifact shall
/// exist" below.
class UnknownVerificationError : public std::runtime_error {
 public:
  explicit UnknownVerificationError(const std::string& verification_id)
      : std::runtime_error("verification_id does not reference an existing Verification: " + verification_id) {}
};

/// Thrown by `MetadataExtractionService::extract` when the referenced
/// Verification's status is not `Verified` (WORK_PACKAGE-008 Validation
/// Rules: "Verification shall be successful" / "Metadata extraction shall
/// operate only on successfully verified artifacts"). A state conflict on
/// an otherwise-valid reference, mirroring
/// `downloads::JobNotExecutableError` -- not recorded as a Failed
/// extraction, since it is known immediately from the Verification's own
/// status, not discovered only by trying to read the artifact (contrast
/// with "Artifact shall exist", which IS recorded as Failed -- see
/// README.md "Implementation Decisions").
class VerificationNotSuccessfulError : public std::runtime_error {
 public:
  VerificationNotSuccessfulError(const std::string& verification_id, const std::string& verification_status)
      : std::runtime_error("Verification is not successful (status '" + verification_status +
                            "'): " + verification_id) {}
};

}  // namespace oep::acquisition::metadata
