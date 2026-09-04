#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/downloads/download_repository.hpp"
#include "oep/acquisition/integrity/verification_repository.hpp"

namespace oep::acquisition::integrity {

/// Orchestrates WORK_PACKAGE-007's Integrity Verification Engine: resolves
/// a `download_session_id` against the Engineering Downloader, hashes the
/// artifact it points to, and records the outcome as a Verification --
/// entirely synchronously, within the call to `verify` (mirroring
/// `downloads::DownloadService::start_download`; see README.md
/// "Implementation Decisions" for why no background thread is used).
///
/// Depends on `IVerificationRepository` and `downloads::IDownloadRepository`
/// (interfaces, not concrete Postgres classes) so it can be unit-tested
/// against fakes without a live database, mirroring
/// `downloads::DownloadService`.
class IntegrityVerificationService {
 public:
  IntegrityVerificationService(IVerificationRepository& verifications, downloads::IDownloadRepository& downloads);

  /// Throws (WORK_PACKAGE-007 "Validation Rules", checked in this order):
  /// - ValidationError if `download_session_id` is missing.
  /// - UnknownDownloadSessionError if `download_session_id` does not
  ///   reference an existing Download Session.
  ///
  /// On success, synchronously hashes the artifact and returns the
  /// Verification in its final state (Verified or Failed) -- a missing,
  /// empty, unreadable, or hash-mismatched artifact is recorded as Failed
  /// rather than thrown, since those describe the artifact's condition,
  /// not the request's validity.
  Verification verify(const nlohmann::json& body);

  std::optional<Verification> get(const std::string& id);

  std::vector<Verification> list(const VerificationFilter& filter);

 private:
  IVerificationRepository& verifications_;
  downloads::IDownloadRepository& downloads_;
};

}  // namespace oep::acquisition::integrity
