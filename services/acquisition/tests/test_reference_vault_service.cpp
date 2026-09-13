#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>

#include "fake_acquisition_job_repository.hpp"
#include "fake_download_repository.hpp"
#include "fake_metadata_repository.hpp"
#include "fake_vault_repository.hpp"
#include "fake_verification_repository.hpp"
#include "oep/acquisition/acquisition/acquisition_job.hpp"
#include "oep/acquisition/downloads/download.hpp"
#include "oep/acquisition/integrity/hashing.hpp"
#include "oep/acquisition/integrity/verification.hpp"
#include "oep/acquisition/metadata/artifact_metadata.hpp"
#include "oep/acquisition/vault/reference_vault_service.hpp"
#include "oep/acquisition/vault/validation.hpp"
#include "oep/acquisition/vault/vault_errors.hpp"
#include "oep/acquisition/vault/vault_path.hpp"

using namespace oep::acquisition::vault;
using oep::acquisition::acquisition::AcquisitionJob;
using oep::acquisition::acquisition::JobPriority;
using oep::acquisition::acquisition::JobStatus;
using oep::acquisition::downloads::Download;
using oep::acquisition::downloads::DownloadStatus;
using oep::acquisition::integrity::Verification;
using oep::acquisition::integrity::VerificationStatus;
using oep::acquisition::metadata::ArtifactMetadata;
using oep::acquisition::metadata::ExtractionStatus;
using oep::acquisition::test_support::FakeAcquisitionJobRepository;
using oep::acquisition::test_support::FakeDownloadRepository;
using oep::acquisition::test_support::FakeMetadataRepository;
using oep::acquisition::test_support::FakeVaultRepository;
using oep::acquisition::test_support::FakeVerificationRepository;

namespace {

std::filesystem::path make_scratch_dir() {
  static std::atomic<int> counter{0};
  auto path = std::filesystem::temp_directory_path() / ("oep_vault_service_test_" + std::to_string(++counter));
  std::filesystem::create_directories(path);
  return path;
}

std::filesystem::path make_scratch_file(const std::string& contents, const std::string& name = "artifact.txt") {
  const auto path = make_scratch_dir() / name;
  std::ofstream(path, std::ios::binary) << contents;
  return path;
}

nlohmann::json publish_body(const std::string& metadata_id) {
  return nlohmann::json{{"metadata_id", metadata_id}};
}

// Seeds a full Source -> Job -> Download -> Verification -> Metadata
// chain across the fakes, with a real file on disk, and returns the
// created ArtifactMetadata's id.
struct Chain {
  std::string metadata_id;
  std::string download_id;
  std::string job_id;
};

Chain seed_chain(FakeAcquisitionJobRepository& jobs, FakeDownloadRepository& downloads,
                   FakeVerificationRepository& verifications, FakeMetadataRepository& metadata_repo,
                   const std::filesystem::path& artifact_path, ExtractionStatus metadata_status = ExtractionStatus::Extracted,
                   VerificationStatus verification_status = VerificationStatus::Verified) {
  AcquisitionJob job;
  job.source_id = "source-1";
  job.name = "Acquire 802.11";
  job.priority = JobPriority::Normal;
  job.status = JobStatus::Created;
  const auto created_job = jobs.create(job);

  Download download;
  download.job_id = created_job.id;
  download.connector_id = "conn-1";
  download.source_uri = "stub://example/artifact.txt";
  download.local_storage_path = artifact_path.string();
  download.file_name = artifact_path.filename().string();
  download.status = DownloadStatus::Completed;
  const auto created_download = downloads.create(download);

  const auto hash_result = oep::acquisition::integrity::hash_file_sha256(artifact_path);

  Verification verification;
  verification.download_session_id = created_download.id;
  verification.status = verification_status;
  verification.sha256_hash = hash_result.has_value() ? hash_result->sha256_hex : "";
  verification.file_size_bytes = hash_result.has_value() ? hash_result->file_size_bytes : 0;
  const auto created_verification = verifications.create(verification);

  ArtifactMetadata metadata;
  metadata.verification_id = created_verification.id;
  metadata.file_name = download.file_name;
  metadata.mime_type = "text/plain";
  metadata.sha256_hash = verification.sha256_hash;
  metadata.file_size_bytes = verification.file_size_bytes;
  metadata.status = metadata_status;
  const auto created_metadata = metadata_repo.create(metadata);

  return Chain{.metadata_id = created_metadata.id, .download_id = created_download.id, .job_id = created_job.id};
}

}  // namespace

