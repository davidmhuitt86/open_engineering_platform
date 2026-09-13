#pragma once

#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "oep/acquisition/provenance/acquisition_record.hpp"

namespace oep::acquisition::provenance {

/// Optional filters for `GET /acquisition-records`. Every field is
/// optional; unset fields impose no constraint.
struct AcquisitionRecordFilter {
  std::optional<AcquisitionRecordStatus> status;
};

/// Thrown by `create` if `download_session_id` does not reference an
/// existing Download Session, or already has an Acquisition Record --
/// defense in depth via the database's own foreign key/unique constraint;
/// `AcquisitionRecordService` already validates both before calling
/// `create`, mirroring `vault::UnknownMetadataError`/`AlreadyPublishedError`.
class UnknownDownloadSessionError : public std::runtime_error {
 public:
  explicit UnknownDownloadSessionError(const std::string& download_session_id)
      : std::runtime_error("download_session_id does not reference an existing Download Session: " +
                            download_session_id) {}
};

class DuplicateAcquisitionRecordError : public std::runtime_error {
 public:
  explicit DuplicateAcquisitionRecordError(const std::string& download_session_id)
      : std::runtime_error("An Acquisition Record already exists for download_session_id: " +
                            download_session_id) {}
};

/// Abstracts persistence for `AcquisitionRecord` so `AcquisitionRecordService`
/// can be unit-tested against a fake without a live PostgreSQL instance,
/// mirroring `vault::IVaultRepository`.
class IAcquisitionRecordRepository {
 public:
  virtual ~IAcquisitionRecordRepository() = default;

  /// Inserts `record` (in its initial state, set by the caller) and returns
  /// the stored row (`id`/`created_at`/`updated_at` populated by the
  /// database). Throws UnknownDownloadSessionError if
  /// `record.download_session_id` does not reference an existing Download
  /// Session. Throws DuplicateAcquisitionRecordError if one already exists
  /// for that `download_session_id`.
  virtual AcquisitionRecord create(const AcquisitionRecord& record) = 0;

  /// Empty optional if `id` does not exist.
  virtual std::optional<AcquisitionRecord> find_by_id(const std::string& id) = 0;

  /// Empty optional if no Acquisition Record exists for `download_session_id`
  /// -- true for every Download Session created before WP-018, and never
  /// true for one created afterward (see `AcquisitionRecordService`).
  virtual std::optional<AcquisitionRecord> find_by_download_session_id(
      const std::string& download_session_id) = 0;

  virtual std::vector<AcquisitionRecord> list(const AcquisitionRecordFilter& filter) = 0;

  /// Updates only `status`/`error_message`/`updated_at` on an existing row
  /// -- the one deliberately-mutable summary field pair (see
  /// `AcquisitionRecord`'s own header comment on immutability). Empty
  /// optional if `id` does not exist. There is deliberately no general
  /// `update` that can rewrite `download_session_id` or `created_at` --
  /// no code path anywhere in this module can alter a record's identity
  /// once created.
  virtual std::optional<AcquisitionRecord> update_status(const std::string& id, AcquisitionRecordStatus status,
                                                          const std::optional<std::string>& error_message) = 0;
};

}  // namespace oep::acquisition::provenance
