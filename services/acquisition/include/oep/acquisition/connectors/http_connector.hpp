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
/// (scheme + host + path, no userinfo); `fetch` fails fast with a
/// descriptive `error_message` for anything else rather than guessing an
/// origin. HTTPS support depends on `cpp-httplib` having been built with
/// OpenSSL available at configure time (`HTTPLIB_USE_OPENSSL_IF_AVAILABLE`,
/// cpp-httplib's own default) -- if it wasn't, an `https://` request
/// fails with a clear error rather than silently downgrading to a
/// different scheme.
///
/// **Security (ADR-0003 -- see `docs/decisions/ADR-0003-HTTPCONNECTOR-SCOPE-DISCREPANCY.md`
/// for the full decision record):** `source_uri` is caller-supplied,
/// per-request, with no cross-check against any registered source --
/// this is an intentional SSRF-shaped trust boundary, closed
/// structurally rather than documented-only. Before connecting, and
/// before following *every* redirect hop, the destination host is
/// resolved and every returned address is validated to reject loopback,
/// RFC1918/link-local/multicast/unspecified/broadcast addresses (IPv4
/// and IPv6, including IPv4-mapped IPv6 and the 169.254.169.254 cloud
/// metadata address, which is simply link-local) -- then the exact
/// validated address is pinned for the actual TCP connection (via
/// `httplib::Client::set_hostname_addr_map`), so a second, independent
/// DNS lookup at connect time can never resolve to a different (rebound)
/// address than the one already checked. Redirects are followed
/// manually (`set_follow_location(false)`, this class's own loop) with
/// the same validation applied to every hop, up to `"max_redirects"`.
/// Response bodies are capped at `"max_response_bytes"`. No caller
/// header (including `Authorization`) is ever accepted or forwarded --
/// the only request header this connector ever sends is `User-Agent`.
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
/// - `"max_redirects"`: integer, default 5.
/// - `"max_response_bytes"`: integer (bytes), default 2 GiB.
/// - `"allow_private_destinations"`: `"true"` disables the
///   loopback/private/link-local destination check above -- test-only
///   (see `tests/test_http_connector.cpp`, which needs a real local
///   test server); the live `"http-source"` connector `main.cpp`
///   registers never sets this and is validated unconditionally.
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
