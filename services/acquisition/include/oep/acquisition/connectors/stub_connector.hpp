#pragma once

#include "oep/acquisition/connectors/connector.hpp"

namespace oep::acquisition::connectors {

/// The one concrete `IConnector` this work package ships, registered
/// under the type name `"stub"`. Performs no real network communication
/// (WORK_PACKAGE-005: "No implementation shall perform actual network
/// communication") -- it exists purely to prove the Connector Interface,
/// Factory, Registry, capability discovery, and health check machinery
/// work end to end. Future work packages add real transports (HTTP, FTP,
/// browser automation) as additional connector types, following this
/// same interface.
///
/// Configurable via `ConnectorConfig::settings`:
/// - `"capabilities"`: comma-separated capability names (see
///   `connector.hpp`'s `capability::` constants). Empty/absent means no
///   capabilities.
/// - `"health_status"`: one of `"healthy"`, `"unhealthy"`, `"unknown"`
///   (default `"healthy"`) -- lets tests and the REST layer exercise
///   every health state without a real health check existing yet.
/// - `"fetch_outcome"`: one of `"success"` (default), `"failure"` -- lets
///   tests exercise `fetch`'s failure path without a real failure
///   condition existing yet.
/// - `"fetch_mime_type"`: reported as `AcquisitionResult::mime_type` on
///   success (default `"text/plain"`).
///
/// `fetch` (ADR-0008) writes a small, deterministic placeholder file to
/// `request.destination` -- still no real network communication, just a
/// local write standing in for one, so WORK_PACKAGE-006's Downloader has
/// something real on disk to assert against in its own tests.
class StubConnector : public IConnector {
 public:
  explicit StubConnector(ConnectorConfig config);

  void connect() override;
  void disconnect() override;
  [[nodiscard]] bool is_connected() const override;

  [[nodiscard]] HealthCheckResult health_check() const override;
  [[nodiscard]] std::set<std::string> capabilities() const override;
  [[nodiscard]] bool validate_configuration() const override;
  [[nodiscard]] const ConnectorConfig& config() const override;
  [[nodiscard]] AcquisitionResult fetch(const AcquisitionRequest& request) override;

 private:
  ConnectorConfig config_;
  bool connected_ = false;
};

}  // namespace oep::acquisition::connectors
