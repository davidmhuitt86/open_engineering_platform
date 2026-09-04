#include "oep/acquisition/acquisition/acquisition_execution.hpp"

namespace oep::acquisition::acquisition {

std::optional<JobStatus> next_execution_status(JobStatus current) {
  switch (current) {
    case JobStatus::Created:
      return JobStatus::Queued;
    case JobStatus::Queued:
      return JobStatus::Running;
    case JobStatus::Running:
      return JobStatus::Completed;
    case JobStatus::Completed:
    case JobStatus::Failed:
    case JobStatus::Cancelled:
      return std::nullopt;
  }
  return std::nullopt;
}

bool can_cancel(JobStatus current) {
  return current == JobStatus::Queued || current == JobStatus::Running;
}

}  // namespace oep::acquisition::acquisition
