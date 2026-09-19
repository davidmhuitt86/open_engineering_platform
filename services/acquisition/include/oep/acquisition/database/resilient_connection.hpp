#pragma once

#include <memory>
#include <string>

namespace pqxx {
class connection;
}

namespace oep::acquisition::database {

/// A `pqxx::connection` holder that transparently reconnects when the
/// underlying connection has gone bad, instead of leaving every Repository
/// method throwing `pqxx::broken_connection` forever until the whole
/// process is restarted.
///
/// `libpqxx` deliberately does not auto-reconnect a `pqxx::connection` once
/// it is broken (e.g. the PostgreSQL server restarts, or a network path
/// drops and comes back) -- see libpqxx's own documentation. Every
/// Postgres-backed Repository in this service (`registry`, `vault`,
/// `acquisition`, `downloads`, `integrity`, `metadata`, `provenance`) held
/// a single `pqxx::connection` for the process lifetime with no reconnect
/// logic at all, so one dropped connection meant every subsequent request
/// failed with a 503 until someone manually restarted the process. This
/// class centralizes the fix in one place rather than duplicating it eight
/// times.
///
/// Not a connection pool: this is deliberately still "one connection,
/// replaced in place when it's dead," matching every Repository's existing
/// single-connection-per-instance design -- just self-healing instead of
/// permanently broken.
class ResilientConnection {
 public:
  explicit ResilientConnection(std::string connection_string);
  ~ResilientConnection();

  ResilientConnection(const ResilientConnection&) = delete;
  ResilientConnection& operator=(const ResilientConnection&) = delete;

  /// Returns a healthy, usable connection: reconnects first if the current
  /// one is closed, and reconnects-and-retries once more if the current
  /// one merely reports itself open but turns out to be dead the moment it
  /// is actually used (libpq/libpqxx do not always detect a broken socket
  /// via `is_open()` alone). Only propagates `pqxx::broken_connection` (or
  /// whatever reconnecting itself throws) when the database is genuinely
  /// unreachable -- that case is a real "service unavailable" and is left
  /// to callers exactly as before.
  pqxx::connection& get();

 private:
  void reconnect();

  std::string connection_string_;
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::acquisition::database
