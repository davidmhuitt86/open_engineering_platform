#include "oep/acquisition/provenance/acquisition_record_json.hpp"

namespace oep::acquisition::provenance {

namespace {

nlohmann::json optional_to_json(const std::optional<std::string>& value) {
  return value.has_value() ? nlohmann::json(*value) : nullptr;
}

}  // namespace

nlohmann::json to_json(const AcquisitionRecord& record) {
  return nlohmann::json{
      {"id", record.id},
      {"download_session_id", record.download_session_id},
      {"status", to_string(record.status)},
      {"error_message", optional_to_json(record.error_message)},
      {"created_at", record.created_at},
      {"updated_at", record.updated_at},
  };
}

}  // namespace oep::acquisition::provenance
