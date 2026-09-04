#include <catch2/catch_test_macros.hpp>

#include "execution_test_support.hpp"
#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/acquisition/postgres_job_execution_history_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::acquisition;
using oep::acquisition::test_support::reset_execution_schema;
using oep::acquisition::test_support::seed_official_source;
using oep::acquisition::test_support::test_database_config;

TEST_CASE("PostgresJobExecutionHistoryRepository records and lists transitions against a real database",
          "[execution][database]") {
  const auto schema_error = reset_execution_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string source_id = seed_official_source();
  PostgresAcquisitionJobRepository jobs(test_database_config());
  AcquisitionJob job;
  job.source_id = source_id;
  job.name = "Acquire 802.11";
  job.priority = JobPriority::Normal;
  job.status = JobStatus::Created;
  const auto created = jobs.create(job);

  PostgresJobExecutionHistoryRepository history(test_database_config());

  SECTION("list_for_job is empty before any transition is recorded") {
    CHECK(history.list_for_job(created.id).empty());
  }

  SECTION("record appends entries in occurred_at order") {
    history.record(created.id, JobStatus::Created, JobStatus::Queued, "");
    history.record(created.id, JobStatus::Queued, JobStatus::Running, "starting");

    const auto entries = history.list_for_job(created.id);
    REQUIRE(entries.size() == 2);
    CHECK(entries[0].from_status == "created");
    CHECK(entries[0].to_status == "queued");
    CHECK(entries[1].from_status == "queued");
    CHECK(entries[1].to_status == "running");
    CHECK(entries[1].message == "starting");
    CHECK_FALSE(entries[0].occurred_at.empty());
  }

  SECTION("list_for_job only returns entries for the requested job") {
    auto second_job = job;
    second_job.name = "Second Job";
    const auto second_created = jobs.create(second_job);

    history.record(created.id, JobStatus::Created, JobStatus::Queued, "");
    history.record(second_created.id, JobStatus::Created, JobStatus::Queued, "");

    CHECK(history.list_for_job(created.id).size() == 1);
    CHECK(history.list_for_job(second_created.id).size() == 1);
  }
}
