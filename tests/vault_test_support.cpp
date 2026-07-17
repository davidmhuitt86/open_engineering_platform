#include "vault_test_support.hpp"

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
#include "oep/acquisition/metadata/artifact_metadata.hpp"
#include "oep/acquisition/metadata/postgres_metadata_repository.hpp"
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

std::optional<std::string> reset_vault_schema() {
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
    if (txn.exec("SELECT to_regclass('reference_vault')")[0][0].is_null()) {
      txn.exec(read_file(migrations_dir / "V8__reference_vault.sql"));
    }

    txn.exec(
        "TRUNCATE TABLE reference_vault, artifact_metadata, integrity_verifications, download_sessions, "
        "acquisition_jobs, official_sources RESTART IDENTITY CASCADE");
    txn.commit();
    return std::nullopt;
  } catch (const std::exception& ex) {
    return std::string(ex.what());
  }
}

SeededMetadata seed_extracted_metadata(const std::string& file_contents, const std::string& file_name) {
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
      std::filesystem::temp_directory_path() / ("oep_vault_test_" + std::to_string(++counter));
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
  download.mime_type = "text/plain";
  download.file_size_bytes = file_contents.size();
  download.status = downloads::DownloadStatus::Completed;
  const auto created_download = downloads.create(download);

  const auto hash_result = integrity::hash_file_sha256(artifact_path);
  const std::string sha256_hash = hash_result.has_value() ? hash_result->sha256_hex : "";
  const std::uint64_t file_size_bytes =
      hash_result.has_value() ? hash_result->file_size_bytes : file_contents.size();

  integrity::PostgresVerificationRepository verifications(test_database_config());
  integrity::Verification verification;
  verification.download_session_id = created_download.id;
  verification.status = integrity::VerificationStatus::Verified;
  verification.sha256_hash = sha256_hash;
  verification.file_size_bytes = file_size_bytes;
  const auto created_verification = verifications.create(verification);

  metadata::PostgresMetadataRepository metadata_repo(test_database_config());
  metadata::ArtifactMetadata artifact_metadata;
  artifact_metadata.verification_id = created_verification.id;
  artifact_metadata.file_name = file_name;
  artifact_metadata.mime_type = "text/plain";
  artifact_metadata.sha256_hash = sha256_hash;
  artifact_metadata.file_size_bytes = file_size_bytes;
  artifact_metadata.status = metadata::ExtractionStatus::Extracted;
  const auto created_metadata = metadata_repo.create(artifact_metadata);

  return SeededMetadata{
      .id = created_metadata.id,
      .verification_id = created_verification.id,
      .download_session_id = created_download.id,
      .source_id = source_id,
      .local_storage_path = artifact_path.string(),
      .sha256_hash = sha256_hash,
      .file_size_bytes = file_size_bytes,
      .mime_type = "text/plain",
  };
}

}  // namespace oep::acquisition::test_support
