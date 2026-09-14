#pragma once

#include <cstdint>
#include <filesystem>
#include <stdexcept>
#include <string>

namespace oep::server_repository::common {

/// Thrown when a configuration file cannot be read or parsed.
class ConfigError : public std::runtime_error {
 public:
  explicit ConfigError(const std::string& message) : std::runtime_error(message) {}
};

/// WP-SRV-011 / ADR-0006 SS25: the Server Repository MUST use a separate
/// database from EAM's, a separate least-privilege role, and separate
/// migrations, though it MAY share the same physical PostgreSQL
/// installation. Defaults here name a distinct database/role
/// (`oep_server_repository`) from EAM's (`oep_acquisition`).
struct DatabaseConfig {
  std::string host = "localhost";
  std::uint16_t port = 5432;
  std::string name = "oep_server_repository";
  std::string user = "oep_server_repository";
  std::string password;
  std::string sslmode = "prefer";
};

struct LoggingConfig {
  std::string level = "info";
  bool console = true;
  std::string file;
};

struct ServerConfig {
  // ADR-0003/ADR-0006 SS5: loopback-only by default -- the supported
  // topology terminates TLS/auth in front of this process, mirroring
  // EAM's own established posture (services/acquisition's own
  // ServerConfig default, WP-SRV-004).
  std::string host = "127.0.0.1";
  std::uint16_t port = 8081;
};

/// The Server Repository process's configuration (WP-SRV-011):
/// [database], [logging], [server]. Every field has a sensible default,
/// so a missing config file (or a missing section within one) does not
/// prevent the process from starting -- only a malformed TOML document
/// is an error. Mirrors services/acquisition's own Config exactly.
struct Config {
  DatabaseConfig database;
  LoggingConfig logging;
  ServerConfig server;

  static Config load_from_string(const std::string& toml_text);
  static Config load_from_file(const std::filesystem::path& path);

  /// Never logged verbatim -- see common::Logger and api::respond_error.
  [[nodiscard]] std::string database_connection_string() const;
};

}  // namespace oep::server_repository::common
