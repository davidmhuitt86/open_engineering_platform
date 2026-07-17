#include "oep/acquisition/connectors/connector_factory.hpp"

#include "oep/acquisition/connectors/connector_errors.hpp"

namespace oep::acquisition::connectors {

void ConnectorFactory::register_type(const std::string& type, Creator creator) {
  creators_[type] = std::move(creator);
}

bool ConnectorFactory::has_type(const std::string& type) const {
  return creators_.contains(type);
}

std::unique_ptr<IConnector> ConnectorFactory::create(const ConnectorConfig& config) const {
  const auto it = creators_.find(config.type);
  if (it == creators_.end()) {
    throw UnknownConnectorTypeError(config.type);
  }
  return it->second(config);
}

}  // namespace oep::acquisition::connectors
