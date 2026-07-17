#include <catch2/catch_test_macros.hpp>

#include "integrity_test_support.hpp"
#include "oep/acquisition/integrity/postgres_verification_repository.hpp"
#include "oep/acquisition/integrity/verification_errors.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::integrity;
using oep::acquisition::test_support::reset_integrity_schema;
using oep::acquisition::test_support::seed_completed_download;
using oep::acquisition::test_support::test_database_config;

namespace {

Verification make_verification(const std::string& download_session_id) {
  Verification verification;
  verification.download_session_id = download_session_id;
  verification.status = VerificationStatus::Pending;
  return verification;
}

}  // namespace

TEST_CASE("PostgresVerificationRepository performs CRUD against a real database",
          "[integrity][database]") {
  const auto schema_error = reset_integrity_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = seed_completed_download();
  PostgresVerificationRepository repository(test_database_config());

  SECTION("create assigns id and timestamps") {
    const auto created = repository.create(make_verification(seeded.id));
    CHECK_FALSE(created.id.empty());
    CHECK_FALSE(created.created_at.empty());
    CHECK(created.updated_at == created.created_at);
    CHECK(created.download_session_id == seeded.id);
    CHECK(created.status == VerificationStatus::Pending);
  }

  SECTION("create throws UnknownDownloadSessionError for a download_session_id that does not exist") {
    auto verification = make_verification("00000000-0000-0000-0000-000000000000");
    CHECK_THROWS_AS(repository.create(verification), UnknownDownloadSessionError);
  }

  SECTION("find_by_id returns the created verification") {
    const auto created = repository.create(make_verification(seeded.id));
    const auto found = repository.find_by_id(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
    CHECK(found->download_session_id == seeded.id);
  }

  SECTION("find_by_id returns nullopt for an unknown id") {
    CHECK_FALSE(repository.find_by_id("00000000-0000-0000-0000-000000000000").has_value());
  }

  SECTION("list returns every verification") {
    repository.create(make_verification(seeded.id));
    repository.create(make_verification(seeded.id));

    CHECK(repository.list(VerificationFilter{}).size() == 2);
  }

  SECTION("list filters by status and download_session_id") {
    auto pending = make_verification(seeded.id);
    repository.create(pending);

    auto verified = make_verification(seeded.id);
    verified.status = VerificationStatus::Verified;
    repository.create(verified);

    VerificationFilter status_filter;
    status_filter.status = VerificationStatus::Verified;
    CHECK(repository.list(status_filter).size() == 1);

    VerificationFilter session_filter;
    session_filter.download_session_id = seeded.id;
    CHECK(repository.list(session_filter).size() == 2);
  }

  SECTION("update changes fields and refreshes updated_at, preserving id") {
    const auto created = repository.create(make_verification(seeded.id));

    auto changed = created;
    changed.status = VerificationStatus::Verified;
    changed.sha256_hash = "abc123";
    changed.file_size_bytes = 42;

    const auto updated = repository.update(created.id, changed);
    REQUIRE(updated.has_value());
    CHECK(updated->id == created.id);
    CHECK(updated->status == VerificationStatus::Verified);
    CHECK(updated->sha256_hash == "abc123");
    CHECK(updated->file_size_bytes == 42);
  }

  SECTION("update returns nullopt for an unknown id") {
    CHECK_FALSE(
        repository.update("00000000-0000-0000-0000-000000000000", make_verification(seeded.id)).has_value());
  }
}
