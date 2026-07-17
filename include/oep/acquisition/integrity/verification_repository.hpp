#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/integrity/verification.hpp"

namespace oep::acquisition::integrity {

/// Optional filters for `GET /verifications`. Every field is optional;
/// unset fields impose no constraint.
struct VerificationFilter {
  std::optional<VerificationStatus> status;
  std::optional<std::string> download_session_id;
};

/// Abstracts persistence for `Verification` so `IntegrityVerificationService`
/// can be unit-tested against a fake without a live PostgreSQL instance,
/// mirroring `downloads::IDownloadRepository`.
class IVerificationRepository {
 public:
  virtual ~IVerificationRepository() = default;

  /// Inserts `verification` and returns the stored row (`id`/`created_at`/
  /// `updated_at` populated by the database). Throws
  /// UnknownDownloadSessionError if `verification.download_session_id`
  /// does not reference an existing Download Session.
  virtual Verification create(const Verification& verification) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<Verification> find_by_id(const std::string& id) = 0;

  virtual std::vector<Verification> list(const VerificationFilter& filter) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<Verification> update(const std::string& id, const Verification& verification) = 0;
};

}  // namespace oep::acquisition::integrity
