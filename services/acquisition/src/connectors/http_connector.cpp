#include "oep/acquisition/connectors/http_connector.hpp"

#include <cstdint>
#include <cstring>
#include <fstream>
#include <optional>
#include <sstream>
#include <string_view>

#include <httplib.h>

#include "oep/acquisition/common/time.hpp"

namespace oep::acquisition::connectors {

namespace {

// ADR-0003 (HttpConnector Security, Scope, and SSRF Resolution): a
// parsed absolute http(s) URL, split into the piece httplib::Client's
// constructor needs (`origin`), the request path, and the bare
// hostname/IP-literal (no port, no brackets) that
// `resolve_and_validate_host` below validates and DNS-resolves. `host`
// is extracted with the exact same authority grammar
// (`scheme://[bracketed-ipv6|host](:port)?`) cpp-httplib's own
// `Client(scheme_host_port)` constructor uses internally, so it is
// guaranteed to match the hostname httplib itself keys its
// `hostname_addr_map` lookup on.
struct ParsedUrl {
  std::string origin;  // e.g. "https://example.com" or "https://example.com:8443"
  std::string path;     // e.g. "/data/file.csv?x=1" -- always starts with '/'
  std::string host;     // e.g. "example.com" or "2001:db8::1" (no brackets, no port)
};

// Rejects anything that is not an absolute `http://`/`https://` URL
// with a non-empty host, and rejects userinfo (`user:pass@host`) --
// this connector never sends caller-supplied credentials, and a
// userinfo component is a classic URL-confusion technique (the text
// before '@' can be crafted to look like a trusted host while the
// real authority follows it). ADR-0003 Security Design "URL parsing".
std::optional<ParsedUrl> parse_url(const std::string& uri) {
  const auto scheme_end = uri.find("://");
  if (scheme_end == std::string::npos) return std::nullopt;
  const std::string scheme = uri.substr(0, scheme_end);
  if (scheme != "http" && scheme != "https") return std::nullopt;

  const auto authority_start = scheme_end + 3;
  if (authority_start >= uri.size()) return std::nullopt;
  const auto path_start = uri.find('/', authority_start);
  const std::string authority =
      path_start == std::string::npos ? uri.substr(authority_start) : uri.substr(authority_start, path_start - authority_start);
  if (authority.empty()) return std::nullopt;
  if (authority.find('@') != std::string::npos) return std::nullopt;

  std::string host = authority;
  if (host.front() == '[') {
    const auto close = host.find(']');
    if (close == std::string::npos) return std::nullopt;
    host = host.substr(1, close - 1);
  } else {
    const auto colon = host.rfind(':');
    if (colon != std::string::npos) host = host.substr(0, colon);
  }
  if (host.empty()) return std::nullopt;

  const std::string path = path_start == std::string::npos ? "/" : uri.substr(path_start);
  return ParsedUrl{scheme + "://" + authority, path, host};
}

// Resolves a redirect `Location` header against the request that
// produced it. Only absolute URLs, protocol-relative ("//host/path"),
// and origin-relative ("/path") locations are supported -- a bare
// relative path (e.g. "file.csv") is rejected rather than guessed at,
// since RFC 7231 redirects are conventionally absolute or
// origin-relative in practice, and guessing wrong here would be a
// silent correctness/security bug, not just a missing feature. ADR-0003
// Security Design "Redirects: validate every redirect destination".
std::optional<ParsedUrl> resolve_redirect(const std::string& location, const ParsedUrl& current) {
  if (location.rfind("http://", 0) == 0 || location.rfind("https://", 0) == 0) {
    return parse_url(location);
  }
  if (location.rfind("//", 0) == 0) {
    const std::string scheme = current.origin.rfind("https://", 0) == 0 ? "https:" : "http:";
    return parse_url(scheme + location);
  }
  if (!location.empty() && location.front() == '/') {
    return parse_url(current.origin + location);
  }
  return std::nullopt;
}

// ADR-0003: the actual SSRF/destination-restriction policy. Every
// address `getaddrinfo` returns for `host` -- not just the first -- is
// checked; if ANY resolved address falls in a disallowed range, the
// whole resolution is rejected (an attacker able to make a name
// resolve to a mix of public and internal addresses must not be able
// to rely on "just pick one"). `getaddrinfo` itself is what normalizes
// alternate numeric representations (decimal/octal/hex-encoded IPv4
// literals, IPv4-mapped IPv6, etc.) into real address bytes before
// these checks ever run, so the checks below operate on the one
// canonical representation that matters: the bytes the OS will
// actually connect to.

bool is_disallowed_ipv4(const in_addr& addr) {
  const auto* b = reinterpret_cast<const unsigned char*>(&addr.s_addr);
  if (b[0] == 0) return true;                        // 0.0.0.0/8 -- "this network" / unspecified
  if (b[0] == 127) return true;                       // 127.0.0.0/8 -- loopback
  if (b[0] == 10) return true;                        // 10.0.0.0/8 -- RFC1918
  if (b[0] == 172 && (b[1] & 0xF0) == 16) return true; // 172.16.0.0/12 -- RFC1918
  if (b[0] == 192 && b[1] == 168) return true;         // 192.168.0.0/16 -- RFC1918
  if (b[0] == 169 && b[1] == 254) return true;         // 169.254.0.0/16 -- link-local (covers the 169.254.169.254 cloud metadata address)
  if (b[0] == 100 && (b[1] & 0xC0) == 64) return true;  // 100.64.0.0/10 -- carrier-grade NAT / shared address space
  if ((b[0] & 0xF0) == 224) return true;               // 224.0.0.0/4 -- multicast
  if (b[0] == 255 && b[1] == 255 && b[2] == 255 && b[3] == 255) return true;  // 255.255.255.255 -- broadcast
  return false;
}

bool is_disallowed_ipv6(const in6_addr& addr) {
  if (IN6_IS_ADDR_V4MAPPED(&addr)) {
    in_addr v4{};
    std::memcpy(&v4, &addr.s6_addr[12], sizeof(v4));
    return is_disallowed_ipv4(v4);
  }
  if (IN6_IS_ADDR_LOOPBACK(&addr)) return true;
  if (IN6_IS_ADDR_UNSPECIFIED(&addr)) return true;
  if (IN6_IS_ADDR_LINKLOCAL(&addr)) return true;
  if (IN6_IS_ADDR_MULTICAST(&addr)) return true;
  if ((addr.s6_addr[0] & 0xFE) == 0xFC) return true;  // fc00::/7 -- unique local addresses (RFC 4193)
  return false;
}

struct AddressValidation {
  bool ok = false;
  std::string pinned_address;  // a numeric IP literal -- see the "pin" comment below
  std::string error;
};

// Resolves `host` and, unless `allow_private_destinations` is true,
// validates every returned address exactly as
// `is_disallowed_ipv4`/`is_disallowed_ipv6` above describe. On success,
// returns ONE validated, numeric IP literal ("pinned"): the caller must
// hand this exact string to `httplib::Client::set_hostname_addr_map`
// (via `AI_NUMERICHOST`, cpp-httplib performs no further hostname
// lookup once a pinned IP is supplied -- confirmed directly in
// `httplib.h`'s own `create_socket`), so the TCP connection this
// validation is guarding cannot be established against a *different*
// address a second, independent DNS lookup might return (DNS
// rebinding) -- ADR-0003 Security Design "DNS: rebinding implications".
// Address pinning itself always applies, even when
// `allow_private_destinations` is set -- that flag only widens which
// address *classes* are acceptable, never reintroduces the
// rebinding-window `getaddrinfo`-then-connect would otherwise leave open.
//
// `allow_private_destinations` exists ONLY for this connector's own test
// suite (`tests/test_http_connector.cpp`), which -- per this codebase's
// own established convention (`ApiServer`'s tests, `packages/exchange_client`'s
// download tests, etc.) -- spins up a REAL local HTTP server on
// 127.0.0.1 rather than depending on internet access or a mock. The
// live `"http-source"` connector `main.cpp` registers at startup never
// sets this setting, so production behavior rejects loopback/private/
// link-local destinations unconditionally by default -- see
// `test_http_connector.cpp`'s own "the connector registered in main.cpp
// does not opt out of destination validation" test, which asserts this
// directly against `main.cpp`'s literal registration call.
AddressValidation resolve_and_validate_host(const std::string& host, bool allow_private_destinations) {
  AddressValidation out;
  addrinfo hints{};
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  addrinfo* results = nullptr;
  const int rc = getaddrinfo(host.c_str(), nullptr, &hints, &results);
  if (rc != 0 || results == nullptr) {
    out.error = "Could not resolve host: " + host;
    return out;
  }

  std::string first_valid;
  for (addrinfo* p = results; p != nullptr; p = p->ai_next) {
    char buf[INET6_ADDRSTRLEN] = {};
    if (p->ai_family == AF_INET) {
      const auto* sa = reinterpret_cast<sockaddr_in*>(p->ai_addr);
      if (!allow_private_destinations && is_disallowed_ipv4(sa->sin_addr)) {
        out.error = "Destination host \"" + host + "\" resolves to a disallowed private/loopback/link-local address.";
        freeaddrinfo(results);
        return out;
      }
      if (first_valid.empty() && inet_ntop(AF_INET, &sa->sin_addr, buf, sizeof(buf)) != nullptr) {
        first_valid = buf;
      }
    } else if (p->ai_family == AF_INET6) {
      const auto* sa = reinterpret_cast<sockaddr_in6*>(p->ai_addr);
      if (!allow_private_destinations && is_disallowed_ipv6(sa->sin6_addr)) {
        out.error = "Destination host \"" + host + "\" resolves to a disallowed private/loopback/link-local address.";
        freeaddrinfo(results);
        return out;
      }
      if (first_valid.empty() && inet_ntop(AF_INET6, &sa->sin6_addr, buf, sizeof(buf)) != nullptr) {
        first_valid = buf;
      }
    }
  }
  freeaddrinfo(results);

  if (first_valid.empty()) {
    out.error = "Could not resolve host: " + host;
    return out;
  }
  out.ok = true;
  out.pinned_address = first_valid;
  return out;
}

bool fetch_configured_to_fail(const ConnectorConfig& config) {
  const auto it = config.settings.find("fetch_outcome");
  return it != config.settings.end() && it->second == "failure";
}

std::set<std::string> parse_capabilities(const ConnectorConfig& config) {
  std::set<std::string> result;
  const auto it = config.settings.find("capabilities");
  if (it == config.settings.end() || it->second.empty()) return result;
  std::istringstream stream(it->second);
  std::string capability;
  while (std::getline(stream, capability, ',')) {
    if (!capability.empty()) result.insert(capability);
  }
  return result;
}

HealthStatus parse_health_status(const ConnectorConfig& config) {
  const auto it = config.settings.find("health_status");
  if (it == config.settings.end()) return HealthStatus::Healthy;
  if (it->second == "unhealthy") return HealthStatus::Unhealthy;
  if (it->second == "unknown") return HealthStatus::Unknown;
  return HealthStatus::Healthy;
}

int setting_int(const ConnectorConfig& config, std::string_view key, int fallback) {
  const auto it = config.settings.find(std::string(key));
  if (it == config.settings.end()) return fallback;
  try {
    return std::stoi(it->second);
  } catch (const std::exception&) {
    return fallback;
  }
}

std::uint64_t setting_uint64(const ConnectorConfig& config, std::string_view key, std::uint64_t fallback) {
  const auto it = config.settings.find(std::string(key));
  if (it == config.settings.end()) return fallback;
  try {
    return std::stoull(it->second);
  } catch (const std::exception&) {
    return fallback;
  }
}

std::string setting_string(const ConnectorConfig& config, std::string_view key, std::string fallback) {
  const auto it = config.settings.find(std::string(key));
  return it != config.settings.end() ? it->second : std::move(fallback);
}

// Test-only escape hatch -- see `resolve_and_validate_host`'s own doc
// comment. Defaults to false (destination validation enforced) for any
// connector that doesn't explicitly set this, which includes the real
// `"http-source"` connector `main.cpp` registers.
bool setting_bool(const ConnectorConfig& config, std::string_view key, bool fallback) {
  const auto it = config.settings.find(std::string(key));
  if (it == config.settings.end()) return fallback;
  return it->second == "true";
}

}  // namespace

HttpConnector::HttpConnector(ConnectorConfig config) : config_(std::move(config)) {}

void HttpConnector::connect() { connected_ = true; }
void HttpConnector::disconnect() { connected_ = false; }
bool HttpConnector::is_connected() const { return connected_; }

HealthCheckResult HttpConnector::health_check() const {
  const HealthStatus status = parse_health_status(config_);
  std::string message;
  switch (status) {
    case HealthStatus::Healthy:
      message = "HTTP connector reports healthy (no live probe performed).";
      break;
    case HealthStatus::Unhealthy:
      message = "HTTP connector configured to report unhealthy.";
      break;
    case HealthStatus::Unknown:
      message = "HTTP connector configured to report unknown.";
      break;
  }
  return HealthCheckResult{status, message, common::current_timestamp_utc()};
}

std::set<std::string> HttpConnector::capabilities() const { return parse_capabilities(config_); }

bool HttpConnector::validate_configuration() const {
  return !config_.connector_id.empty() && !config_.type.empty();
}

const ConnectorConfig& HttpConnector::config() const { return config_; }

AcquisitionResult HttpConnector::fetch(const AcquisitionRequest& request) {
  AcquisitionResult result;

  if (request.cancellation.stop_requested()) {
    result.error_message = "Fetch cancelled before it started.";
    return result;
  }

  if (fetch_configured_to_fail(config_)) {
    result.error_message = "HTTP connector configured to report fetch failure.";
    return result;
  }

  if (!request.overwrite && !request.resume && std::filesystem::exists(request.destination)) {
    result.error_message = "Destination already exists (overwrite=false).";
    return result;
  }

  const auto initial = parse_url(request.source_uri);
  if (!initial) {
    result.error_message = "source_uri is not an absolute http:// or https:// URL, or contains userinfo: " + request.source_uri;
    return result;
  }

  const int max_redirects = setting_int(config_, "max_redirects", 5);
  const std::uint64_t max_response_bytes = setting_uint64(config_, "max_response_bytes", 2ull * 1024 * 1024 * 1024);
  const bool allow_private_destinations = setting_bool(config_, "allow_private_destinations", false);

  ParsedUrl current = *initial;
  int redirects_followed = 0;

  std::ofstream out;
  bool file_opened = false;
  std::uint64_t bytes_written = 0;
  bool write_failed = false;
  bool size_exceeded = false;
  int final_status = 0;
  std::string final_mime;
  std::string final_etag;

  const auto cancellation = request.cancellation;
  const auto progress = request.progress;

  for (;;) {
#ifndef CPPHTTPLIB_OPENSSL_SUPPORT
    if (current.origin.rfind("https://", 0) == 0) {
      result.error_message =
          "https:// requested but this build of cpp-httplib has no OpenSSL support "
          "(CPPHTTPLIB_OPENSSL_SUPPORT not defined) -- configure OpenSSL and rebuild.";
      return result;
    }
#endif

    const AddressValidation validated = resolve_and_validate_host(current.host, allow_private_destinations);
    if (!validated.ok) {
      result.error_message = validated.error;
      return result;
    }

    httplib::Client client(current.origin);
    client.set_connection_timeout(setting_int(config_, "connect_timeout_seconds", 10));
    client.set_read_timeout(setting_int(config_, "read_timeout_seconds", 30));
    // Redirects are validated and followed manually below (this loop) --
    // httplib's own set_follow_location(true) would follow a redirect
    // to anywhere, including a private address, without ever giving
    // this connector a chance to inspect the destination first.
    client.set_follow_location(false);
    // Pins the TCP connection to the exact address already validated
    // above -- see resolve_and_validate_host's own doc comment.
    client.set_hostname_addr_map({{current.host, validated.pinned_address}});

    const httplib::Headers headers = {
        {"User-Agent", setting_string(config_, "user_agent", "oep-acquisition-http-connector/1.0")},
    };

    std::string redirect_location;

    auto response_handler = [&](const httplib::Response& response) -> bool {
      final_status = response.status;
      if (response.status >= 300 && response.status < 400) {
        redirect_location = response.get_header_value("Location");
        return false;  // never stream a redirect's own body
      }
      if (response.status < 200 || response.status >= 300) {
        return false;  // never stream an error response's body either
      }
      if (request.destination.has_parent_path()) {
        std::filesystem::create_directories(request.destination.parent_path());
      }
      out.open(request.destination, std::ios::binary | std::ios::trunc);
      if (!out) {
        result.error_message = "Failed to open destination path for writing: " + request.destination.string();
        return false;
      }
      file_opened = true;
      final_mime = response.get_header_value("Content-Type");
      final_etag = response.get_header_value("ETag");
      return true;
    };

    auto content_receiver = [&](const char* data, size_t data_length) -> bool {
      if (cancellation.stop_requested()) return false;
      bytes_written += data_length;
      if (bytes_written > max_response_bytes) {
        size_exceeded = true;
        return false;
      }
      out.write(data, static_cast<std::streamsize>(data_length));
      if (!out) {
        write_failed = true;
        return false;
      }
      return true;
    };

    auto progress_callback = [&](std::uint64_t current_bytes, std::uint64_t total_bytes) -> bool {
      if (progress) progress(current_bytes, total_bytes);
      return !cancellation.stop_requested();
    };

    const auto response = client.Get(current.path, headers, response_handler, content_receiver, progress_callback);

    if (!redirect_location.empty()) {
      if (++redirects_followed > max_redirects) {
        result.error_message = "Too many redirects (" + std::to_string(max_redirects) + " max).";
        return result;
      }
      const auto next = resolve_redirect(redirect_location, current);
      if (!next) {
        result.error_message = "Redirect to an unsupported or invalid location: " + redirect_location;
        return result;
      }
      current = *next;
      continue;
    }

    if (file_opened) {
      out.flush();
      out.close();
    }

    if (result.error_message.has_value()) {
      // response_handler hit a local failure (e.g. could not open the
      // destination path) -- already descriptive, nothing to add.
      if (file_opened) std::filesystem::remove(request.destination);
      return result;
    }
    if (final_status == 0) {
      // response_handler was never reached at all: a genuine
      // transport-level failure (connection refused, TLS failure, timeout, ...).
      if (file_opened) std::filesystem::remove(request.destination);
      result.error_message = "HTTP request failed: " + httplib::to_string(response.error());
      return result;
    }
    if (size_exceeded) {
      if (file_opened) std::filesystem::remove(request.destination);
      result.error_message = "Response exceeded the maximum allowed size (" + std::to_string(max_response_bytes) + " bytes).";
      return result;
    }
    if (write_failed) {
      if (file_opened) std::filesystem::remove(request.destination);
      result.error_message = "Failed while writing response body to destination path.";
      return result;
    }
    if (cancellation.stop_requested()) {
      if (file_opened) std::filesystem::remove(request.destination);
      result.error_message = "Fetch cancelled during transfer.";
      return result;
    }
    if (final_status < 200 || final_status >= 300) {
      result.error_message =
          "HTTP request returned status " + std::to_string(final_status) + ": " + current.origin + current.path;
      return result;
    }

    result.success = true;
    result.downloaded_file = request.destination;
    result.bytes_transferred = bytes_written;
    result.mime_type = final_mime.empty() ? "application/octet-stream" : final_mime;
    // A transfer-level identifier, not a cryptographic hash -- see this
    // class's own doc comment and AcquisitionResult::checksum's. ETag is
    // the closest thing HTTP offers to a server-reported content fingerprint;
    // absent one, this stays empty (the platform's real integrity guarantee
    // is the Integrity Verification stage's own SHA-256, not this field).
    result.checksum = final_etag;
    return result;
  }
}

}  // namespace oep::acquisition::connectors
