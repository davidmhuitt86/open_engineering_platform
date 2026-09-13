#include <catch2/catch_test_macros.hpp>

#include "fake_acquisition_job_repository.hpp"
#include "fake_acquisition_record_repository.hpp"
#include "fake_download_repository.hpp"
#include "fake_job_execution_history_repository.hpp"
#include "fake_metadata_repository.hpp"
#include "fake_official_source_repository.hpp"
#include "fake_verification_repository.hpp"
#include "fake_vault_repository.hpp"
#include "oep/acquisition/provenance/acquisition_record_repository.hpp"
#include "oep/acquisition/provenance/acquisition_record_service.hpp"

using namespace oep::acquisition::provenance;
using oep::acquisition::downloads::Download;
using oep::acquisition::downloads::DownloadStatus;
using oep::acquisition::integrity::Verification;
using oep::acquisition::integrity::VerificationStatus;
using oep::acquisition::metadata::ArtifactMetadata;
using oep::acquisition::metadata::ExtractionStatus;
using oep::acquisition::test_support::FakeAcquisitionRecordRepository;
using oep::acquisition::test_support::FakeAcquisitionJobRepository;
using oep::acquisition::test_support::FakeDownloadRepository;
using oep::acquisition::test_support::FakeJobExecutionHistoryRepository;
using oep::acquisition::test_support::FakeMetadataRepository;
using oep::acquisition::test_support::FakeOfficialSourceRepository;
using oep::acquisition::test_support::FakeVaultRepository;
using oep::acquisition::test_support::FakeVerificationRepository;
using oep::acquisition::vault::VaultEntry;
using oep::acquisition::vault::VaultEntryStatus;

namespace {

struct Fixture {
  FakeAcquisitionRecordRepository records;
  FakeDownloadRepository downloads;
  FakeAcquisitionJobRepository jobs;
  FakeJobExecutionHistoryRepository job_history;
  FakeVerificationRepository verifications;
  FakeMetadataRepository metadata;
  FakeVaultRepository vault;
  FakeOfficialSourceRepository sources;

  AcquisitionRecordService make_service() {
    return AcquisitionRecordService(records, downloads, jobs, job_history, verifications, metadata, vault,
                                     sources);
  }
};

Download make_completed_download() {
  Download download;
  download.id = "download-1";
  download.job_id = "job-1";
  download.connector_id = "example-stub";
  download.source_uri = "stub://example/artifact.pdf";
  download.status = DownloadStatus::Completed;
  return download;
}

}  // namespace

TEST_CASE("AcquisitionRecordService.record_download_outcome creates an Acquired record on success",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  const auto download = make_completed_download();
  const auto record = service.record_download_outcome(download);

  CHECK_FALSE(record.id.empty());
  CHECK(record.download_session_id == download.id);
  CHECK(record.status == AcquisitionRecordStatus::Acquired);
  CHECK_FALSE(record.error_message.has_value());
}

TEST_CASE("AcquisitionRecordService.record_download_outcome creates a Failed record with the download's error",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  Download download = make_completed_download();
  download.status = DownloadStatus::Failed;
  download.error_message = "connector reported failure";

  const auto record = service.record_download_outcome(download);

  CHECK(record.status == AcquisitionRecordStatus::Failed);
  REQUIRE(record.error_message.has_value());
  CHECK(*record.error_message == "connector reported failure");
}

TEST_CASE("AcquisitionRecordService.record_download_outcome rejects a second call for the same Download Session",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  const auto download = make_completed_download();
  service.record_download_outcome(download);

  CHECK_THROWS_AS(service.record_download_outcome(download), DuplicateAcquisitionRecordError);
}

TEST_CASE("AcquisitionRecordService.record_verification_outcome advances an Acquired record to Verified",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  const auto download = make_completed_download();
  service.record_download_outcome(download);

  Verification verification;
  verification.download_session_id = download.id;
  verification.status = VerificationStatus::Verified;

  const auto updated = service.record_verification_outcome(verification);
  REQUIRE(updated.has_value());
  CHECK(updated->status == AcquisitionRecordStatus::Verified);
}

TEST_CASE("AcquisitionRecordService.record_verification_outcome advances a record to Failed on failed verification",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  const auto download = make_completed_download();
  service.record_download_outcome(download);

  Verification verification;
  verification.download_session_id = download.id;
  verification.status = VerificationStatus::Failed;
  verification.error_message = "hash mismatch";

  const auto updated = service.record_verification_outcome(verification);
  REQUIRE(updated.has_value());
  CHECK(updated->status == AcquisitionRecordStatus::Failed);
  REQUIRE(updated->error_message.has_value());
  CHECK(*updated->error_message == "hash mismatch");
}

