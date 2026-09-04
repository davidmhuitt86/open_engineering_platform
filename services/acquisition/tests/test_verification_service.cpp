#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>

#include "fake_download_repository.hpp"
#include "fake_verification_repository.hpp"
#include "oep/acquisition/downloads/download.hpp"
#include "oep/acquisition/integrity/integrity_verification_service.hpp"
#include "oep/acquisition/integrity/validation.hpp"
#include "oep/acquisition/integrity/verification_errors.hpp"

using namespace oep::acquisition::integrity;
using oep::acquisition::downloads::Download;
using oep::acquisition::downloads::DownloadStatus;
using oep::acquisition::test_support::FakeDownloadRepository;
using oep::acquisition::test_support::FakeVerificationRepository;

namespace {

std::filesystem::path make_scratch_file(const std::string& contents) {
  static std::atomic<int> counter{0};
  const auto dir =
      std::filesystem::temp_directory_path() / ("oep_verification_service_test_" + std::to_string(++counter));
  std::filesystem::create_directories(dir);
  const auto path = dir / "artifact.bin";
  std::ofstream(path, std::ios::binary) << contents;
  return path;
}

Download seed_download(FakeDownloadRepository& downloads, const std::string& local_storage_path,
                         std::uint64_t file_size_bytes) {
  Download download;
  download.job_id = "job-1";
  download.connector_id = "conn-1";
  download.source_uri = "stub://example/artifact.bin";
  download.local_storage_path = local_storage_path;
  download.file_size_bytes = file_size_bytes;
  download.status = DownloadStatus::Completed;
  return downloads.create(download);
}

nlohmann::json verify_body(const std::string& download_session_id) {
  return nlohmann::json{{"download_session_id", download_session_id}};
}

}  // namespace

TEST_CASE("IntegrityVerificationService.verify records Verified for a healthy artifact",
          "[integrity][service]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("a real engineering artifact");
  const auto download = seed_download(downloads, path.string(), 27);

  IntegrityVerificationService service(verifications, downloads);
  const auto result = service.verify(verify_body(download.id));

  CHECK(result.status == VerificationStatus::Verified);
  CHECK_FALSE(result.sha256_hash.empty());
  CHECK(result.file_size_bytes == 27);
  CHECK(result.verified_at.has_value());
  CHECK_FALSE(result.error_message.has_value());
}

TEST_CASE("IntegrityVerificationService.verify throws ValidationError for a malformed body",
          "[integrity][service]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  IntegrityVerificationService service(verifications, downloads);

  CHECK_THROWS_AS(service.verify(nlohmann::json::object()), ValidationError);
}

TEST_CASE("IntegrityVerificationService.verify throws UnknownDownloadSessionError for a nonexistent session",
          "[integrity][service]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  IntegrityVerificationService service(verifications, downloads);

  CHECK_THROWS_AS(service.verify(verify_body("does-not-exist")), UnknownDownloadSessionError);
}

TEST_CASE("IntegrityVerificationService.verify records Failed for a missing artifact",
          "[integrity][service][missing-file]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto dir = std::filesystem::temp_directory_path() / "oep_verification_missing_test";
  std::filesystem::create_directories(dir);
  const auto missing_path = dir / "does-not-exist.bin";
  const auto download = seed_download(downloads, missing_path.string(), 10);

  IntegrityVerificationService service(verifications, downloads);
  const auto result = service.verify(verify_body(download.id));

  CHECK(result.status == VerificationStatus::Failed);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("does not exist") != std::string::npos);
  CHECK(result.verified_at.has_value());
}

TEST_CASE("IntegrityVerificationService.verify records Failed for a corrupt (unreadable) artifact",
          "[integrity][service][corrupt-file]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  // A directory path exists but cannot be read as artifact content -- the
  // Corrupt Files case, distinct from Missing Files.
  const auto dir = std::filesystem::temp_directory_path() / "oep_verification_corrupt_test";
  std::filesystem::create_directories(dir);
  const auto download = seed_download(downloads, dir.string(), 10);

  IntegrityVerificationService service(verifications, downloads);
  const auto result = service.verify(verify_body(download.id));

  CHECK(result.status == VerificationStatus::Failed);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("could not be read") != std::string::npos);
}

TEST_CASE("IntegrityVerificationService.verify records Failed for an empty artifact",
          "[integrity][service]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("");
  const auto download = seed_download(downloads, path.string(), 0);

  IntegrityVerificationService service(verifications, downloads);
  const auto result = service.verify(verify_body(download.id));

  CHECK(result.status == VerificationStatus::Failed);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("empty") != std::string::npos);
  // "SHA-256 shall always be generated" -- even a failing (empty) artifact
  // still gets a computed hash if it could be read at all.
  CHECK_FALSE(result.sha256_hash.empty());
}

TEST_CASE("IntegrityVerificationService.verify re-verifies against a prior hash and detects corruption",
          "[integrity][service]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("original contents");
  const auto download = seed_download(downloads, path.string(), 18);

  IntegrityVerificationService service(verifications, downloads);
  const auto first = service.verify(verify_body(download.id));
  REQUIRE(first.status == VerificationStatus::Verified);

  // Mutate the artifact on disk after the first, successful verification --
  // a second verification of the same download session should now detect
  // the drift and flag it as Failed (WORK_PACKAGE-007's "Verify Existing
  // Hashes" / "Detect Corrupt Files").
  std::ofstream(path, std::ios::binary | std::ios::trunc) << "tampered contents";

  const auto second = service.verify(verify_body(download.id));
  CHECK(second.status == VerificationStatus::Failed);
  REQUIRE(second.error_message.has_value());
  CHECK(second.error_message->find("does not match previously verified hash") != std::string::npos);
}

TEST_CASE("IntegrityVerificationService.verify re-verifies an unchanged artifact as Verified again",
          "[integrity][service]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("stable contents");
  const auto download = seed_download(downloads, path.string(), 16);

  IntegrityVerificationService service(verifications, downloads);
  const auto first = service.verify(verify_body(download.id));
  REQUIRE(first.status == VerificationStatus::Verified);

  const auto second = service.verify(verify_body(download.id));
  CHECK(second.status == VerificationStatus::Verified);
  CHECK(second.sha256_hash == first.sha256_hash);
}

TEST_CASE("IntegrityVerificationService.get/list", "[integrity][service]") {
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("contents");
  const auto download = seed_download(downloads, path.string(), 8);

  IntegrityVerificationService service(verifications, downloads);
  const auto created = service.verify(verify_body(download.id));

  SECTION("get returns the verification") {
    const auto found = service.get(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
  }

  SECTION("get returns nullopt for an unknown id") {
    CHECK_FALSE(service.get("does-not-exist").has_value());
  }

  SECTION("list returns the verification") {
    CHECK(service.list(VerificationFilter{}).size() == 1);
  }
}
