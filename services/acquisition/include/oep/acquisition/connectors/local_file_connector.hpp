#pragma once

#include "oep/acquisition/connectors/connector.hpp"

namespace oep::acquisition::connectors {

/// WP-EAM-005 (User-Provided Artifact Acquisition): a real `IConnector`
/// implementation whose `source_uri` is interpreted as an absolute local
/// filesystem path rather than a network URL -- the same
/// `AcquisitionRequest`/`AcquisitionResult` contract every other
/// connector (`HttpConnector`, `StubConnector`) already uses, per
/// ADR-0008. This lets a User-Provided Artifact (a local file the
/// engineer selects directly, e.g. a PDF wiring diagram) flow through
/// the EXISTING Job -> Download -> Verify -> Metadata -> Vault pipeline
/// completely unchanged -- only the connector differs; no second
/// acquisition pipeline is introduced.
///
/// `fetch` copies (never moves, never deletes) the source file's bytes
/// to `request.destination` -- the original file the engineer selected
/// is never touched. Per ADR-0008, this connector's own responsibility
/// ends at "retrieve the artifact" -- cryptographic integrity
/// verification (SHA-256) remains the existing, unmodified Integrity
/// Verification stage's job, not this connector's.
///
/// Configurable via `ConnectorConfig::settings`:
/// - `"max_file_bytes"`: maximum accepted source file size in bytes
///   (default 2 GiB, mirroring `HttpConnector`'s own
///   `"max_response_bytes"` default) -- rejects the fetch before any
///   copy begins rather than partially copying an oversized file.
class LocalFileConnector : public IConnector {
 public:
  explicit LocalFileConnector(ConnectorConfig config);

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
