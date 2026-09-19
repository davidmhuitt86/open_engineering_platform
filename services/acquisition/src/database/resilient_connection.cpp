#include "oep/acquisition/database/resilient_connection.hpp"

#include <pqxx/pqxx>

namespace oep::acquisition::database {

ResilientConnection::ResilientConnection(std::string connection_string)
    : connection_string_(std::move(connection_string)),
      connection_(std::make_unique<pqxx::connection>(connection_string_)) {}

ResilientConnection::~ResilientConnection() = default;

void ResilientConnection::reconnect() {
  connection_ = std::make_unique<pqxx::connection>(connection_string_);
}

pqxx::connection& ResilientConnection::get() {
  if (!connection_->is_open()) {
    reconnect();
  }

  // `is_open()` can still report true right up until the connection is
  // actually used and libpqxx discovers the socket is dead (e.g. the
  // PostgreSQL server restarted, or a NAT/VM network path dropped and came
  // back) -- see this class's header comment. A trivial no-op query
  // surfaces that here, once, so every Repository call site downstream
  // gets a genuinely healthy connection instead of discovering the break
  // itself. Reconnecting and retrying this probe exactly once mirrors
  // every other Repository's existing "one connection, no pool, no
  // backoff loop" design -- if the retry also fails, the database is
  // genuinely unreachable and that failure is left to propagate normally.
  try {
    pqxx::nontransaction probe(*connection_);
    probe.exec("SELECT 1");
  } catch (const pqxx::broken_connection&) {
    reconnect();
    pqxx::nontransaction probe(*connection_);
    probe.exec("SELECT 1");
  }

  return *connection_;
}

}  // namespace oep::acquisition::database
