#include <catch2/catch_test_macros.hpp>

#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::acquisition;
using oep::acquisition::test_support::reset_acquisition_jobs_schema;
using oep::acquisition::test_support::seed_official_source;
using oep::acquisition::test_support::test_database_config;

namespace {

AcquisitionJob make_job(const std::string& source_id) {
  AcquisitionJob job;
  job.source_id = source_id;
  job.name = "Acquire IEEE Standard 802.11";
  job.description = "Pull the latest revision.";
  job.status = JobStatus::Created;
  job.priority = JobPriority::Normal;
  job.requested_by = "jdoe";
  return job;
}

}  // namespace

TEST_CASE("PostgresAcquisitionJobRepository performs CRUD against a real database", "[jobs][database]") {
  const auto schema_error = reset_acquisition_jobs_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const std::string source_id = seed_official_source();
  PostgresAcquisitionJobRepository repository(test_database_config());

  SECTION("create assigns id and timestamps, defaults nullable fields to unset") {
    const auto created = repository.create(make_job(source_id));
    CHECK_FALSE(created.id.empty());
    CHECK_FALSE(created.created_at.empty());
    CHECK(created.updated_at == created.created_at);
    CHECK(created.source_id == source_id);
    CHECK_FALSE(created.started_at.has_value());
    CHECK_FALSE(created.completed_at.has_value());
    CHECK_FALSE(created.error_message.has_value());
  }

  SECTION("create throws UnknownSourceError for a source_id that does not exist") {
    auto job = make_job("00000000-0000-0000-0000-000000000000");
    CHECK_THROWS_AS(repository.create(job), UnknownSourceError);
  }

  SECTION("find_by_id returns the created job") {
    const auto created = repository.create(make_job(source_id));
    const auto found = repository.find_by_id(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
    CHECK(found->name == "Acquire IEEE Standard 802.11");
  }

  SECTION("find_by_id returns nullopt for an unknown id") {
    CHECK_FALSE(repository.find_by_id("00000000-0000-0000-0000-000000000000").has_value());
  }

  SECTION("list returns every non-deleted job") {
    repository.create(make_job(source_id));
    auto second = make_job(source_id);
    second.name = "Second Job";
    repository.create(second);

    CHECK(repository.list(JobFilter{}).size() == 2);
  }

  SECTION("list filters by status and priority") {
    auto queued = make_job(source_id);
    queued.status = JobStatus::Queued;
    repository.create(queued);

    auto urgent = make_job(source_id);
    urgent.priority = JobPriority::Urgent;
    repository.create(urgent);

    JobFilter status_filter;
    status_filter.status = JobStatus::Queued;
    CHECK(repository.list(status_filter).size() == 1);

    JobFilter priority_filter;
    priority_filter.priority = JobPriority::Urgent;
    CHECK(repository.list(priority_filter).size() == 1);
  }

  SECTION("update changes fields, sets started_at, preserves id and created_at") {
    const auto created = repository.create(make_job(source_id));

    auto changed = created;
    changed.status = JobStatus::Running;
    changed.started_at = "2026-01-01T00:00:00Z";

    const auto updated = repository.update(created.id, changed);
    REQUIRE(updated.has_value());
    CHECK(updated->id == created.id);
    CHECK(updated->created_at == created.created_at);
    CHECK(updated->status == JobStatus::Running);
    REQUIRE(updated->started_at.has_value());
    CHECK(*updated->started_at == "2026-01-01T00:00:00Z");
  }

  SECTION("update throws UnknownSourceError when source_id is changed to a nonexistent source") {
    const auto created = repository.create(make_job(source_id));
    auto changed = created;
    changed.source_id = "00000000-0000-0000-0000-000000000000";

    CHECK_THROWS_AS(repository.update(created.id, changed), UnknownSourceError);
  }

  SECTION("update returns nullopt for an unknown id") {
    CHECK_FALSE(repository.update("00000000-0000-0000-0000-000000000000", make_job(source_id)).has_value());
  }

  SECTION("soft_delete hides the job from find_by_id and list") {
    const auto created = repository.create(make_job(source_id));
    CHECK(repository.soft_delete(created.id));
    CHECK_FALSE(repository.find_by_id(created.id).has_value());
    CHECK(repository.list(JobFilter{}).empty());
  }

  SECTION("soft_delete is not repeatable") {
    const auto created = repository.create(make_job(source_id));
    CHECK(repository.soft_delete(created.id));
    CHECK_FALSE(repository.soft_delete(created.id));
  }
}
