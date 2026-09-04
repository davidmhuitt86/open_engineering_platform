#include <catch2/catch_test_macros.hpp>

#include "metadata_test_support.hpp"
#include "oep/acquisition/metadata/artifact_metadata_errors.hpp"
#include "oep/acquisition/metadata/postgres_metadata_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::metadata;
using oep::acquisition::test_support::reset_metadata_schema;
using oep::acquisition::test_support::seed_verified_download;
using oep::acquisition::test_support::test_database_config;

namespace {

ArtifactMetadata make_metadata(const std::string& verification_id) {
  ArtifactMetadata metadata;
  metadata.verification_id = verification_id;
  metadata.file_name = "artifact.txt";
  metadata.file_extension = "txt";
  metadata.status = ExtractionStatus::Pending;
  return metadata;
}

}  // namespace

TEST_CASE("PostgresMetadataRepository performs CRUD against a real database", "[metadata][database]") {
  const auto schema_error = reset_metadata_schema();
  if (schema_error.has_value()) {
    SKIP("PostgreSQL test database unavailable: " << *schema_error);
  }

  const auto seeded = seed_verified_download();
  PostgresMetadataRepository repository(test_database_config());

  SECTION("create assigns id and timestamps") {
    const auto created = repository.create(make_metadata(seeded.id));
    CHECK_FALSE(created.id.empty());
    CHECK_FALSE(created.created_at.empty());
    CHECK(created.updated_at == created.created_at);
    CHECK(created.verification_id == seeded.id);
    CHECK(created.status == ExtractionStatus::Pending);
  }

  SECTION("create throws UnknownVerificationError for a verification_id that does not exist") {
    auto metadata = make_metadata("00000000-0000-0000-0000-000000000000");
    CHECK_THROWS_AS(repository.create(metadata), UnknownVerificationError);
  }

  SECTION("find_by_id returns the created record") {
    const auto created = repository.create(make_metadata(seeded.id));
    const auto found = repository.find_by_id(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
    CHECK(found->verification_id == seeded.id);
  }

  SECTION("find_by_id returns nullopt for an unknown id") {
    CHECK_FALSE(repository.find_by_id("00000000-0000-0000-0000-000000000000").has_value());
  }

  SECTION("list returns every record, preserving history") {
    repository.create(make_metadata(seeded.id));
    repository.create(make_metadata(seeded.id));

    CHECK(repository.list(MetadataFilter{}).size() == 2);
  }

  SECTION("list filters by status and verification_id") {
    auto pending = make_metadata(seeded.id);
    repository.create(pending);

    auto extracted = make_metadata(seeded.id);
    extracted.status = ExtractionStatus::Extracted;
    repository.create(extracted);

    MetadataFilter status_filter;
    status_filter.status = ExtractionStatus::Extracted;
    CHECK(repository.list(status_filter).size() == 1);

    MetadataFilter verification_filter;
    verification_filter.verification_id = seeded.id;
    CHECK(repository.list(verification_filter).size() == 2);
  }

  SECTION("update changes fields and refreshes updated_at, preserving id") {
    const auto created = repository.create(make_metadata(seeded.id));

    auto changed = created;
    changed.status = ExtractionStatus::Extracted;
    changed.mime_type = "text/plain";
    changed.pdf_version = "1.7";
    changed.pdf_page_count = 10;

    const auto updated = repository.update(created.id, changed);
    REQUIRE(updated.has_value());
    CHECK(updated->id == created.id);
    CHECK(updated->status == ExtractionStatus::Extracted);
    CHECK(updated->mime_type == "text/plain");
    REQUIRE(updated->pdf_version.has_value());
    CHECK(*updated->pdf_version == "1.7");
    REQUIRE(updated->pdf_page_count.has_value());
    CHECK(*updated->pdf_page_count == 10);
  }

  SECTION("update returns nullopt for an unknown id") {
    CHECK_FALSE(
        repository.update("00000000-0000-0000-0000-000000000000", make_metadata(seeded.id)).has_value());
  }
}
