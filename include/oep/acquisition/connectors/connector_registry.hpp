#pragma once

#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "oep/acquisition/connectors/connector.hpp"
#include "oep/acquisition/connectors/connector_factory.hpp"

namespace oep::acquisition::connectors {

/// Holds every registered `IConnector` instance, keyed by
/// `ConnectorConfig::connector_id`. In-memory only -- WORK_PACKAGE-005
/// asks for a Flyway migration "only if persistent connector
/// configuration metadata is required," and since connectors are
/// registered by `main.cpp` at startup rather than through the (entirely
/// read-only) REST API, no such requirement exists yet; see README.md
/// "Implementation Decisions".
class ConnectorRegistry {
 public:
  explicit ConnectorRegistry(const ConnectorFactory& factory);

  /// Constructs a connector of the type named in `config.type` via the
  /// Factory, validates it, and adds it to the registry. Returns a
  /// reference to the now-registered connector (owned by the registry).
  ///
  /// Throws (WORK_PACKAGE-005 "Validation Rules", checked in this order):
  /// - DuplicateConnectorIdError if `config.connector_id` is already
  ///   registered ("Connector IDs shall be unique").
  /// - UnknownConnectorTypeError if `config.type` has no registered
  ///   Factory creator ("Unknown connector types shall be rejected").
  /// - ConnectorValidationError if the constructed connector's
  ///   `validate_configuration()` returns false ("Connector
  ///   configuration shall validate before registration").
  IConnector& register_connector(const ConnectorConfig& config);

  /// nullptr if `connector_id` is not registered.
  [[nodiscard]] IConnector* resolve(const std::string& connector_id) const;

  [[nodiscard]] std::vector<IConnector*> list() const;

 private:
  const ConnectorFactory& factory_;
  std::unordered_map<std::string, std::unique_ptr<IConnector>> connectors_;
};

}  // namespace oep::acquisition::connectors
