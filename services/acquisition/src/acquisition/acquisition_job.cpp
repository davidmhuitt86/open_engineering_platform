#include "oep/acquisition/acquisition/acquisition_job.hpp"

namespace oep::acquisition::acquisition {

std::string to_string(JobStatus status) {
  switch (status) {
    case JobStatus::Created:
      return "created";
    case JobStatus::Queued:
      return "queued";
    case JobStatus::Running:
      return "running";
    case JobStatus::Completed:
      return "completed";
    case JobStatus::Failed:
      return "failed";
    case JobStatus::Cancelled:
      return "cancelled";
  }
  return "created";
}

std::optional<JobStatus> job_status_from_string(const std::string& text) {
  if (text == "created") return JobStatus::Created;
  if (text == "queued") return JobStatus::Queued;
  if (text == "running") return JobStatus::Running;
  if (text == "completed") return JobStatus::Completed;
  if (text == "failed") return JobStatus::Failed;
  if (text == "cancelled") return JobStatus::Cancelled;
  return std::nullopt;
}

std::string to_string(JobPriority priority) {
  switch (priority) {
    case JobPriority::Low:
      return "low";
    case JobPriority::Normal:
      return "normal";
    case JobPriority::High:
      return "high";
    case JobPriority::Urgent:
      return "urgent";
  }
  return "normal";
}

std::optional<JobPriority> job_priority_from_int(int value) {
  if (value < 0 || value > 3) {
    return std::nullopt;
  }
  return static_cast<JobPriority>(value);
}

}  // namespace oep::acquisition::acquisition
