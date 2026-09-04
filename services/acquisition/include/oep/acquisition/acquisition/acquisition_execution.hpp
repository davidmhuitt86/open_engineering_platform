#pragma once

#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include "oep/acquisition/acquisition/acquisition_job.hpp"

namespace oep::acquisition::acquisition {

/// One recorded state transition (WORK_PACKAGE-004: "Execution history
/// shall be recorded"). Append-only -- never modified or deleted, mirroring
/// Engineering Principle 8 (Engineering Evidence Is Immutable).
struct JobExecutionHistoryEntry {
  std::string from_status;
  std::string to_status;
  std::string occurred_at;
  std::string message;
};

/// `GET /jobs/{id}/status` response payload: the job's current state plus
/// its full transition history.
struct ExecutionStatus {
  AcquisitionJob job;
  std::vector<JobExecutionHistoryEntry> history;
};

/// Thrown by `execute`/`cancel` when the job's current status has no valid
/// transition for the requested action (WORK_PACKAGE-004: "Invalid
/// transitions shall be rejected").
class InvalidTransitionError : public std::runtime_error {
 public:
  InvalidTransitionError(const std::string& current_status, const std::string& action)
      : std::runtime_error("Cannot " + action + " a job in status '" + current_status + "'.") {}
};

/// Thrown by `execute` when the job's Official Source is archived or no
/// longer available (soft-deleted) -- WORK_PACKAGE-004: "Attempting to
/// execute an archived source shall fail."
class SourceNotAvailableError : public std::runtime_error {
 public:
  explicit SourceNotAvailableError(const std::string& source_id)
      : std::runtime_error("Source is not available for execution: " + source_id) {}
};

/// The single valid forward-execution step from `current`, or nullopt if
/// `current` is a terminal state (Completed, Failed, Cancelled) with no
/// forward-execution edge. WORK_PACKAGE-004's state diagram lists exactly
/// three forward-execution edges (Created->Queued, Queued->Running,
/// Running->Completed); `execute()` advances a job by one such edge per
/// call -- see README.md "Implementation Decisions" for why a single
/// generic action was chosen over one endpoint per edge.
[[nodiscard]] std::optional<JobStatus> next_execution_status(JobStatus current);

/// True if `current` has a valid transition to Cancelled (Queued or
/// Running, per WORK_PACKAGE-004's state diagram).
[[nodiscard]] bool can_cancel(JobStatus current);

}  // namespace oep::acquisition::acquisition
