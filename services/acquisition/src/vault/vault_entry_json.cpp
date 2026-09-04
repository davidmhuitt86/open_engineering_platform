#include "oep/acquisition/vault/vault_entry_json.hpp"

namespace oep::acquisition::vault {

nlohmann::json to_json(const VaultEntry& entry) {
  return nlohmann::json{
      {"id", entry.id},
      {"metadata_id", entry.metadata_id},
      {"verification_id", entry.verification_id},
      {"download_session_id", entry.download_session_id},
      {"source_id", entry.source_id},
      {"vault_path", entry.vault_path},
      {"sha256_hash", entry.sha256_hash},
      {"mime_type", entry.mime_type},
      {"file_size_bytes", entry.file_size_bytes},
      {"status", to_string(entry.status)},
      {"published_at", entry.published_at},
      {"created_at", entry.created_at},
      {"updated_at", entry.updated_at},
  };
}

nlohmann::json status_to_json(const VaultEntry& entry) {
  return nlohmann::json{
      {"id", entry.id},
      {"status", to_string(entry.status)},
      {"sha256_hash", entry.sha256_hash},
      {"published_at", entry.published_at},
  };
}

}  // namespace oep::acquisition::vault
