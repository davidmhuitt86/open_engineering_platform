#pragma once

#include <nlohmann/json.hpp>
#include <set>
#include <string>

#include "oep/acquisition/connectors/connector.hpp"

namespace oep::acquisition::connectors {

/// Full JSON representation used for `GET /connectors` and
/// `GET /connectors/{id}` responses.
[[nodiscard]] nlohmann::json to_json(const ConnectorConfig& config);

/// `GET /connectors/{id}/capabilities` response body.
[[nodiscard]] nlohmann::json capabilities_to_json(const std::string& connector_id,
                                                     const std::set<std::string>& capabilities);

/// `GET /connectors/{id}/health` response body.
[[nodiscard]] nlohmann::json health_to_json(const std::string& connector_id, const HealthCheckResult& result);

}  // namespace oep::acquisition::connectors
