#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/registry/postgres_official_source_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::registry;
using oep::acquisition::test_support::reset_official_sources_table;
using oep::acquisition::test_support::test_database_config;

namespace {

OfficialSource make_source() {
  OfficialSource source;
  source.name = "Example Standards Body";
  source.organization = "Example Org";
  source.base_url = "https://example.org";
  source.description = "A test source.";
  source.country = "US";
  source.language = "en";
  source.category = "standards";
  source.trust_level = TrustLevel::Authoritative;
  source.status = SourceStatus::Active;
  source.authentication_type = AuthenticationType::None;
  return source;
}

}  // namespace

TEST_CASE("PostgresOfficialSourceRepository performs CRUD against a real database", "[registry][database]") {
  const auto schema_error = reset_official_sources_table();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  PostgresOfficialSourceRepository repository(test_database_config());

  SECTION("create assigns id and timestamps") {
    const auto created = repository.create(make_source());
    CHECK_FALSE(created.id.empty());
    CHECK_FALSE(created.created_at.empty());
    CHECK(created.updated_at == created.created_at);
    CHECK(created.name == "Example Standards Body");
  }

  SECTION("find_by_id returns the created source") {
    const auto created = repository.create(make_source());
    const auto found = repository.find_by_id(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
    CHECK(found->base_url == "https://example.org");
  }

  SECTION("find_by_id returns nullopt for an unknown id") {
    CHECK_FALSE(repository.find_by_id("00000000-0000-0000-0000-000000000000").has_value());
  }

  SECTION("find_by_id returns nullopt for a malformed id") {
    CHECK_FALSE(repository.find_by_id("not-a-uuid").has_value());
  }

  SECTION("list returns every non-deleted source") {
    repository.create(make_source());
    auto second = make_source();
    second.name = "Second Source";
    repository.create(second);

    CHECK(repository.list(SourceFilter{}).size() == 2);
  }

  SECTION("list filters by status and trust level") {
    auto active = make_source();
    active.status = SourceStatus::Active;
    repository.create(active);

    auto suspended = make_source();
    suspended.status = SourceStatus::Suspended;
    suspended.trust_level = TrustLevel::Community;
    repository.create(suspended);

    SourceFilter status_filter;
    status_filter.status = SourceStatus::Active;
    CHECK(repository.list(status_filter).size() == 1);

    SourceFilter trust_filter;
    trust_filter.trust_level = TrustLevel::Community;
    CHECK(repository.list(trust_filter).size() == 1);
  }

  SECTION("update changes fields and refreshes updated_at, preserving id and created_at") {
    const auto created = repository.create(make_source());

    auto changed = created;
    changed.name = "Renamed Source";
    changed.status = SourceStatus::Suspended;

    const auto updated = repository.update(created.id, changed);
    REQUIRE(updated.has_value());
    CHECK(updated->id == created.id);
    CHECK(updated->created_at == created.created_at);
    CHECK(updated->name == "Renamed Source");
    CHECK(updated->status == SourceStatus::Suspended);
  }

  SECTION("update returns nullopt for an unknown id") {
    CHECK_FALSE(repository.update("00000000-0000-0000-0000-000000000000", make_source()).has_value());
  }

  SECTION("soft_delete hides the source from find_by_id and list") {
    const auto created = repository.create(make_source());
    CHECK(repository.soft_delete(created.id));
    CHECK_FALSE(repository.find_by_id(created.id).has_value());
    CHECK(repository.list(SourceFilter{}).empty());
  }

  SECTION("soft_delete is not repeatable") {
    const auto created = repository.create(make_source());
    CHECK(repository.soft_delete(created.id));
    CHECK_FALSE(repository.soft_delete(created.id));
  }

  SECTION("soft_delete returns false for an unknown id") {
    CHECK_FALSE(repository.soft_delete("00000000-0000-0000-0000-000000000000"));
  }
}
