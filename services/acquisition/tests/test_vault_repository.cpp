#include <catch2/catch_test_macros.hpp>

#include "oep/acquisition/vault/postgres_vault_repository.hpp"
#include "oep/acquisition/vault/vault_errors.hpp"
#include "registry_test_support.hpp"
#include "vault_test_support.hpp"

using namespace oep::acquisition::vault;
using oep::acquisition::test_support::reset_vault_schema;
using oep::acquisition::test_support::seed_extracted_metadata;
using oep::acquisition::test_support::test_database_config;

namespace {

VaultEntry make_entry(const oep::acquisition::test_support::SeededMetadata& seeded) {
  VaultEntry entry;
  entry.metadata_id = seeded.id;
  entry.verification_id = seeded.verification_id;
  entry.download_session_id = seeded.download_session_id;
  entry.source_id = seeded.source_id;
  entry.vault_path = "/reference_vault/" + seeded.sha256_hash.substr(0, 2) + "/" + seeded.sha256_hash;
  entry.sha256_hash = seeded.sha256_hash;
  entry.mime_type = seeded.mime_type;
  entry.file_size_bytes = seeded.file_size_bytes;
  entry.status = VaultEntryStatus::Published;
  entry.published_at = "2026-01-01T00:00:00Z";
  return entry;
}

}  // namespace

TEST_CASE("PostgresVaultRepository performs create/find/list against a real database",
          "[vault][database]") {
  const auto schema_error = reset_vault_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = seed_extracted_metadata();
  PostgresVaultRepository repository(test_database_config());

  SECTION("create assigns id and timestamps") {
    const auto created = repository.create(make_entry(seeded));
    CHECK_FALSE(created.id.empty());
    CHECK_FALSE(created.created_at.empty());
    CHECK(created.updated_at == created.created_at);
    CHECK(created.metadata_id == seeded.id);
    CHECK(created.status == VaultEntryStatus::Published);
    CHECK(created.source_id == seeded.source_id);
  }

  SECTION("create throws UnknownMetadataError for a metadata_id that does not exist") {
    auto entry = make_entry(seeded);
    entry.metadata_id = "00000000-0000-0000-0000-000000000000";
    CHECK_THROWS_AS(repository.create(entry), UnknownMetadataError);
  }

  SECTION("create throws AlreadyPublishedError for a metadata_id already published") {
    repository.create(make_entry(seeded));
    CHECK_THROWS_AS(repository.create(make_entry(seeded)), AlreadyPublishedError);
  }

  SECTION("find_by_id returns the created entry") {
    const auto created = repository.create(make_entry(seeded));
    const auto found = repository.find_by_id(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
    CHECK(found->sha256_hash == seeded.sha256_hash);
  }

  SECTION("find_by_id returns nullopt for an unknown id") {
    CHECK_FALSE(repository.find_by_id("00000000-0000-0000-0000-000000000000").has_value());
  }

  SECTION("list filters by status and metadata_id") {
    const auto created = repository.create(make_entry(seeded));

    VaultFilter status_filter;
    status_filter.status = VaultEntryStatus::Published;
    CHECK(repository.list(status_filter).size() == 1);

    VaultFilter metadata_filter;
    metadata_filter.metadata_id = created.metadata_id;
    CHECK(repository.list(metadata_filter).size() == 1);

    VaultFilter mismatched_filter;
    mismatched_filter.metadata_id = "00000000-0000-0000-0000-000000000000";
    CHECK(repository.list(mismatched_filter).empty());
  }
}