TEST_CASE("ReferenceVaultService.publish records Published for a healthy chain", "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("engineering artifact contents");
  const auto chain = seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();

  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);
  const auto result = service.publish(publish_body(chain.metadata_id));

  CHECK(result.status == VaultEntryStatus::Published);
  CHECK(result.metadata_id == chain.metadata_id);
  CHECK(result.source_id == "source-1");
  CHECK_FALSE(result.vault_path.empty());
  CHECK(std::filesystem::exists(result.vault_path));
  CHECK_FALSE(result.published_at.empty());
  CHECK_FALSE(result.sha256_hash.empty());

  const auto copied_contents = [&] {
    std::ifstream stream(result.vault_path, std::ios::binary);
    std::ostringstream buffer;
    buffer << stream.rdbuf();
    return buffer.str();
  }();
  CHECK(copied_contents == "engineering artifact contents");
}

TEST_CASE("ReferenceVaultService.publish throws ValidationError for a malformed body", "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  CHECK_THROWS_AS(service.publish(nlohmann::json::object()), ValidationError);
}

TEST_CASE("ReferenceVaultService.publish throws UnknownMetadataError for a nonexistent metadata_id",
          "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  CHECK_THROWS_AS(service.publish(publish_body("does-not-exist")), UnknownMetadataError);
}

TEST_CASE("ReferenceVaultService.publish throws MetadataNotSuccessfulError for Pending metadata",
          "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("contents");
  const auto chain =
      seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path, ExtractionStatus::Pending);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  CHECK_THROWS_AS(service.publish(publish_body(chain.metadata_id)), MetadataNotSuccessfulError);
}

TEST_CASE("ReferenceVaultService.publish throws MetadataNotSuccessfulError for Failed metadata",
          "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("contents");
  const auto chain =
      seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path, ExtractionStatus::Failed);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  CHECK_THROWS_AS(service.publish(publish_body(chain.metadata_id)), MetadataNotSuccessfulError);
}

TEST_CASE("ReferenceVaultService.publish throws AlreadyPublishedError for a second publish attempt",
          "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("contents");
  const auto chain = seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  service.publish(publish_body(chain.metadata_id));
  CHECK_THROWS_AS(service.publish(publish_body(chain.metadata_id)), AlreadyPublishedError);
}

TEST_CASE("ReferenceVaultService.publish throws VerificationNotSuccessfulError for a Failed verification",
          "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("contents");
  const auto chain = seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path,
                                   ExtractionStatus::Extracted, VerificationStatus::Failed);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  CHECK_THROWS_AS(service.publish(publish_body(chain.metadata_id)), VerificationNotSuccessfulError);
}

TEST_CASE("ReferenceVaultService.publish throws ArtifactNotFoundError for a missing artifact",
          "[vault][service][missing-file]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("contents");
  const auto chain = seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path);
  std::filesystem::remove(artifact_path);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  CHECK_THROWS_AS(service.publish(publish_body(chain.metadata_id)), ArtifactNotFoundError);
}

TEST_CASE("ReferenceVaultService.publish throws ArtifactHashMismatchError for a tampered artifact",
          "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("original contents");
  const auto chain = seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path);

  // Mutate the artifact after Verification/Metadata already recorded its
  // original hash -- WORK_PACKAGE-009's "SHA-256 shall match the
  // Verification record before publication."
  std::ofstream(artifact_path, std::ios::binary | std::ios::trunc) << "tampered contents";

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  CHECK_THROWS_AS(service.publish(publish_body(chain.metadata_id)), ArtifactHashMismatchError);
}

TEST_CASE("ReferenceVaultService.publish deduplicates identical content across two different chains",
          "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto first_path = make_scratch_file("identical content", "first.txt");
  const auto second_path = make_scratch_file("identical content", "second.txt");
  const auto first_chain = seed_chain(jobs, downloads, verifications, metadata_repo, first_path);
  const auto second_chain = seed_chain(jobs, downloads, verifications, metadata_repo, second_path);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  const auto first_result = service.publish(publish_body(first_chain.metadata_id));
  const auto second_result = service.publish(publish_body(second_chain.metadata_id));

  CHECK(first_result.id != second_result.id);
  CHECK(first_result.vault_path == second_result.vault_path);
  CHECK(first_result.sha256_hash == second_result.sha256_hash);
  CHECK(vault_repo.list(VaultFilter{}).size() == 2);
}

