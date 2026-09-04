#pragma once

#include <memory>
#include <string>

#include "oep/acquisition/common/config.hpp"

// Forward-declared rather than including <libpq-fe.h> here, so headers
// that only need to pass a DatabaseConnection around don't pull in the C
// PostgreSQL client API transitively.
struct pg_conn;

namespace oep::acquisition::database {

/// A thin RAII wrapper around a single `libpq` connection
/// (WORK_PACKAGE_001: "Connection only. No schema. No repositories.").
///
/// Deliberately not `libpqxx` -- this work package's scope is limited to
/// connection management, not query execution with rich C++ type
/// conversions, so the lighter-weight raw C client (already installed
/// alongside PostgreSQL 18, see README.md) is sufficient and avoids an
/// extra dependency this work package doesn't need. Later work packages
/// that add real repositories/queries may reconsider that trade-off.
class DatabaseConnection {
 public:
  /// Attempts to connect immediately. Never throws -- construction always
  /// succeeds; call `is_connected()` to check the outcome. A health
  /// endpoint (or anything else at startup) should be able to report
  /// "database unreachable" without the whole process failing to start,
  /// since WORK_PACKAGE_001 does not require the database to be running
  /// for the bootstrap itself to be considered complete.
  explicit DatabaseConnection(const common::DatabaseConfig& config);
  ~DatabaseConnection();

  DatabaseConnection(const DatabaseConnection&) = delete;
  DatabaseConnection& operator=(const DatabaseConnection&) = delete;
  DatabaseConnection(DatabaseConnection&&) noexcept;
  DatabaseConnection& operator=(DatabaseConnection&&) noexcept;

  [[nodiscard]] bool is_connected() const;

  /// Empty when connected; otherwise libpq's own error description
  /// (never includes the password -- see Config::database_connection_string).
  [[nodiscard]] const std::string& last_error() const;

 private:
  struct ConnDeleter {
    void operator()(pg_conn* conn) const noexcept;
  };

  std::unique_ptr<pg_conn, ConnDeleter> connection_;
  std::string last_error_;
};

}  // namespace oep::acquisition::database
