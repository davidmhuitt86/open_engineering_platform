#include "oep/acquisition/integrity/verification_json.hpp"

namespace oep::acquisition::integrity {

namespace {

nlohmann::json optional_to_json(const std::optional<std::string>& value) {
  return value.has_value() ? nlohmann::json(*value) : nullptr;
}

}  // namespace

nlohmann::json to_json(const Verification& verification) {
  return nlohmann::json{
      {"id", verification.id},
      {"download_session_id", verification.download_session_id},
      {"status", to_string(verification.status)},
      {"sha256_hash", verification.sha256_hash},
      {"file_size_bytes", verification.file_size_bytes},
      {"verified_at", optional_to_json(verification.verified_at)},
      {"error_message", optional_to_json(verification.error_message)},
      {"created_at", verification.created_at},
      {"updated_at", verification.updated_at},
  };
}

nlohmann::json status_to_json(const Verification& verification) {
  return nlohmann::json{
      {"id", verification.id},
      {"status", to_string(verification.status)},
      {"sha256_hash", verification.sha256_hash},
      {"verified_at", optional_to_json(verification.verified_at)},
      {"error_message", optional_to_json(verification.error_message)},
  };
}

}  // namespace oep::acquisition::integrity
