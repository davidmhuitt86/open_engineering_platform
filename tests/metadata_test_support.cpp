#include "metadata_test_support.hpp"

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
#include "oep/acquisition/integrity/hashing.hpp"
#include "oep/acquisition/integrity/postgres_verification_repository.hpp"
#include "oep/acquisition/integrity/verification.hpp"
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

std::optional<std::string> reset_metadata_schema() {
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
    if (txn.exec("SELECT to_regclass('artifact_metadata')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V7__artifact_metadata.sql"));
    }

    txn.exec(
        "TRUNCATE TABLE artifact_metadata, integrity_verifications, download_sessions, acquisition_jobs, "
        "official_sources RESTART IDENTITY CASCADE");
    txn.commit();
    return std::nullopt;
  } catch (const std::exception& ex) {
    return std::string(ex.what());
  }
}

SeededVerification seed_verified_download(const std::string& file_contents, const std::string& file_name) {
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
      std::filesystem::temp_directory_path() / ("oep_metadata_test_" + std::to_string(++counter));
  std::filesystem::create_directories(workspace);
  const auto artifact_path = workspace / file_name;

  std::ofstream artifact(artifact_path, std::ios::binary);
  artifact << file_contents;
  artifact.close();

  downloads::PostgresDownloadRepository downloads(test_database_config());
  downloads::Download download;
  download.job_id = created_job.id;
  download.connector_id = "example-stub";
  download.source_uri = "stub://example/" + file_name;
  download.local_storage_path = artifact_path.string();
  download.file_name = file_name;
  download.mime_type = "application/octet-stream";
  download.file_size_bytes = file_contents.size();
  download.status = downloads::DownloadStatus::Completed;
  const auto created_download = downloads.create(download);

  const auto hash_result = integrity::hash_file_sha256(artifact_path);

  integrity::PostgresVerificationRepository verifications(test_database_config());
  integrity::Verification verification;
  verification.download_session_id = created_download.id;
  verification.status = integrity::VerificationStatus::Verified;
  verification.sha256_hash = hash_result.has_value() ? hash_result->sha256_hex : "";
  verification.file_size_bytes = hash_result.has_value() ? hash_result->file_size_bytes : file_contents.size();
  const auto created_verification = verifications.create(verification);

  return SeededVerification{
      .id = created_verification.id,
      .download_session_id = created_download.id,
      .local_storage_path = artifact_path.string(),
      .file_size_bytes = verification.file_size_bytes,
      .sha256_hash = verification.sha256_hash,
  };
}

}  // namespace oep::acquisition::test_support
