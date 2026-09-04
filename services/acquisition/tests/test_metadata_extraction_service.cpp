#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>

#include "fake_download_repository.hpp"
#include "fake_metadata_repository.hpp"
#include "fake_verification_repository.hpp"
#include "oep/acquisition/downloads/download.hpp"
#include "oep/acquisition/integrity/verification.hpp"
#include "oep/acquisition/metadata/artifact_metadata_errors.hpp"
#include "oep/acquisition/metadata/metadata_extraction_service.hpp"
#include "oep/acquisition/metadata/validation.hpp"

using namespace oep::acquisition::metadata;
using oep::acquisition::downloads::Download;
using oep::acquisition::downloads::DownloadStatus;
using oep::acquisition::integrity::Verification;
using oep::acquisition::integrity::VerificationStatus;
using oep::acquisition::test_support::FakeDownloadRepository;
using oep::acquisition::test_support::FakeMetadataRepository;
using oep::acquisition::test_support::FakeVerificationRepository;

namespace {

std::filesystem::path make_scratch_file(const std::string& file_name, const std::string& contents) {
  static std::atomic<int> counter{0};
  const auto dir = std::filesystem::temp_directory_path() /
                     ("oep_metadata_service_test_" + std::to_string(++counter));
  std::filesystem::create_directories(dir);
  const auto path = dir / file_name;
  std::ofstream(path, std::ios::binary) << contents;
  return path;
}

Download seed_download(FakeDownloadRepository& downloads, const std::string& file_name,
                         const std::string& local_storage_path) {
  Download download;
  download.job_id = "job-1";
  download.connector_id = "conn-1";
  download.source_uri = "stub://example/" + file_name;
  download.file_name = file_name;
  download.local_storage_path = local_storage_path;
  download.status = DownloadStatus::Completed;
  return downloads.create(download);
}

Verification seed_verification(FakeVerificationRepository& verifications, const std::string& download_id,
                                 VerificationStatus status = VerificationStatus::Verified,
                                 const std::string& sha256_hash = "abc123",
                                 std::uint64_t file_size_bytes = 42) {
  Verification verification;
  verification.download_session_id = download_id;
  verification.status = status;
  verification.sha256_hash = sha256_hash;
  verification.file_size_bytes = file_size_bytes;
  return verifications.create(verification);
}

nlohmann::json extract_body(const std::string& verification_id) {
  return nlohmann::json{{"verification_id", verification_id}};
}

}  // namespace

TEST_CASE("MetadataExtractionService.extract records Extracted for a healthy artifact",
          "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("notes.txt", "some plain text content");
  const auto download = seed_download(downloads, "notes.txt", path.string());
  const auto verification = seed_verification(verifications, download.id, VerificationStatus::Verified,
                                                 "deadbeef", 23);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  const auto result = service.extract(extract_body(verification.id));

  CHECK(result.status == ExtractionStatus::Extracted);
  CHECK(result.file_name == "notes.txt");
  CHECK(result.file_extension == "txt");
  CHECK(result.mime_type == "text/plain");
  CHECK(result.sha256_hash == "deadbeef");
  CHECK(result.file_size_bytes == 23);
  CHECK(result.extracted_at.has_value());
  CHECK_FALSE(result.error_message.has_value());
}

TEST_CASE("MetadataExtractionService.extract throws ValidationError for a malformed body",
          "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  MetadataExtractionService service(metadata_repo, verifications, downloads);

  CHECK_THROWS_AS(service.extract(nlohmann::json::object()), ValidationError);
}

TEST_CASE("MetadataExtractionService.extract throws UnknownVerificationError for a nonexistent verification",
          "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;
  MetadataExtractionService service(metadata_repo, verifications, downloads);

  CHECK_THROWS_AS(service.extract(extract_body("does-not-exist")), UnknownVerificationError);
}

TEST_CASE("MetadataExtractionService.extract throws VerificationNotSuccessfulError for a Pending verification",
          "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto download = seed_download(downloads, "artifact.bin", "/tmp/does-not-matter.bin");
  const auto verification = seed_verification(verifications, download.id, VerificationStatus::Pending);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  CHECK_THROWS_AS(service.extract(extract_body(verification.id)), VerificationNotSuccessfulError);
}

