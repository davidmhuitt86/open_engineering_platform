#include "oep/acquisition/common/config.hpp"

#include <fstream>
#include <sstream>

#include <toml++/toml.hpp>

namespace oep::acquisition::common {

namespace {

template <typename T>
T read_or(const toml::table& section, std::string_view key, T fallback) {
  if (auto value = section[key].value<T>()) {
    return *value;
  }
  return fallback;
}

void apply_database(const toml::table& root, DatabaseConfig& out) {
  const auto* section = root["database"].as_table();
  if (section == nullptr) {
    return;
  }
  out.host = read_or<std::string>(*section, "host", out.host);
  out.port = static_cast<std::uint16_t>(read_or<std::int64_t>(*section, "port", out.port));
  out.name = read_or<std::string>(*section, "name", out.name);
  out.user = read_or<std::string>(*section, "user", out.user);
  out.password = read_or<std::string>(*section, "password", out.password);
  out.sslmode = read_or<std::string>(*section, "sslmode", out.sslmode);
}

void apply_logging(const toml::table& root, LoggingConfig& out) {
  const auto* section = root["logging"].as_table();
  if (section == nullptr) {
    return;
  }
  out.level = read_or<std::string>(*section, "level", out.level);
  out.console = read_or<bool>(*section, "console", out.console);
  out.file = read_or<std::string>(*section, "file", out.file);
}

void apply_storage(const toml::table& root, StorageConfig& out) {
  const auto* section = root["storage"].as_table();
  if (section == nullptr) {
    return;
  }
  out.root_path = read_or<std::string>(*section, "root_path", out.root_path);
}

void apply_server(const toml::table& root, ServerConfig& out) {
  const auto* section = root["server"].as_table();
  if (section == nullptr) {
    return;
  }
  out.host = read_or<std::string>(*section, "host", out.host);
  out.port = static_cast<std::uint16_t>(read_or<std::int64_t>(*section, "port", out.port));
}

}  // namespace

Config Config::load_from_string(const std::string& toml_text) {
  toml::table root;
  try {
    root = toml::parse(toml_text);
  } catch (const toml::parse_error& error) {
    std::ostringstream message;
    message << "failed to parse configuration: " << error.description() << " (" << error.source().begin << ")";
    throw ConfigError(message.str());
  }

  Config config;
  apply_database(root, config.database);
  apply_logging(root, config.logging);
  apply_storage(root, config.storage);
  apply_server(root, config.server);
  return config;
}

Config Config::load_from_file(const std::filesystem::path& path) {
  std::error_code exists_error;
  if (!std::filesystem::exists(path, exists_error) || exists_error) {
    throw ConfigError("configuration file does not exist: " + path.string());
  }

  std::ifstream file(path);
  if (!file) {
    throw ConfigError("configuration file could not be opened: " + path.string());
  }
  std::ostringstream buffer;
  buffer << file.rdbuf();
  return load_from_string(buffer.str());
}

std::string Config::database_connection_string() const {
  std::ostringstream stream;
  stream << "host=" << database.host << " port=" << database.port << " dbname=" << database.name
         << " user=" << database.user;
  if (!database.password.empty()) {
    stream << " password=" << database.password;
  }
  stream << " sslmode=" << database.sslmode;
  return stream.str();
}

}  // namespace oep::acquisition::common
