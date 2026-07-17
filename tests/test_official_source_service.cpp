#include <catch2/catch_test_macros.hpp>

#include "fake_official_source_repository.hpp"
#include "oep/acquisition/registry/official_source_service.hpp"
#include "oep/acquisition/registry/validation.hpp"

using namespace oep::acquisition::registry;
using oep::acquisition::test_support::FakeOfficialSourceRepository;

namespace {

nlohmann::json valid_body() {
  return nlohmann::json{
      {"name", "Example Standards Body"},
      {"base_url", "https://example.org"},
      {"trust_level", 4},
      {"status", "active"},
  };
}

}  // namespace

TEST_CASE("OfficialSourceService creates and retrieves a source", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  const auto created = service.create(valid_body());
  CHECK_FALSE(created.id.empty());

  const auto found = service.get(created.id);
  REQUIRE(found.has_value());
  CHECK(found->name == "Example Standards Body");
}

TEST_CASE("OfficialSourceService propagates validation failures from create", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  CHECK_THROWS_AS(service.create(nlohmann::json::object()), ValidationError);
}

TEST_CASE("OfficialSourceService.get returns nullopt for an unknown id", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  CHECK_FALSE(service.get("does-not-exist").has_value());
}

TEST_CASE("OfficialSourceService.list applies filters", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  service.create(valid_body());
  auto suspended = valid_body();
  suspended["status"] = "suspended";
  service.create(suspended);

  CHECK(service.list(SourceFilter{}).size() == 2);

  SourceFilter filter;
  filter.status = SourceStatus::Suspended;
  CHECK(service.list(filter).size() == 1);
}

TEST_CASE("OfficialSourceService.update changes fields but preserves id/created_at", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  const auto created = service.create(valid_body());

  auto changed = valid_body();
  changed["name"] = "Renamed";
  const auto updated = service.update(created.id, changed);

  REQUIRE(updated.has_value());
  CHECK(updated->id == created.id);
  CHECK(updated->created_at == created.created_at);
  CHECK(updated->name == "Renamed");
}

TEST_CASE("OfficialSourceService.update returns nullopt for an unknown id", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  CHECK_FALSE(service.update("does-not-exist", valid_body()).has_value());
}

TEST_CASE("OfficialSourceService.update rejects an attempt to change the immutable id", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  const auto created = service.create(valid_body());
  auto changed = valid_body();
  changed["id"] = "some-other-id";

  CHECK_THROWS_AS(service.update(created.id, changed), ValidationError);
}

TEST_CASE("OfficialSourceService.remove soft-deletes and is not repeatable", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  const auto created = service.create(valid_body());

  CHECK(service.remove(created.id));
  CHECK_FALSE(service.get(created.id).has_value());
  CHECK_FALSE(service.remove(created.id));
}

TEST_CASE("OfficialSourceService.enable sets status to Active", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  auto suspended = valid_body();
  suspended["status"] = "suspended";
  const auto created = service.create(suspended);

  const auto enabled = service.enable(created.id);
  REQUIRE(enabled.has_value());
  CHECK(enabled->status == SourceStatus::Active);
}

TEST_CASE("OfficialSourceService.disable sets status to Suspended", "[registry][service]") {
  FakeOfficialSourceRepository repository;
  OfficialSourceService service(repository);

  const auto created = service.create(valid_body());

  const auto disabled = service.disable(created.id);
  REQUIRE(disabled.has_value());
  CHECK(disabled->status == SourceStatus::Suspended);
}
