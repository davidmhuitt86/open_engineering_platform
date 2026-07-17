#pragma once

#include <optional>
#include <string>

#include "oep/acquisition/acquisition/acquisition_execution.hpp"
#include "oep/acquisition/acquisition/acquisition_job_repository.hpp"
#include "oep/acquisition/acquisition/job_execution_history_repository.hpp"
#include "oep/acquisition/registry/official_source_repository.hpp"

namespace oep::acquisition::acquisition {

/// Manages Acquisition Jobs' runtime execution lifecycle
/// (WORK_PACKAGE-004): advancing a job through its execution states,
/// cancelling it, and reporting its execution status and history.
///
/// Depends on `IAcquisitionJobRepository`, `registry::IOfficialSourceRepository`,
/// and `IJobExecutionHistoryRepository` as interfaces (not concrete
/// PostgreSQL types) so it can be unit-tested against fakes without a live
/// database, mirroring `OfficialSourceService` and `AcquisitionJobService`.
class AcquisitionExecutionService {
 public:
  AcquisitionExecutionService(IAcquisitionJobRepository& jobs, registry::IOfficialSourceRepository& sources,
                               IJobExecutionHistoryRepository& history);

  /// Advances `job_id` by one valid execution step (see
  /// `next_execution_status`), setting `started_at`/`completed_at` as
  /// appropriate and recording the transition. Empty optional if `job_id`
  /// does not exist or is soft-deleted (WORK_PACKAGE-004: "Attempting to
  /// execute a deleted job shall fail"). Throws SourceNotAvailableError if
  /// the job's Official Source is archived or unavailable. Throws
  /// InvalidTransitionError if the job's current status has no forward
  /// execution step.
  std::optional<AcquisitionJob> execute(const std::string& job_id);

  /// Transitions `job_id` to Cancelled. Empty optional if `job_id` does
  /// not exist or is soft-deleted. Throws InvalidTransitionError if the
  /// job's current status cannot be cancelled (only Queued and Running
  /// can).
  std::optional<AcquisitionJob> cancel(const std::string& job_id);

  /// Empty optional if `job_id` does not exist or is soft-deleted.
  std::optional<ExecutionStatus> get_status(const std::string& job_id);

 private:
  IAcquisitionJobRepository& jobs_;
  registry::IOfficialSourceRepository& sources_;
  IJobExecutionHistoryRepository& history_;
};

}  // namespace oep::acquisition::acquisition
