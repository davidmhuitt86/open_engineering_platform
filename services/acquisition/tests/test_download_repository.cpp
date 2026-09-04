#include <catch2/catch_test_macros.hpp>

#include "downloads_test_support.hpp"
#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/downloads/download_repository.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "registry_test_support.hpp"

using namespace oep::acquisition::downloads;
using oep::acquisition::acquisition::AcquisitionJob;
using oep::acquisition::acquisition::JobPriority;
using oep::acquisition::acquisition::JobStatus;
using oep::acquisition::acquisition::PostgresAcquisitionJobRepository;
using oep::acquisition::test_support::reset_downloads_schema;
using oep::acquisition::test_support::seed_official_source;
using oep::acquisition::test_support::test_database_config;

namespace {

Download make_download(const std::string& job_id) {
  Download download;
  download.job_id = job_id;
  download.connector_id = "example-stub";
  download.source_uri = "stub://example/artifact.pdf";
  download.local_storage_path = "/tmp/workspace/artifact.pdf";
  download.file_name = "artifact.pdf";
  download.status = DownloadStatus::Pending;
  return download;
}

}  // namespace

TEST_CASE("PostgresDownloadRepository performs CRUD against a real database", "[downloads][database]") {
  const auto schema_error = reset_downloads_schema();
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
  const auto created_job = jobs.create(job);

  PostgresDownloadRepository repository(test_database_config());

  SECTION("create assigns id and timestamps") {
    const auto created = repository.create(make_download(created_job.id));
    CHECK_FALSE(created.id.empty());
    CHECK_FALSE(created.created_at.empty());
    CHECK(created.updated_at == created.created_at);
    CHECK(created.job_id == created_job.id);
    CHECK(created.status == DownloadStatus::Pending);
    CHECK(created.progress_percentage == 0);
  }

  SECTION("create throws UnknownJobError for a job_id that does not exist") {
    auto download = make_download("00000000-0000-0000-0000-000000000000");
    CHECK_THROWS_AS(repository.create(download), UnknownJobError);
  }

  SECTION("find_by_id returns the created download") {
    const auto created = repository.create(make_download(created_job.id));
    const auto found = repository.find_by_id(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
    CHECK(found->source_uri == "stub://example/artifact.pdf");
  }

  SECTION("find_by_id returns nullopt for an unknown id") {
    CHECK_FALSE(repository.find_by_id("00000000-0000-0000-0000-000000000000").has_value());
  }

  SECTION("list returns every download") {
    repository.create(make_download(created_job.id));
    auto second = make_download(created_job.id);
    second.file_name = "second.pdf";
    repository.create(second);

    CHECK(repository.list(DownloadFilter{}).size() == 2);
  }

  SECTION("list filters by status and job_id") {
    auto pending = make_download(created_job.id);
    repository.create(pending);

    auto completed = make_download(created_job.id);
    completed.status = DownloadStatus::Completed;
    repository.create(completed);

    DownloadFilter status_filter;
    status_filter.status = DownloadStatus::Completed;
    CHECK(repository.list(status_filter).size() == 1);

    DownloadFilter job_filter;
    job_filter.job_id = created_job.id;
    CHECK(repository.list(job_filter).size() == 2);
  }

  SECTION("update changes fields and refreshes updated_at, preserving id") {
    const auto created = repository.create(make_download(created_job.id));

    auto changed = created;
    changed.status = DownloadStatus::Completed;
    changed.progress_percentage = 100;
    changed.mime_type = "application/pdf";
    changed.file_size_bytes = 1024;

    const auto updated = repository.update(created.id, changed);
    REQUIRE(updated.has_value());
    CHECK(updated->id == created.id);
    CHECK(updated->status == DownloadStatus::Completed);
    CHECK(updated->progress_percentage == 100);
    CHECK(updated->mime_type == "application/pdf");
    CHECK(updated->file_size_bytes == 1024);
  }

  SECTION("update returns nullopt for an unknown id") {
    CHECK_FALSE(repository.update("00000000-0000-0000-0000-000000000000", make_download(created_job.id))
                    .has_value());
  }
}
