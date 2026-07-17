#pragma once

#include <map>
#include <set>
#include <string>

namespace oep::acquisition::connectors {

/// WORK_PACKAGE-005 "Connector Capabilities": named, string-keyed rather
/// than a closed enum, per "Capabilities shall be extensible" -- a future
/// connector type can declare a capability the framework has never heard
/// of without any change here. These constants name the six capabilities
/// WORK_PACKAGE-005 itself lists as examples.
namespace capability {
inline constexpr const char* kDownloadFiles = "download_files";
inline constexpr const char* kBrowseDirectory = "browse_directory";
inline constexpr const char* kSearch = "search";
inline constexpr const char* kAuthenticationRequired = "authentication_required";
inline constexpr const char* kIncrementalSynchronization = "incremental_synchronization";
inline constexpr const char* kMetadataAvailable = "metadata_available";
}  // namespace capability

/// WORK_PACKAGE-005's "Connector configuration model". `settings` is a
/// generic, type-specific key/value bag -- the core framework never
/// interprets it, only a given connector `type`'s own implementation
/// does, so new connector types can require whatever settings they need
/// without changing this struct.
struct ConnectorConfig {
  std::string connector_id;
  std::string type;
  std::string name;
  std::string description;
  std::map<std::string, std::string> settings;
};

enum class HealthStatus {
  Healthy,
  Unhealthy,
  Unknown,
};

[[nodiscard]] std::string to_string(HealthStatus status);

struct HealthCheckResult {
  HealthStatus status = HealthStatus::Unknown;
  std::string message;
  // ISO-8601 UTC, e.g. "2026-07-17T12:00:00Z".
  std::string checked_at;
};

/// The common abstraction WORK_PACKAGE-005 establishes for communicating
/// with an engineering information source. No implementation registered
/// in this work package performs actual network communication -- see
/// `StubConnector` -- this interface exists so future work packages can
/// add real transports (HTTP, FTP, browser automation, ...) without the
/// Registry, Factory, or REST layer changing.
///
/// Capabilities are fixed at construction time (from `config()`) and
/// exposed only through the read-only `capabilities()` accessor -- there
/// is deliberately no setter anywhere in this interface, which is how
/// WORK_PACKAGE-005's "Capability definitions shall be immutable after
/// registration" rule is satisfied: there is nothing capable of mutating
/// them once a connector exists.
class IConnector {
 public:
  virtual ~IConnector() = default;

  virtual void connect() = 0;
  virtual void disconnect() = 0;
  [[nodiscard]] virtual bool is_connected() const = 0;

  [[nodiscard]] virtual HealthCheckResult health_check() const = 0;
  [[nodiscard]] virtual std::set<std::string> capabilities() const = 0;

  /// Checked by `ConnectorRegistry::register_connector` before a
  /// connector is added to the registry (WORK_PACKAGE-005: "Connector
  /// configuration shall validate before registration"). Returns false
  /// -- rather than throwing -- for configuration problems the connector
  /// itself can detect; the Registry is what turns a `false` result into
  /// a `ConnectorValidationError`.
  [[nodiscard]] virtual bool validate_configuration() const = 0;

  [[nodiscard]] virtual const ConnectorConfig& config() const = 0;
};

}  // namespace oep::acquisition::connectors
