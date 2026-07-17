#include "oep/acquisition/metadata/artifact_metadata_json.hpp"

namespace oep::acquisition::metadata {

namespace {

nlohmann::json optional_to_json(const std::optional<std::string>& value) {
  return value.has_value() ? nlohmann::json(*value) : nullptr;
}

nlohmann::json optional_to_json(const std::optional<int>& value) {
  return value.has_value() ? nlohmann::json(*value) : nullptr;
}

}  // namespace

nlohmann::json to_json(const ArtifactMetadata& metadata) {
  return nlohmann::json{
      {"id", metadata.id},
      {"verification_id", metadata.verification_id},
      {"file_name", metadata.file_name},
      {"file_extension", metadata.file_extension},
      {"mime_type", metadata.mime_type},
      {"file_size_bytes", metadata.file_size_bytes},
      {"sha256_hash", metadata.sha256_hash},
      {"file_created_at", optional_to_json(metadata.file_created_at)},
      {"file_modified_at", optional_to_json(metadata.file_modified_at)},
      {"pdf_version", optional_to_json(metadata.pdf_version)},
      {"pdf_page_count", optional_to_json(metadata.pdf_page_count)},
      {"status", to_string(metadata.status)},
      {"extracted_at", optional_to_json(metadata.extracted_at)},
      {"error_message", optional_to_json(metadata.error_message)},
      {"created_at", metadata.created_at},
      {"updated_at", metadata.updated_at},
  };
}

nlohmann::json status_to_json(const ArtifactMetadata& metadata) {
  return nlohmann::json{
      {"id", metadata.id},
      {"status", to_string(metadata.status)},
      {"extracted_at", optional_to_json(metadata.extracted_at)},
      {"error_message", optional_to_json(metadata.error_message)},
  };
}

}  // namespace oep::acquisition::metadata
