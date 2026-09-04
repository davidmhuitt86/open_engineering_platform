#pragma once

#include <optional>
#include <string>

namespace oep::acquisition::acquisition {

/// WORK_PACKAGE-003 "Job States" lifecycle. No automatic transitions are
/// implemented -- a Job stays in whatever state it was last explicitly set
/// to via the REST API.
enum class JobStatus {
  Created,
  Queued,
  Running,
  Completed,
  Failed,
  Cancelled,
};

/// WORK_PACKAGE-003 lists "Priority" as a required field but does not
/// enumerate its values (unlike Job States, which has a named list). A
/// small ordered scale is used here -- consistent with WORK-PACKAGE-002's
/// numeric Trust Level -- rather than an unconstrained integer, so
/// "Priority required" has a concrete, validated meaning. Documented as an
/// assumption in README.md "Implementation Decisions".
enum class JobPriority {
  Low = 0,
  Normal = 1,
  High = 2,
  Urgent = 3,
};

[[nodiscard]] std::string to_string(JobStatus status);
[[nodiscard]] std::optional<JobStatus> job_status_from_string(const std::string& text);

[[nodiscard]] std::string to_string(JobPriority priority);
[[nodiscard]] std::optional<JobPriority> job_priority_from_int(int value);

/// The Engineering Acquisition Job Engine's domain entity
/// (WORK_PACKAGE-003). `id` is the externally-visible UUID (the REST
/// API's `/jobs/{id}` path segment and the JSON body's "id" field) --
/// distinct from the database's internal surrogate primary key, mirroring
/// `registry::OfficialSource`.
///
/// `source_id` references an `OfficialSource`'s `id`
/// (WORK-PACKAGE-002) -- enforced at the database level by a foreign key
/// (see migrations/V3__acquisition_jobs.sql), not re-validated here.
///
/// `started_at`, `completed_at`, and `error_message` are nullable per
/// WORK_PACKAGE-003's Job Model; empty means "not set" (no value has ever
/// been recorded), distinct from an empty string being a meaningful value.
struct AcquisitionJob {
  std::string id;
  std::string source_id;
  std::string name;
  std::string description;
  JobStatus status = JobStatus::Created;
  JobPriority priority = JobPriority::Normal;
  std::string requested_by;
  std::string created_at;
  std::string updated_at;
  std::optional<std::string> started_at;
  std::optional<std::string> completed_at;
  std::optional<std::string> error_message;
};

}  // namespace oep::acquisition::acquisition
