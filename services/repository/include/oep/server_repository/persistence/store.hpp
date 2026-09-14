#pragma once

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "oep/server_repository/common/config.hpp"
#include "oep/server_repository/domain/types.hpp"

namespace pqxx {
class connection;
}

namespace oep::server_repository::persistence {

/// The Server Repository's entire persistence surface (WP-SRV-011).
///
/// This single class deliberately owns every table (repositories,
/// objects/relationships + their "head" pointers, commits, audit events)
/// rather than being split into one class per table, because the
/// ADR-0006 SS26 atomicity requirement -- a commit's mutations, revisions,
/// commit record, idempotency outcome, and audit association MUST all
/// commit in one transaction -- is naturally expressed as one method
/// (`submit_commit`) owning one `pqxx::work`. Splitting persistence
/// across several repository classes each opening their own transaction
/// would make that atomicity guarantee much harder to keep correct, not
/// easier.
///
/// Every method throws a `domain::*Error` (never leaks a raw `pqxx`
/// exception, a SQL string, or a connection detail to a caller -- see
/// `domain/errors.hpp` and ADR-0006 SS13).
///
/// WP-SRV-011A correction: the first slice (WP-SRV-011) held exactly one
/// `pqxx::connection` behind a `std::mutex`, so every method -- including
/// `submit_commit` -- executed on a single shared connection. That made
/// concurrent HTTP requests *safe*, but it also meant every concurrent
/// commit was serialized by the process-wide mutex before PostgreSQL ever
/// saw a second transaction: the required optimistic-concurrency guarantee
/// (real competing transactions racing for the same `object_heads` row,
/// resolved by `SELECT ... FOR UPDATE` plus the `expected_revision` check)
/// was never actually exercised at the database layer, only simulated by
/// application-level serialization.
///
/// This class now owns a small internal connection pool instead of one
/// connection: each public method leases its own `pqxx::connection` for
/// the duration of its one transaction and returns it to the pool
/// afterward. Concurrent HTTP requests therefore run on genuinely
/// independent connections/transactions and compete for the same
/// `object_heads`/`relationship_heads` row at the PostgreSQL row-lock
/// level, which is what `SELECT ... FOR UPDATE` is actually for. The pool
/// is deliberately the smallest structure that achieves this (a
/// mutex+condition-variable-guarded free list of connections, defined
/// entirely in store.cpp) rather than a general-purpose pooling library --
/// still no cross-thread sharing of a single `pqxx::connection`, still no
/// architectural change to the atomicity model documented above.
class ServerRepositoryStore {
 public:
  explicit ServerRepositoryStore(const common::DatabaseConfig& config);
  ~ServerRepositoryStore();

  ServerRepositoryStore(const ServerRepositoryStore&) = delete;
  ServerRepositoryStore& operator=(const ServerRepositoryStore&) = delete;

  /// ADR-0006 SS9/SS21: `request.operation_id` is checked against the
  /// SERVER-SCOPED repository-creation namespace (not any one
  /// repository's own records, since none exists yet). Identical retry
  /// -> returns the original repository. Reused identity with different
  /// content -> throws IdempotencyConflictError. Otherwise creates a new
  /// repository, its creation audit event, and the idempotency record,
  /// all atomically (ADR-0006's own repository-creation atomicity
  /// correction).
  [[nodiscard]] domain::RepositoryMetadata create_repository(const domain::RepositoryCreateRequest& request);

  [[nodiscard]] std::optional<domain::RepositoryMetadata> get_repository(const std::string& repository_id);

  [[nodiscard]] std::vector<domain::RepositoryMetadata> list_repositories();

  /// ADR-0006 SS8/SS9/SS26: `request.operation_id` is checked against
  /// the REPOSITORY-SCOPED commit-idempotency namespace for
  /// `repository_id`. Identical retry -> returns the original commit
  /// result. Reused identity with different content ->
  /// IdempotencyConflictError. A stale `expected_revision` on any
  /// mutation -> ConcurrencyConflictError, the whole commit rejected,
  /// repository state unchanged. An invalid mutation (unknown
  /// relationship endpoint, duplicate create identity) ->
  /// ValidationError, same all-or-nothing rejection. Every check and
  /// every write happens inside one `pqxx::work` transaction.
  [[nodiscard]] domain::CommitResult submit_commit(const std::string& repository_id,
                                                      const domain::CommitRequest& request);

  [[nodiscard]] std::optional<domain::EngineeringObject> get_object(const std::string& repository_id,
                                                                        const std::string& object_id);
  [[nodiscard]] std::optional<domain::EngineeringObject> get_object_revision(const std::string& repository_id,
                                                                                const std::string& object_id,
                                                                                std::int64_t revision);

  // ADR-0006 SS7/SS18: "List objects" -- simple enumeration of the
  // repository's current objects, no pagination/filtering/sorting
  // (explicitly out of this slice's scope). Throws NotFoundError if
  // repository_id does not exist, matching every other repository-scoped
  // method here.
  [[nodiscard]] std::vector<domain::EngineeringObject> list_objects(const std::string& repository_id);

  [[nodiscard]] std::optional<domain::Relationship> get_relationship(const std::string& repository_id,
                                                                        const std::string& relationship_id);
  [[nodiscard]] std::optional<domain::Relationship> get_relationship_revision(
      const std::string& repository_id, const std::string& relationship_id, std::int64_t revision);

  // ADR-0006 SS7/SS18: "List relationships" -- same shape as list_objects.
  [[nodiscard]] std::vector<domain::Relationship> list_relationships(const std::string& repository_id);

  [[nodiscard]] std::optional<domain::CommitResult> get_commit(const std::string& repository_id,
                                                                   const std::string& commit_id);

 private:
  class ConnectionPool;

  // Used internally by `submit_commit`'s idempotent-retry path, which
  // already holds a leased connection for its own transaction and simply
  // reuses it (on the same thread, sequentially) rather than acquiring a
  // second one from the pool. Identical logic to the public `get_commit`.
  [[nodiscard]] std::optional<domain::CommitResult> get_commit_with_connection(pqxx::connection& connection,
                                                                                   const std::string& repository_id,
                                                                                   const std::string& commit_id);

  std::unique_ptr<ConnectionPool> pool_;
};

}  // namespace oep::server_repository::persistence