TEST_CASE("AcquisitionRecordService.record_verification_outcome is a no-op when no record exists for the download",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  Verification verification;
  verification.download_session_id = "download-without-a-record";
  verification.status = VerificationStatus::Verified;

  CHECK_FALSE(service.record_verification_outcome(verification).has_value());
}

TEST_CASE("AcquisitionRecordService.record_metadata_outcome only advances the record on failure",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  const auto download = make_completed_download();
  service.record_download_outcome(download);

  Verification verification;
  verification.download_session_id = download.id;
  verification.status = VerificationStatus::Verified;
  const auto created_verification = fixture.verifications.create(verification);
  service.record_verification_outcome(created_verification);

  SECTION("successful extraction leaves the record Verified") {
    ArtifactMetadata item;
    item.verification_id = created_verification.id;
    item.status = ExtractionStatus::Extracted;

    CHECK_FALSE(service.record_metadata_outcome(item).has_value());
    const auto record = fixture.records.find_by_download_session_id(download.id);
    REQUIRE(record.has_value());
    CHECK(record->status == AcquisitionRecordStatus::Verified);
  }

  SECTION("failed extraction advances the record to Failed") {
    ArtifactMetadata item;
    item.verification_id = created_verification.id;
    item.status = ExtractionStatus::Failed;
    item.error_message = "unreadable artifact";

    const auto updated = service.record_metadata_outcome(item);
    REQUIRE(updated.has_value());
    CHECK(updated->status == AcquisitionRecordStatus::Failed);
    REQUIRE(updated->error_message.has_value());
    CHECK(*updated->error_message == "unreadable artifact");
  }
}

TEST_CASE("AcquisitionRecordService.record_vault_publication advances a Verified record to Published",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  const auto download = make_completed_download();
  service.record_download_outcome(download);

  Verification verification;
  verification.download_session_id = download.id;
  verification.status = VerificationStatus::Verified;
  const auto created_verification = fixture.verifications.create(verification);
  service.record_verification_outcome(created_verification);

  VaultEntry entry;
  entry.metadata_id = "metadata-1";
  entry.verification_id = created_verification.id;
  entry.download_session_id = download.id;
  entry.status = VaultEntryStatus::Published;

  const auto updated = service.record_vault_publication(entry);
  REQUIRE(updated.has_value());
  CHECK(updated->status == AcquisitionRecordStatus::Published);
}

TEST_CASE("AcquisitionRecordService.get_provenance traverses the full chain from a Download Session",
          "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  auto source = fixture.sources.create(oep::acquisition::registry::OfficialSource{});
  auto job = fixture.jobs.create([&] {
    oep::acquisition::acquisition::AcquisitionJob job;
    job.source_id = source.id;
    job.name = "Acquire 802.11";
    return job;
  }());

  auto download = make_completed_download();
  download.job_id = job.id;
  download = fixture.downloads.create(download);
  const auto record = service.record_download_outcome(download);

  Verification verification;
  verification.download_session_id = download.id;
  verification.status = VerificationStatus::Verified;
  const auto created_verification = fixture.verifications.create(verification);
  service.record_verification_outcome(created_verification);

  ArtifactMetadata item;
  item.verification_id = created_verification.id;
  item.status = ExtractionStatus::Extracted;
  const auto created_metadata = fixture.metadata.create(item);

  VaultEntry entry;
  entry.metadata_id = created_metadata.id;
  entry.verification_id = created_verification.id;
  entry.download_session_id = download.id;
  entry.status = VaultEntryStatus::Published;
  const auto created_entry = fixture.vault.create(entry);
  service.record_vault_publication(created_entry);

  const auto provenance = service.get_provenance(record.id);
  REQUIRE(provenance.has_value());
  CHECK(provenance->at("acquisition_record").at("status") == "published");
  CHECK(provenance->at("download").at("id") == download.id);
  CHECK(provenance->at("job").at("id") == job.id);
  CHECK(provenance->at("source").at("id") == source.id);
  CHECK(provenance->at("verifications").size() == 1);
  CHECK(provenance->at("metadata").size() == 1);
  CHECK_FALSE(provenance->at("vault_entry").is_null());
  CHECK(provenance->at("vault_entry").at("id") == created_entry.id);
}

TEST_CASE("AcquisitionRecordService.get_provenance returns nullopt for an unknown id", "[provenance][service]") {
  Fixture fixture;
  auto service = fixture.make_service();

  CHECK_FALSE(service.get_provenance("does-not-exist").has_value());
}
