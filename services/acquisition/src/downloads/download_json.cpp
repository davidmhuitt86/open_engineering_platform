#include "oep/acquisition/downloads/download_json.hpp"

namespace oep::acquisition::downloads {

namespace {

nlohmann::json optional_to_json(const std::optional<std::string>& value) {
  return value.has_value() ? nlohmann::json(*value) : nullptr;
}

}  // namespace

nlohmann::json to_json(const Download& download) {
  // WP-SRV-002: `local_storage_path` is a server-local filesystem path and
  // must never appear in the public API (see ADR-0001 Section 6). It
  // remains on the `Download` struct for internal use (e.g. by
  // `ReferenceVaultService`).
  return nlohmann::json{
      {"id", download.id},
      {"job_id", download.job_id},
      {"connector_id", download.connector_id},
      {"source_uri", download.source_uri},
      {"file_name", download.file_name},
      {"mime_type", download.mime_type},
      {"file_size_bytes", download.file_size_bytes},
      {"status", to_string(download.status)},
      {"progress_percentage", download.progress_percentage},
      {"started_at", optional_to_json(download.started_at)},
      {"completed_at", optional_to_json(download.completed_at)},
      {"error_message", optional_to_json(download.error_message)},
      {"created_at", download.created_at},
      {"updated_at", download.updated_at},
  };
}

nlohmann::json status_to_json(const Download& download) {
  return nlohmann::json{
      {"id", download.id},
      {"status", to_string(download.status)},
      {"progress_percentage", download.progress_percentage},
      {"started_at", optional_to_json(download.started_at)},
      {"completed_at", optional_to_json(download.completed_at)},
      {"error_message", optional_to_json(download.error_message)},
  };
}

}  // namespace oep::acquisition::downloads
