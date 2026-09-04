#pragma once

#include <functional>
#include <memory>
#include <string>
#include <unordered_map>

#include "oep/acquisition/connectors/connector.hpp"

namespace oep::acquisition::connectors {

/// Constructs `IConnector` instances by `ConnectorConfig::type`.
///
/// New connector types register a creator function at runtime via
/// `register_type` -- the Factory (and the Registry built on top of it)
/// never needs to change to support a new type, satisfying
/// WORK_PACKAGE-005's "The framework shall allow future connector
/// implementations without modification to the core framework."
class ConnectorFactory {
 public:
  using Creator = std::function<std::unique_ptr<IConnector>(const ConnectorConfig&)>;

  /// Registers (or replaces) the creator for `type`.
  void register_type(const std::string& type, Creator creator);

  [[nodiscard]] bool has_type(const std::string& type) const;

  /// Constructs a connector from `config` using the creator registered
  /// for `config.type`. Throws UnknownConnectorTypeError if no such
  /// creator is registered.
  [[nodiscard]] std::unique_ptr<IConnector> create(const ConnectorConfig& config) const;

 private:
  std::unordered_map<std::string, Creator> creators_;
};

}  // namespace oep::acquisition::connectors
