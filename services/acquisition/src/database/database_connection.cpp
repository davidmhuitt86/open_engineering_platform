#include "oep/acquisition/database/database_connection.hpp"

#include <libpq-fe.h>

namespace oep::acquisition::database {

void DatabaseConnection::ConnDeleter::operator()(pg_conn* conn) const noexcept {
  if (conn != nullptr) {
    PQfinish(conn);
  }
}

DatabaseConnection::DatabaseConnection(const common::DatabaseConfig& config) {
  const std::string connection_string = common::Config{.database = config}.database_connection_string();
  connection_.reset(PQconnectdb(connection_string.c_str()));

  if (connection_ == nullptr || PQstatus(connection_.get()) != CONNECTION_OK) {
    last_error_ = (connection_ != nullptr) ? PQerrorMessage(connection_.get()) : "PQconnectdb returned null";
  }
}

DatabaseConnection::~DatabaseConnection() = default;
DatabaseConnection::DatabaseConnection(DatabaseConnection&&) noexcept = default;
DatabaseConnection& DatabaseConnection::operator=(DatabaseConnection&&) noexcept = default;

bool DatabaseConnection::is_connected() const {
  return connection_ != nullptr && PQstatus(connection_.get()) == CONNECTION_OK;
}

const std::string& DatabaseConnection::last_error() const {
  return last_error_;
}

}  // namespace oep::acquisition::database
