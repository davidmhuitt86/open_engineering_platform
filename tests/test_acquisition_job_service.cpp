#include <catch2/catch_test_macros.hpp>

#include "fake_acquisition_job_repository.hpp"
#include "oep/acquisition/acquisition/acquisition_job_service.hpp"
#include "oep/acquisition/acquisition/validation.hpp"

using namespace oep::acquisition::acquisition;
using oep::acquisition::test_support::FakeAcquisitionJobRepository;

namespace {

nlohmann::json valid_create_body() {
  return nlohmann::json{
      {"name", "Acquire IEEE Standard 802.11"},
      {"source_id", "11111111-1111-1111-1111-111111111111"},
      {"priority", 1},
  };
}

}  // namespace

TEST_CASE("AcquisitionJobService creates a job in the Created state and retrieves it", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  const auto created = service.create(valid_create_body());
  CHECK_FALSE(created.id.empty());
  CHECK(created.status == JobStatus::Created);

  const auto found = service.get(created.id);
  REQUIRE(found.has_value());
  CHECK(found->name == "Acquire IEEE Standard 802.11");
}

TEST_CASE("AcquisitionJobService propagates validation failures from create", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  CHECK_THROWS_AS(service.create(nlohmann::json::object()), ValidationError);
}

TEST_CASE("AcquisitionJobService.get returns nullopt for an unknown id", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  CHECK_FALSE(service.get("does-not-exist").has_value());
}

TEST_CASE("AcquisitionJobService.list applies filters", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  service.create(valid_create_body());
  auto second = valid_create_body();
  second["priority"] = 3;
  service.create(second);

  CHECK(service.list(JobFilter{}).size() == 2);

  JobFilter filter;
  filter.priority = JobPriority::Urgent;
  CHECK(service.list(filter).size() == 1);
}

TEST_CASE("AcquisitionJobService.update changes status but preserves id/created_at", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  const auto created = service.create(valid_create_body());

  auto changed = valid_create_body();
  changed["status"] = "running";
  const auto updated = service.update(created.id, changed);

  REQUIRE(updated.has_value());
  CHECK(updated->id == created.id);
  CHECK(updated->created_at == created.created_at);
  CHECK(updated->status == JobStatus::Running);
}

TEST_CASE("AcquisitionJobService.update returns nullopt for an unknown id", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  auto body = valid_create_body();
  body["status"] = "queued";
  CHECK_FALSE(service.update("does-not-exist", body).has_value());
}

TEST_CASE("AcquisitionJobService.update rejects an attempt to change the immutable id", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  const auto created = service.create(valid_create_body());
  auto changed = valid_create_body();
  changed["status"] = "queued";
  changed["id"] = "some-other-id";

  CHECK_THROWS_AS(service.update(created.id, changed), ValidationError);
}

TEST_CASE("AcquisitionJobService.remove soft-deletes and is not repeatable", "[jobs][service]") {
  FakeAcquisitionJobRepository repository;
  AcquisitionJobService service(repository);

  const auto created = service.create(valid_create_body());

  CHECK(service.remove(created.id));
  CHECK_FALSE(service.get(created.id).has_value());
  CHECK_FALSE(service.remove(created.id));
}
