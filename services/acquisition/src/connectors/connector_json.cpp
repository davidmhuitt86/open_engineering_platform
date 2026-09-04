#include "oep/acquisition/connectors/connector_json.hpp"

namespace oep::acquisition::connectors {

nlohmann::json to_json(const ConnectorConfig& config) {
  return nlohmann::json{
      {"id", config.connector_id},
      {"type", config.type},
      {"name", config.name},
      {"description", config.description},
      {"settings", config.settings},
  };
}

nlohmann::json capabilities_to_json(const std::string& connector_id, const std::set<std::string>& capabilities) {
  return nlohmann::json{
      {"id", connector_id},
      {"capabilities", capabilities},
  };
}

nlohmann::json health_to_json(const std::string& connector_id, const HealthCheckResult& result) {
  return nlohmann::json{
      {"id", connector_id},
      {"status", to_string(result.status)},
      {"message", result.message},
      {"checked_at", result.checked_at},
  };
}

}  // namespace oep::acquisition::connectors
