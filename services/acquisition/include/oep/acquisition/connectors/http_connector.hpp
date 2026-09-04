#pragma once

#include "oep/acquisition/connectors/connector.hpp"

namespace oep::acquisition::connectors {

/// A real `IConnector` implementation: retrieves artifacts over genuine
/// HTTP/HTTPS using `cpp-httplib`'s client mode -- unlike `StubConnector`
/// (which performs no network communication at all), `fetch` here issues
/// a real GET request against `request.source_uri` and streams the
/// response body to disk. Registered under the type name `"http"`.
///
/// `request.source_uri` must be an absolute `http://` or `https://` URL
/// (scheme + host + path); `fetch` fails fast with a descriptive
/// `error_message` for anything else rather than guessing an origin.
/// HTTPS support depends on `cpp-httplib` having been built with OpenSSL
/// available at configure time (`HTTPLIB_USE_OPENSSL_IF_AVAILABLE`,
/// cpp-httplib's own default) -- if it wasn't, an `https://` request
/// fails with a clear error rather than silently downgrading to a
/// different scheme.
///
/// Configurable via `ConnectorConfig::settings`:
/// - `"capabilities"`: comma-separated capability names, same convention
///   as `StubConnector`.
/// - `"health_status"`: same three values as `StubConnector` -- there is
///   no cheap, universal "is this connector healthy" HTTP probe (unlike
///   a fixed health endpoint a real backend would offer), so this stays
///   operator-configured rather than invented.
/// - `"connect_timeout_seconds"` / `"read_timeout_seconds"`: integers,
///   default 10 and 30 respectively.
/// - `"user_agent"`: sent as the `User-Agent` header (default
///   `"oep-acquisition-http-connector/1.0"`), since some public data
///   hosts reject requests with no or a generic client `User-Agent`.
class HttpConnector : public IConnector {
 public:
  explicit HttpConnector(ConnectorConfig config);

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
