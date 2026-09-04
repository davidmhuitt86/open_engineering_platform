#pragma once

#include <cstdint>
#include <filesystem>
#include <functional>
#include <map>
#include <optional>
#include <set>
#include <stop_token>
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

/// `bytes_transferred`, `total_bytes` -- `total_bytes` is 0 if unknown.
/// ADR-0008 lists "progress callbacks" as a field of `AcquisitionRequest`
/// without specifying a signature; this is the one this codebase uses.
using ProgressCallback = std::function<void(std::uint64_t bytes_transferred, std::uint64_t total_bytes)>;

/// ADR-0008 "Connector Content Retrieval Interface": the standardized
/// request object for `IConnector::fetch`. Intentionally extensible --
/// additional fields may be added without changing `IConnector::fetch`'s
/// signature, which is the whole point of using a request object instead
/// of a primitive parameter list (ADR-0008 Rationale).
///
/// `cancellation` uses the standard library's own `std::stop_token`
/// rather than a platform-specific cancellation type, since it already
/// does exactly what ADR-0008 asks for.
struct AcquisitionRequest {
  std::string job_id;
  std::string source_uri;
  std::filesystem::path destination;
  bool overwrite = false;
  // Reserved for future connector implementations that support resumable
  // transfers -- ADR-0008 lists "resume operations" as a future
  // extensibility example, not a requirement of this ADR. StubConnector
  // does not implement partial-resume semantics.
  bool resume = false;
  ProgressCallback progress;
  std::stop_token cancellation;
  std::map<std::string, std::string> properties;
};

/// ADR-0008's standardized result object for `IConnector::fetch`.
struct AcquisitionResult {
  bool success = false;
  std::filesystem::path downloaded_file;
  std::uint64_t bytes_transferred = 0;
  std::string mime_type;
  // A transfer-level checksum reported by the connector as a byproduct of
  // the fetch itself -- not the platform's Integrity Verification stage,
  // which ADR-0008 explicitly excludes from Connector Responsibilities
  // and which remains a later pipeline stage's job to perform against
  // this value.
  std::string checksum;
  std::optional<std::string> error_message;
};

/// The common abstraction WORK_PACKAGE-005 establishes for communicating
/// with an engineering information source, extended by ADR-0008 with a
/// standardized content-retrieval operation. No implementation registered
/// so far performs actual network communication -- see `StubConnector`
/// -- this interface exists so future work packages can add real
/// transports (HTTP, FTP, browser automation, ...) without the Registry,
/// Factory, or REST layer changing.
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

  /// ADR-0008 "Connector Content Retrieval Interface": the standardized
  /// mechanism for retrieving an engineering artifact through this
  /// connector. Per that ADR, connectors are responsible only for
  /// establishing communication, retrieving the artifact, reporting
  /// progress, and returning this result -- integrity verification,
  /// metadata extraction, engineering object creation, Reference Vault
  /// publication, repository persistence, job scheduling, and workflow
  /// orchestration all belong to later pipeline stages, not to `fetch`
  /// or any `IConnector` implementation.
  [[nodiscard]] virtual AcquisitionResult fetch(const AcquisitionRequest& request) = 0;
};

}  // namespace oep::acquisition::connectors
