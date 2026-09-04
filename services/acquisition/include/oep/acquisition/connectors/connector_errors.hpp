#pragma once

#include <stdexcept>
#include <string>

namespace oep::acquisition::connectors {

/// Thrown by `ConnectorFactory::create` when `config.type` has no
/// registered creator (WORK_PACKAGE-005: "Unknown connector types shall
/// be rejected").
class UnknownConnectorTypeError : public std::runtime_error {
 public:
  explicit UnknownConnectorTypeError(const std::string& type)
      : std::runtime_error("Unknown connector type: " + type) {}
};

/// Thrown by `ConnectorRegistry::register_connector` when the
/// newly-constructed connector's `validate_configuration()` returns false
/// (WORK_PACKAGE-005: "Connector configuration shall validate before
/// registration").
class ConnectorValidationError : public std::runtime_error {
 public:
  explicit ConnectorValidationError(const std::string& connector_id)
      : std::runtime_error("Connector configuration did not validate: " + connector_id) {}
};

/// Thrown by `ConnectorRegistry::register_connector` when `connector_id`
/// is already registered (WORK_PACKAGE-005: "Connector IDs shall be
/// unique").
class DuplicateConnectorIdError : public std::runtime_error {
 public:
  explicit DuplicateConnectorIdError(const std::string& connector_id)
      : std::runtime_error("Connector id is already registered: " + connector_id) {}
};

}  // namespace oep::acquisition::connectors