TEST_CASE("MetadataExtractionService.extract throws VerificationNotSuccessfulError for a Failed verification",
          "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto download = seed_download(downloads, "artifact.bin", "/tmp/does-not-matter.bin");
  const auto verification = seed_verification(verifications, download.id, VerificationStatus::Failed);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  CHECK_THROWS_AS(service.extract(extract_body(verification.id)), VerificationNotSuccessfulError);
}

TEST_CASE("MetadataExtractionService.extract records Failed for a missing artifact",
          "[metadata][service][missing-file]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto dir = std::filesystem::temp_directory_path() / "oep_metadata_missing_test";
  std::filesystem::create_directories(dir);
  const auto missing_path = dir / "does-not-exist.bin";
  const auto download = seed_download(downloads, "artifact.bin", missing_path.string());
  const auto verification = seed_verification(verifications, download.id);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  const auto result = service.extract(extract_body(verification.id));

  CHECK(result.status == ExtractionStatus::Failed);
  REQUIRE(result.error_message.has_value());
  CHECK(result.error_message->find("does not exist") != std::string::npos);
  CHECK(result.extracted_at.has_value());
  // Even on failure, fields already known from the Download/Verification
  // records are still populated -- only the disk-derived fields are
  // missing.
  CHECK(result.file_name == "artifact.bin");
  CHECK_FALSE(result.sha256_hash.empty());
}

TEST_CASE("MetadataExtractionService.extract records Extracted with type Unknown for an unsupported file",
          "[metadata][service][unsupported-file-type]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("mystery.xyz", "content matching no known signature or extension");
  const auto download = seed_download(downloads, "mystery.xyz", path.string());
  const auto verification = seed_verification(verifications, download.id);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  const auto result = service.extract(extract_body(verification.id));

  CHECK(result.status == ExtractionStatus::Extracted);
  CHECK(result.mime_type == "application/octet-stream");
  CHECK_FALSE(result.error_message.has_value());
}

TEST_CASE("MetadataExtractionService.extract runs Basic Document Inspection for a PDF artifact",
          "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file(
      "manual.pdf", "%PDF-1.6\n3 0 obj\n<< /Type /Pages /Count 5 >>\nendobj\n");
  const auto download = seed_download(downloads, "manual.pdf", path.string());
  const auto verification = seed_verification(verifications, download.id);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  const auto result = service.extract(extract_body(verification.id));

  CHECK(result.status == ExtractionStatus::Extracted);
  CHECK(result.mime_type == "application/pdf");
  REQUIRE(result.pdf_version.has_value());
  CHECK(*result.pdf_version == "1.6");
  REQUIRE(result.pdf_page_count.has_value());
  CHECK(*result.pdf_page_count == 5);
}

TEST_CASE("MetadataExtractionService.get/list", "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("notes.txt", "content");
  const auto download = seed_download(downloads, "notes.txt", path.string());
  const auto verification = seed_verification(verifications, download.id);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  const auto created = service.extract(extract_body(verification.id));

  SECTION("get returns the record") {
    const auto found = service.get(created.id);
    REQUIRE(found.has_value());
    CHECK(found->id == created.id);
  }

  SECTION("get returns nullopt for an unknown id") {
    CHECK_FALSE(service.get("does-not-exist").has_value());
  }

  SECTION("list returns the record") {
    CHECK(service.list(MetadataFilter{}).size() == 1);
  }
}

TEST_CASE("MetadataExtractionService.extract preserves history across re-extraction", "[metadata][service]") {
  FakeMetadataRepository metadata_repo;
  FakeVerificationRepository verifications;
  FakeDownloadRepository downloads;

  const auto path = make_scratch_file("notes.txt", "content");
  const auto download = seed_download(downloads, "notes.txt", path.string());
  const auto verification = seed_verification(verifications, download.id);

  MetadataExtractionService service(metadata_repo, verifications, downloads);
  const auto first = service.extract(extract_body(verification.id));
  const auto second = service.extract(extract_body(verification.id));

  CHECK(first.id != second.id);
  const auto history = service.list(MetadataFilter{.verification_id = verification.id});
  CHECK(history.size() == 2);
}
