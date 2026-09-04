#include "oep/acquisition/metadata/metadata_extraction_service.hpp"

#include <chrono>
#include <cstdio>
#include <ctime>
#include <filesystem>
#include <system_error>

#include "oep/acquisition/common/time.hpp"
#include "oep/acquisition/metadata/artifact_metadata_errors.hpp"
#include "oep/acquisition/metadata/document_inspector.hpp"
#include "oep/acquisition/metadata/file_type_detector.hpp"
#include "oep/acquisition/metadata/validation.hpp"

namespace oep::acquisition::metadata {

namespace {

// Formats a filesystem modification time the same way
// `common::current_timestamp_utc()` formats the current time, so a
// `file_modified_at` value looks identical whether it came from disk or
// (in tests) from a hand-constructed timestamp.
std::string file_time_to_iso8601(std::filesystem::file_time_type file_time) {
  const auto system_time = std::chrono::clock_cast<std::chrono::system_clock>(file_time);
  const std::time_t time = std::chrono::system_clock::to_time_t(system_time);
  std::tm utc_tm{};
#ifdef _WIN32
  gmtime_s(&utc_tm, &time);
#else
  gmtime_r(&time, &utc_tm);
#endif
  char buffer[32];
  std::strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &utc_tm);
  return buffer;
}

std::string derive_extension(const std::string& file_name) {
  std::string extension = std::filesystem::path(file_name).extension().string();
  if (!extension.empty() && extension.front() == '.') {
    extension.erase(0, 1);
  }
  return extension;
}

}  // namespace

MetadataExtractionService::MetadataExtractionService(IMetadataRepository& metadata,
                                                        integrity::IVerificationRepository& verifications,
                                                        downloads::IDownloadRepository& downloads)
    : metadata_(metadata), verifications_(verifications), downloads_(downloads) {}

ArtifactMetadata MetadataExtractionService::extract(const nlohmann::json& body) {
  const CreateMetadataRequest request = parse_and_validate_create(body);

  const auto verification = verifications_.find_by_id(request.verification_id);
  if (!verification.has_value()) {
    throw UnknownVerificationError(request.verification_id);
  }
  if (verification->status != integrity::VerificationStatus::Verified) {
    throw VerificationNotSuccessfulError(request.verification_id, integrity::to_string(verification->status));
  }

  const auto download = downloads_.find_by_id(verification->download_session_id);

  ArtifactMetadata metadata;
  metadata.verification_id = request.verification_id;
  metadata.file_name = download.has_value() ? download->file_name : "";
  metadata.file_extension = derive_extension(metadata.file_name);
  metadata.sha256_hash = verification->sha256_hash;
  metadata.file_size_bytes = verification->file_size_bytes;
  metadata.status = ExtractionStatus::Pending;
  ArtifactMetadata created = metadata_.create(metadata);

  ArtifactMetadata finalized = created;
  finalized.extracted_at = common::current_timestamp_utc();

  const std::filesystem::path artifact_path =
      download.has_value() ? std::filesystem::path(download->local_storage_path) : std::filesystem::path();

  if (!download.has_value() || artifact_path.empty() || !std::filesystem::exists(artifact_path)) {
    finalized.status = ExtractionStatus::Failed;
    finalized.error_message = "Downloaded artifact does not exist: " + artifact_path.string();
  } else {
    const FileTypeInfo file_type = detect_file_type(artifact_path);
    finalized.mime_type = file_type.mime_type;

    if (file_type.type_name == "PDF") {
      const PdfProperties pdf = inspect_pdf(artifact_path);
      finalized.pdf_version = pdf.version;
      finalized.pdf_page_count = pdf.page_count;
    }

    std::error_code error;
    const auto last_write = std::filesystem::last_write_time(artifact_path, error);
    if (!error) {
      finalized.file_modified_at = file_time_to_iso8601(last_write);
    }

    finalized.status = ExtractionStatus::Extracted;
  }

  return metadata_.update(created.id, finalized).value_or(finalized);
}

std::optional<ArtifactMetadata> MetadataExtractionService::get(const std::string& id) {
  return metadata_.find_by_id(id);
}

std::vector<ArtifactMetadata> MetadataExtractionService::list(const MetadataFilter& filter) {
  return metadata_.list(filter);
}

}  // namespace oep::acquisition::metadata
