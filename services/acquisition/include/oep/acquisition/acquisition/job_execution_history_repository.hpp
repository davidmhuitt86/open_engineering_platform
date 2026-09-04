#pragma once

#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_execution.hpp"
#include "oep/acquisition/acquisition/acquisition_job.hpp"

namespace oep::acquisition::acquisition {

/// Abstracts persistence for `JobExecutionHistoryEntry` so
/// `AcquisitionExecutionService` can be unit-tested against a fake without
/// a live PostgreSQL instance, mirroring `IAcquisitionJobRepository`.
class IJobExecutionHistoryRepository {
 public:
  virtual ~IJobExecutionHistoryRepository() = default;

  /// Appends one transition record for `job_id`. Never fails for a
  /// nonexistent `job_id` from the caller's perspective -- callers only
  /// invoke this after already confirming the job exists.
  virtual void record(const std::string& job_id, JobStatus from, JobStatus to, const std::string& message) = 0;

  /// Ordered oldest first. Empty if `job_id` has no recorded history.
  virtual std::vector<JobExecutionHistoryEntry> list_for_job(const std::string& job_id) = 0;
};

}  // namespace oep::acquisition::acquisition
