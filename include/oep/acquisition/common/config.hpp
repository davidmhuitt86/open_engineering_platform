#pragma once

#include <cstdint>
#include <filesystem>
#include <stdexcept>
#include <string>

namespace oep::acquisition::common {

/// Thrown when a configuration file cannot be read or parsed.
class ConfigError : public std::runtime_error {
 public:
  explicit ConfigError(const std::string& message) : std::runtime_error(message) {}
};

struct DatabaseConfig {
  std::string host = "localhost";
  std::uint16_t port = 5432;
  std::string name = "oep_acquisition";
  std::string user = "oep_acquisition";
  std::string password;
  std::string sslmode = "prefer";
};

struct LoggingConfig {
  // One of: "trace", "debug", "info", "warn", "error", "critical".
  std::string level = "info";
  bool console = true;
  // Empty means "no file sink" -- console-only logging.
  std::string file;
};

struct StorageConfig {
  // Where acquired evidence will eventually be written (Reference Vault,
  // out of scope for WORK_PACKAGE_001) -- recorded now so later work
  // packages have a configuration section to extend rather than invent.
  std::string root_path = "./data/vault";
};

struct ServerConfig {
  std::string host = "0.0.0.0";
  std::uint16_t port = 8080;
};

/// The Engineering Acquisition Manager's process configuration
/// (WORK_PACKAGE_001): [database], [logging], [storage], [server].
///
/// Every field has a sensible default, so a missing config file section
/// (or a missing file entirely, for `load_from_file`) does not prevent
/// the process from starting -- only a malformed TOML document is an error.
struct Config {
  DatabaseConfig database;
  LoggingConfig logging;
  StorageConfig storage;
  ServerConfig server;

  /// Parses a TOML document already in memory. Throws ConfigError on
  /// malformed TOML. Exposed separately from load_from_file so tests can
  /// exercise parsing without touching the filesystem.
  static Config load_from_string(const std::string& toml_text);

  /// Reads and parses `path`. Throws ConfigError if the file does not
  /// exist or cannot be parsed.
  static Config load_from_file(const std::filesystem::path& path);

  /// Builds a libpq-style key/value connection string from `database`
  /// (e.g. "host=localhost port=5432 dbname=... user=... password=...
  /// sslmode=prefer"). Never logged verbatim -- see DatabaseConnection.
  [[nodiscard]] std::string database_connection_string() const;
};

}  // namespace oep::acquisition::common