TEST_CASE("ReferenceVaultService.publish removes the just-copied file if the repository insert fails",
          "[vault][service]") {
  // WP-017 (EAM / Reference Vault Implementation Audit) Section 8 -- the
  // artifact copy into vault storage and the VaultEntry database insert
  // are not one atomic operation. Demonstrates the gap this task's own
  // audit asked about (can publication leave an orphaned file?) and that
  // ReferenceVaultService::publish now closes it: when the repository
  // insert throws immediately after a fresh copy, no file is left behind
  // at the computed vault path.
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  // Content includes a real-time nonce, not a fixed literal: `make_scratch_dir`
  // never cleans up between process invocations, and its counter is
  // otherwise fully deterministic by test-execution order -- a fixed
  // literal here would hash to the same content-addressed vault path on
  // every run of this binary, so a *prior* run's own successful retry
  // (below) would still be sitting on disk and be indistinguishable from
  // this run's fix failing to clean up after itself.
  const auto nonce = std::chrono::steady_clock::now().time_since_epoch().count();
  const auto path = make_scratch_file("orphan-check content " + std::to_string(nonce));
  const auto chain = seed_chain(jobs, downloads, verifications, metadata_repo, path);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  // The exact content-addressed path this test's own artifact would land
  // at, computed the same deterministic way ReferenceVaultService does --
  // checked directly rather than scanning all of `storage.root_path`,
  // since scratch directories from earlier, unrelated test runs are never
  // cleaned up (a pre-existing property of `make_scratch_dir`/temp_directory_path
  // reuse across process invocations) and a broad recursive scan would
  // false-positive on their leftovers.
  const auto expected_hash = oep::acquisition::integrity::hash_file_sha256(path)->sha256_hex;
  const auto expected_vault_path = compute_vault_path(storage.root_path, expected_hash);

  vault_repo.fail_next_create = true;
  REQUIRE_THROWS(service.publish(publish_body(chain.metadata_id)));

  // Nothing was left in vault storage -- no orphaned file, no VaultEntry.
  CHECK(vault_repo.list(VaultFilter{}).empty());
  CHECK_FALSE(std::filesystem::exists(expected_vault_path));

  // A retry with a working repository still succeeds against the same
  // artifact -- the earlier failed attempt did not corrupt anything.
  const auto result = service.publish(publish_body(chain.metadata_id));
  CHECK(result.status == VaultEntryStatus::Published);
  CHECK(std::filesystem::exists(result.vault_path));
}

TEST_CASE("ReferenceVaultService.publish never deletes a dedup-reused file when the repository insert fails",
          "[vault][service]") {
  // The cleanup above must never remove a file a *different*, already-
  // published Vault Entry legitimately owns -- only a file *this specific
  // call* copied fresh.
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto first_path = make_scratch_file("shared content", "first.txt");
  const auto second_path = make_scratch_file("shared content", "second.txt");
  const auto first_chain = seed_chain(jobs, downloads, verifications, metadata_repo, first_path);
  const auto second_chain = seed_chain(jobs, downloads, verifications, metadata_repo, second_path);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);

  const auto first_result = service.publish(publish_body(first_chain.metadata_id));

  vault_repo.fail_next_create = true;
  REQUIRE_THROWS(service.publish(publish_body(second_chain.metadata_id)));

  // The first, already-committed entry's file must still exist.
  CHECK(std::filesystem::exists(first_result.vault_path));
  CHECK(vault_repo.list(VaultFilter{}).size() == 1);
}

TEST_CASE("ReferenceVaultService.get/list", "[vault][service]") {
  FakeVaultRepository vault_repo;
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;

  const auto artifact_path = make_scratch_file("contents");
  const auto chain = seed_chain(jobs, downloads, verifications, metadata_repo, artifact_path);

  oep::acquisition::common::StorageConfig storage;
  storage.root_path = (make_scratch_dir() / "reference_vault").string();
  ReferenceVaultService service(vault_repo, metadata_repo, verifications, downloads, jobs, storage);
  const auto created = service.publish(publish_body(chain.metadata_id));

  SECTION("get returns the entry") {
    const auto found = service.get(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
  }

  SECTION("get returns nullopt for an unknown id") {
    CHECK_FALSE(service.get("does-not-exist").has_value());
  }

  SECTION("list returns the entry") {
    CHECK(service.list(VaultFilter{}).size() == 1);
  }
}
