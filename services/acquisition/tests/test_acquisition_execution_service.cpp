#include <catch2/catch_test_macros.hpp>

#include "fake_acquisition_job_repository.hpp"
#include "fake_job_execution_history_repository.hpp"
#include "fake_official_source_repository.hpp"
#include "oep/acquisition/acquisition/acquisition_execution_service.hpp"

using namespace oep::acquisition::acquisition;
using oep::acquisition::registry::AuthenticationType;
using oep::acquisition::registry::OfficialSource;
using oep::acquisition::registry::SourceStatus;
using oep::acquisition::registry::TrustLevel;
using oep::acquisition::test_support::FakeAcquisitionJobRepository;
using oep::acquisition::test_support::FakeJobExecutionHistoryRepository;
using oep::acquisition::test_support::FakeOfficialSourceRepository;

namespace {

OfficialSource make_source(SourceStatus status) {
  OfficialSource source;
  source.name = "IEEE";
  source.base_url = "https://ieee.org";
  source.trust_level = TrustLevel::Authoritative;
  source.status = status;
  source.authentication_type = AuthenticationType::None;
  return source;
}

AcquisitionJob make_job(const std::string& source_id) {
  AcquisitionJob job;
  job.source_id = source_id;
  job.name = "Acquire 802.11";
  job.priority = JobPriority::Normal;
  job.status = JobStatus::Created;
  return job;
}

}  // namespace

TEST_CASE("AcquisitionExecutionService.execute advances a job through its lifecycle", "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  const auto source = sources.create(make_source(SourceStatus::Active));
  const auto created = jobs.create(make_job(source.id));

  const auto queued = service.execute(created.id);
  REQUIRE(queued.has_value());
  CHECK(queued->status == JobStatus::Queued);
  CHECK_FALSE(queued->started_at.has_value());

  const auto running = service.execute(created.id);
  REQUIRE(running.has_value());
  CHECK(running->status == JobStatus::Running);
  CHECK(running->started_at.has_value());

  const auto completed = service.execute(created.id);
  REQUIRE(completed.has_value());
  CHECK(completed->status == JobStatus::Completed);
  CHECK(completed->completed_at.has_value());

  const auto recorded = history.list_for_job(created.id);
  REQUIRE(recorded.size() == 3);
  CHECK(recorded[0].from_status == "created");
  CHECK(recorded[0].to_status == "queued");
  CHECK(recorded[1].to_status == "running");
  CHECK(recorded[2].to_status == "completed");
}

TEST_CASE("AcquisitionExecutionService.execute rejects a terminal job", "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  const auto source = sources.create(make_source(SourceStatus::Active));
  const auto created = jobs.create(make_job(source.id));
  service.execute(created.id);  // Queued
  service.execute(created.id);  // Running
  service.execute(created.id);  // Completed

  CHECK_THROWS_AS(service.execute(created.id), InvalidTransitionError);
}

TEST_CASE("AcquisitionExecutionService.execute rejects an archived source", "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  const auto source = sources.create(make_source(SourceStatus::Archived));
  const auto created = jobs.create(make_job(source.id));

  CHECK_THROWS_AS(service.execute(created.id), SourceNotAvailableError);
}

TEST_CASE("AcquisitionExecutionService.execute rejects a job whose source no longer exists",
          "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  const auto created = jobs.create(make_job("does-not-exist"));

  CHECK_THROWS_AS(service.execute(created.id), SourceNotAvailableError);
}

TEST_CASE("AcquisitionExecutionService.execute returns nullopt for an unknown job", "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  CHECK_FALSE(service.execute("does-not-exist").has_value());
}

TEST_CASE("AcquisitionExecutionService.cancel transitions Queued or Running to Cancelled",
          "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  const auto source = sources.create(make_source(SourceStatus::Active));
  const auto created = jobs.create(make_job(source.id));
  service.execute(created.id);  // Queued

  const auto cancelled = service.cancel(created.id);
  REQUIRE(cancelled.has_value());
  CHECK(cancelled->status == JobStatus::Cancelled);
  CHECK(cancelled->completed_at.has_value());
}

TEST_CASE("AcquisitionExecutionService.cancel rejects a job in the Created state", "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  const auto source = sources.create(make_source(SourceStatus::Active));
  const auto created = jobs.create(make_job(source.id));

  CHECK_THROWS_AS(service.cancel(created.id), InvalidTransitionError);
}

TEST_CASE("AcquisitionExecutionService.cancel returns nullopt for an unknown job", "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  CHECK_FALSE(service.cancel("does-not-exist").has_value());
}

TEST_CASE("AcquisitionExecutionService.get_status returns the job and its history",
          "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  const auto source = sources.create(make_source(SourceStatus::Active));
  const auto created = jobs.create(make_job(source.id));
  service.execute(created.id);

  const auto status = service.get_status(created.id);
  REQUIRE(status.has_value());
  CHECK(status->job.status == JobStatus::Queued);
  CHECK(status->history.size() == 1);
}

TEST_CASE("AcquisitionExecutionService.get_status returns nullopt for an unknown job",
          "[execution][service]") {
  FakeOfficialSourceRepository sources;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository history;
  AcquisitionExecutionService service(jobs, sources, history);

  CHECK_FALSE(service.get_status("does-not-exist").has_value());
}
