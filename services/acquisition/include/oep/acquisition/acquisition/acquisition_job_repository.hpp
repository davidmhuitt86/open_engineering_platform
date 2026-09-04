#pragma once

#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_job.hpp"

namespace oep::acquisition::acquisition {

/// Optional filters for "List Jobs" / "Filter Jobs" (WORK_PACKAGE-003
/// Functional Requirements). Every field is optional; unset fields impose
/// no constraint. Soft-deleted jobs are always excluded.
struct JobFilter {
  std::optional<JobStatus> status;
  std::optional<JobPriority> priority;
  std::optional<std::string> source_id;
  std::optional<std::string> requested_by;
};

/// Thrown by `create`/`update` when `source_id` does not reference an
/// existing Official Source. Lets callers (the REST layer) handle this
/// as a domain-specific error without knowing the repository is backed by
/// PostgreSQL foreign keys (see migrations/V3__acquisition_jobs.sql).
class UnknownSourceError : public std::runtime_error {
 public:
  explicit UnknownSourceError(const std::string& source_id)
      : std::runtime_error("source_id does not reference an existing Official Source: " + source_id) {}
};

/// Abstracts persistence for AcquisitionJob so the Service layer can be
/// unit-tested against a fake without a live PostgreSQL instance, mirroring
/// `registry::IOfficialSourceRepository`.
class IAcquisitionJobRepository {
 public:
  virtual ~IAcquisitionJobRepository() = default;

  /// Inserts `job` and returns the stored row (`id`/`created_at`/
  /// `updated_at` populated by the database). Throws UnknownSourceError if
  /// `job.source_id` does not reference an existing Official Source.
  virtual AcquisitionJob create(const AcquisitionJob& job) = 0;

  /// Empty optional if `id` does not exist or is soft-deleted.
  virtual std::optional<AcquisitionJob> find_by_id(const std::string& id) = 0;

  /// Soft-deleted jobs are always excluded.
  virtual std::vector<AcquisitionJob> list(const JobFilter& filter) = 0;

  /// Empty optional if `id` does not exist or is soft-deleted. Throws
  /// UnknownSourceError if `job.source_id` does not reference an existing
  /// Official Source.
  virtual std::optional<AcquisitionJob> update(const std::string& id, const AcquisitionJob& job) = 0;

  /// Sets `deleted_at`. Returns false if `id` does not exist or is already
  /// soft-deleted. Historical rows are never hard-deleted (WORK_PACKAGE-003:
  /// "Soft deletes only").
  virtual bool soft_delete(const std::string& id) = 0;
};

}  // namespace oep::acquisition::acquisition
