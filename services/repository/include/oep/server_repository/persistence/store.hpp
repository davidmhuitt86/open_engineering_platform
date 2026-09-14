#pragma once

#include <memory>
#include <mutex>
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
/// Holds exactly one `pqxx::connection` (mirroring EAM's own
/// `Postgres*Repository` classes, and the exact concurrency limitation
/// WP-SRV-005's own audit already documented for that pattern: a single
/// libpqxx connection is not safe for concurrent use from multiple
/// threads). Unlike EAM's repositories, this class guards every access
/// to that connection with an internal mutex, so concurrent HTTP
/// requests (this service's `httplib::Server` uses a multi-threaded
/// pool, same as EAM's) are serialized safely at the persistence layer
/// rather than racing on the same connection object. This is what makes
/// this WP's own required concurrent-writer test (multiple real threads
/// submitting conflicting commits at once) safe to run at all -- without
/// it, concurrent access would be undefined behavior, not merely a
/// missed optimization. A connection pool (removing the serialization
/// bottleneck this mutex introduces) is a reasonable future improvement,
/// not required by ADR-0006 for this first slice.
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

  [[nodiscard]] std::optional<domain::Relationship> get_relationship(const std::string& repository_id,
                                                                        const std::string& relationship_id);
  [[nodiscard]] std::optional<domain::Relationship> get_relationship_revision(
      const std::string& repository_id, const std::string& relationship_id, std::int64_t revision);

  [[nodiscard]] std::optional<domain::CommitResult> get_commit(const std::string& repository_id,
                                                                   const std::string& commit_id);

 private:
  // Used internally by `submit_commit`'s idempotent-retry path (which
  // already holds `mutex_`) to avoid recursive-locking a plain
  // `std::mutex` -- identical logic to the public `get_commit`, just
  // without acquiring the lock itself.
  [[nodiscard]] std::optional<domain::CommitResult> get_commit_locked(const std::string& repository_id,
                                                                          const std::string& commit_id);

  std::mutex mutex_;
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::server_repository::persistence
