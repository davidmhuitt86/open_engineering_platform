#include "oep/acquisition/acquisition/acquisition_execution_service.hpp"

#include <chrono>
#include <ctime>

namespace oep::acquisition::acquisition {

namespace {

// Matches the "YYYY-MM-DDTHH:MM:SSZ" format the Repository layer's SQL
// `to_char(... , 'YYYY-MM-DD"T"HH24:MI:SS"Z"')` produces (see
// PostgresAcquisitionJobRepository), so a job updated by the Execution
// Engine looks identical to one updated via a client-supplied timestamp
// through PUT /jobs/{id}.
std::string current_timestamp_utc() {
  const std::time_t now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
  std::tm utc_tm{};
#ifdef _WIN32
  gmtime_s(&utc_tm, &now);
#else
  gmtime_r(&now, &utc_tm);
#endif
  char buffer[32];
  std::strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &utc_tm);
  return buffer;
}

}  // namespace

AcquisitionExecutionService::AcquisitionExecutionService(IAcquisitionJobRepository& jobs,
                                                             registry::IOfficialSourceRepository& sources,
                                                             IJobExecutionHistoryRepository& history)
    : jobs_(jobs), sources_(sources), history_(history) {}

std::optional<AcquisitionJob> AcquisitionExecutionService::execute(const std::string& job_id) {
  const auto job = jobs_.find_by_id(job_id);
  if (!job.has_value()) {
    return std::nullopt;
  }

  const auto source = sources_.find_by_id(job->source_id);
  if (!source.has_value() || source->status == registry::SourceStatus::Archived) {
    throw SourceNotAvailableError(job->source_id);
  }

  const auto next = next_execution_status(job->status);
  if (!next.has_value()) {
    throw InvalidTransitionError(to_string(job->status), "execute");
  }

  AcquisitionJob updated = *job;
  updated.status = *next;
  if (*next == JobStatus::Running) {
    updated.started_at = current_timestamp_utc();
  } else if (*next == JobStatus::Completed) {
    updated.completed_at = current_timestamp_utc();
  }

  const auto result = jobs_.update(job_id, updated);
  history_.record(job_id, job->status, *next, "");
  return result;
}

std::optional<AcquisitionJob> AcquisitionExecutionService::cancel(const std::string& job_id) {
  const auto job = jobs_.find_by_id(job_id);
  if (!job.has_value()) {
    return std::nullopt;
  }

  if (!can_cancel(job->status)) {
    throw InvalidTransitionError(to_string(job->status), "cancel");
  }

  AcquisitionJob updated = *job;
  updated.status = JobStatus::Cancelled;
  updated.completed_at = current_timestamp_utc();

  const auto result = jobs_.update(job_id, updated);
  history_.record(job_id, job->status, JobStatus::Cancelled, "");
  return result;
}

std::optional<ExecutionStatus> AcquisitionExecutionService::get_status(const std::string& job_id) {
  const auto job = jobs_.find_by_id(job_id);
  if (!job.has_value()) {
    return std::nullopt;
  }
  return ExecutionStatus{*job, history_.list_for_job(job_id)};
}

}  // namespace oep::acquisition::acquisition
