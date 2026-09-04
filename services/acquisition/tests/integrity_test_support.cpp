#include "integrity_test_support.hpp"

#include <atomic>
#include <filesystem>
#include <fstream>
#include <sstream>

#include <pqxx/pqxx>

#include "jobs_test_support.hpp"
#include "oep/acquisition/acquisition/acquisition_job.hpp"
#include "oep/acquisition/acquisition/postgres_acquisition_job_repository.hpp"
#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/downloads/download.hpp"
#include "oep/acquisition/downloads/postgres_download_repository.hpp"
#include "registry_test_support.hpp"

namespace oep::acquisition::test_support {

namespace {

std::string read_file(const std::filesystem::path& path) {
  std::ifstream stream(path);
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

}  // namespace

std::optional<std::string> reset_integrity_schema() {
  try {
    pqxx::connection connection(
        common::Config{.database = test_database_config()}.database_connection_string());
    pqxx::work txn(connection);

    const std::filesystem::path migrations_dir = OEP_ACQUISITION_MIGRATIONS_DIR;

    if (txn.exec("SELECT to_regclass('official_sources')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V1__initial_schema.sql"));
      txn.exec(read_file(migrations_dir / "V2__official_sources.sql"));
    }
    if (txn.exec("SELECT to_regclass('acquisition_jobs')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V3__acquisition_jobs.sql"));
    }
    if (txn.exec("SELECT to_regclass('download_sessions')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V5__download_sessions.sql"));
    }
    if (txn.exec("SELECT to_regclass('integrity_verifications')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V6__integrity_verifications.sql"));
    }

    txn.exec(
        "TRUNCATE TABLE integrity_verifications, download_sessions, acquisition_jobs, official_sources "
        "RESTART IDENTITY CASCADE");
    txn.commit();
    return std::nullopt;
  } catch (const std::exception& ex) {
    return std::string(ex.what());
  }
}

SeededDownload seed_completed_download(const std::string& file_contents) {
  const std::string source_id = seed_official_source();

  acquisition::PostgresAcquisitionJobRepository jobs(test_database_config());
  acquisition::AcquisitionJob job;
  job.source_id = source_id;
  job.name = "Acquire 802.11";
  job.priority = acquisition::JobPriority::Normal;
  job.status = acquisition::JobStatus::Created;
  const auto created_job = jobs.create(job);

  static std::atomic<int> counter{0};
  const auto workspace =
      std::filesystem::temp_directory_path() / ("oep_integrity_test_" + std::to_string(++counter));
  std::filesystem::create_directories(workspace);
  const auto artifact_path = workspace / "artifact.bin";

  std::ofstream artifact(artifact_path, std::ios::binary);
  artifact << file_contents;
  artifact.close();

  downloads::PostgresDownloadRepository downloads(test_database_config());
  downloads::Download download;
  download.job_id = created_job.id;
  download.connector_id = "example-stub";
  download.source_uri = "stub://example/artifact.bin";
  download.local_storage_path = artifact_path.string();
  download.file_name = "artifact.bin";
  download.mime_type = "application/octet-stream";
  download.file_size_bytes = file_contents.size();
  download.status = downloads::DownloadStatus::Completed;
  const auto created_download = downloads.create(download);

  return SeededDownload{.id = created_download.id, .local_storage_path = artifact_path.string()};
}

}  // namespace oep::acquisition::test_support
