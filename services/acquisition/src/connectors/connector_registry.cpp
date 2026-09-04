#include "oep/acquisition/connectors/connector_registry.hpp"

#include "oep/acquisition/connectors/connector_errors.hpp"

namespace oep::acquisition::connectors {

ConnectorRegistry::ConnectorRegistry(const ConnectorFactory& factory) : factory_(factory) {}

IConnector& ConnectorRegistry::register_connector(const ConnectorConfig& config) {
  if (connectors_.contains(config.connector_id)) {
    throw DuplicateConnectorIdError(config.connector_id);
  }

  std::unique_ptr<IConnector> connector = factory_.create(config);  // throws UnknownConnectorTypeError

  if (!connector->validate_configuration()) {
    throw ConnectorValidationError(config.connector_id);
  }

  IConnector& ref = *connector;
  connectors_.emplace(config.connector_id, std::move(connector));
  return ref;
}

IConnector* ConnectorRegistry::resolve(const std::string& connector_id) const {
  const auto it = connectors_.find(connector_id);
  if (it == connectors_.end()) {
    return nullptr;
  }
  return it->second.get();
}

std::vector<IConnector*> ConnectorRegistry::list() const {
  std::vector<IConnector*> result;
  result.reserve(connectors_.size());
  for (const auto& [id, connector] : connectors_) {
    result.push_back(connector.get());
  }
  return result;
}

}  // namespace oep::acquisition::connectors
