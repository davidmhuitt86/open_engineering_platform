#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/provenance/acquisition_record_repository.hpp"
#include "oep/acquisition/provenance/postgres_acquisition_record_repository.hpp"
#include "provenance_test_support.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::provenance;
using oep::acquisition::test_support::reset_provenance_schema;
using oep::acquisition::test_support::seed_completed_download;
using oep::acquisition::test_support::test_database_config;

namespace {

AcquisitionRecord make_record(const std::string& download_session_id) {
  AcquisitionRecord record;
  record.download_session_id = download_session_id;
  record.status = AcquisitionRecordStatus::Acquired;
  return record;
}

}  // namespace

TEST_CASE("PostgresAcquisitionRecordRepository performs create/find/list/update_status against a real database",
          "[provenance][database]") {
  const auto schema_error = reset_provenance_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = seed_completed_download();
  PostgresAcquisitionRecordRepository repository(test_database_config());

  SECTION("create assigns id and timestamps") {
    const auto created = repository.create(make_record(seeded.id));
    CHECK_FALSE(created.id.empty());
    CHECK_FALSE(created.created_at.empty());
    CHECK(created.updated_at == created.created_at);
    CHECK(created.download_session_id == seeded.id);
    CHECK(created.status == AcquisitionRecordStatus::Acquired);
  }

  SECTION("create throws UnknownDownloadSessionError for a download_session_id that does not exist") {
    auto record = make_record("00000000-0000-0000-0000-000000000000");
    CHECK_THROWS_AS(repository.create(record), UnknownDownloadSessionError);
  }

  SECTION("create throws DuplicateAcquisitionRecordError for a download_session_id already recorded") {
    repository.create(make_record(seeded.id));
    CHECK_THROWS_AS(repository.create(make_record(seeded.id)), DuplicateAcquisitionRecordError);
  }

  SECTION("find_by_id returns the created record") {
    const auto created = repository.create(make_record(seeded.id));
    const auto found = repository.find_by_id(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
  }

  SECTION("find_by_id returns nullopt for an unknown id") {
    CHECK_FALSE(repository.find_by_id("00000000-0000-0000-0000-000000000000").has_value());
  }

  SECTION("find_by_download_session_id returns the created record") {
    const auto created = repository.create(make_record(seeded.id));
    const auto found = repository.find_by_download_session_id(seeded.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
  }

  SECTION("find_by_download_session_id returns nullopt when none exists") {
    CHECK_FALSE(repository.find_by_download_session_id(seeded.id).has_value());
  }

  SECTION("list filters by status") {
    repository.create(make_record(seeded.id));

    AcquisitionRecordFilter matching_filter;
    matching_filter.status = AcquisitionRecordStatus::Acquired;
    CHECK(repository.list(matching_filter).size() == 1);

    AcquisitionRecordFilter mismatched_filter;
    mismatched_filter.status = AcquisitionRecordStatus::Published;
    CHECK(repository.list(mismatched_filter).empty());
  }

  SECTION("update_status advances status and sets error_message, leaving download_session_id/created_at untouched") {
    const auto created = repository.create(make_record(seeded.id));
    const auto updated = repository.update_status(created.id, AcquisitionRecordStatus::Failed, "hash mismatch");
    REQUIRE(updated.has_value());
    CHECK(updated->id == created.id);
    CHECK(updated->download_session_id == created.download_session_id);
    CHECK(updated->created_at == created.created_at);
    CHECK(updated->status == AcquisitionRecordStatus::Failed);
    REQUIRE(updated->error_message.has_value());
    CHECK(*updated->error_message == "hash mismatch");
  }

  SECTION("update_status returns nullopt for an unknown id") {
    CHECK_FALSE(
        repository.update_status("00000000-0000-0000-0000-000000000000", AcquisitionRecordStatus::Failed, std::nullopt)
            .has_value());
  }
}
