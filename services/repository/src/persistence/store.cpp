#include "oep/server_repository/persistence/store.hpp"

#include <condition_variable>
#include <deque>
#include <mutex>
#include <set>
#include <sstream>

#include <picosha2.h>
#include <pqxx/pqxx>

#include "oep/server_repository/common/config.hpp"
#include "oep/server_repository/common/time.hpp"
#include "oep/server_repository/common/uuid.hpp"
#include "oep/server_repository/domain/errors.hpp"

namespace oep::server_repository::persistence {

// WP-SRV-011A: a small, fixed-size pool of independent `pqxx::connection`s.
// `acquire()` blocks (via a condition variable, not a busy-wait) until a
// connection is free, hands it out wrapped in a move-only RAII lease, and
// the lease's destructor returns the connection to the pool -- so a
// connection can never leak even if the caller throws mid-transaction
// (`pqxx::work`'s own destructor already rolls back an uncommitted
// transaction on that connection before the lease returns it). Sized well
// above this WP's 8-writer concurrency test so genuinely independent
// transactions are never artificially re-serialized by pool exhaustion.
class ServerRepositoryStore::ConnectionPool {
 public:
  ConnectionPool(const common::DatabaseConfig& config, std::size_t size) {
    const std::string connection_string = common::Config{.database = config}.database_connection_string();
    for (std::size_t i = 0; i < size; ++i) {
      connections_.push_back(std::make_unique<pqxx::connection>(connection_string));
    }
  }

  class Lease {
   public:
    Lease(ConnectionPool& pool, std::unique_ptr<pqxx::connection> connection)
        : pool_(&pool), connection_(std::move(connection)) {}
    ~Lease() {
      if (connection_) {
        pool_->release(std::move(connection_));
      }
    }
    Lease(const Lease&) = delete;
    Lease& operator=(const Lease&) = delete;
    Lease(Lease&&) = default;
    Lease& operator=(Lease&&) = default;

    pqxx::connection& get() { return *connection_; }

   private:
    ConnectionPool* pool_;
    std::unique_ptr<pqxx::connection> connection_;
  };

  Lease acquire() {
    std::unique_lock<std::mutex> lock(mutex_);
    cv_.wait(lock, [this] { return !connections_.empty(); });
    std::unique_ptr<pqxx::connection> connection = std::move(connections_.back());
    connections_.pop_back();
    return Lease(*this, std::move(connection));
  }

 private:
  void release(std::unique_ptr<pqxx::connection> connection) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      connections_.push_back(std::move(connection));
    }
    cv_.notify_one();
  }

  std::mutex mutex_;
  std::condition_variable cv_;
  std::deque<std::unique_ptr<pqxx::connection>> connections_;
};

namespace {

constexpr std::size_t kConnectionPoolSize = 16;

using domain::ConcurrencyConflictError;
using domain::IdempotencyConflictError;
using domain::MutationKind;
using domain::NotFoundError;
using domain::ValidationError;

// WP-SRV-012: the wire/fingerprint spelling of each mutation kind.
const char* kind_str(MutationKind kind) {
  switch (kind) {
    case MutationKind::Create:
      return "create";
    case MutationKind::Update:
      return "update";
    case MutationKind::Delete:
      return "delete";
  }
  return "create";
}

// WP-SRV-011 / ADR-0006 SS9/SS21: a stable fingerprint of a request's
// *content* (never including the operation_id itself), used to
// distinguish "the client is retrying the exact same request" (return
// the original result) from "the client reused an operation identity
// with materially different content" (IDEMPOTENCY_CONFLICT). SHA-256 of
// a deterministic field concatenation -- not a wire format, never
// parsed back, only ever compared for equality.
std::string sha256_hex(const std::string& text) {
  std::vector<unsigned char> hash(picosha2::k_digest_size);
  picosha2::hash256(text.begin(), text.end(), hash.begin(), hash.end());
  return picosha2::bytes_to_hex_string(hash.begin(), hash.end());
}

std::string fingerprint_of(const domain::RepositoryCreateRequest& request) {
  std::ostringstream out;
  out << "name=" << request.name << "\x1f"
      << "description=" << request.description << "\x1f"
      << "author=" << request.author << "\x1f"
      << "organization=" << request.organization << "\x1f"
      << "tags=" << request.tags;
  return sha256_hex(out.str());
}

std::string fingerprint_of(const domain::CommitRequest& request) {
  std::ostringstream out;
  for (const auto& mutation : request.object_mutations) {
    out << "obj\x1f" << kind_str(mutation.kind) << "\x1f" << mutation.object_id << "\x1f"
        << (mutation.expected_revision.has_value() ? std::to_string(*mutation.expected_revision) : "-") << "\x1f"
        << domain::to_string(mutation.object_type) << "\x1f" << mutation.name << "\x1f" << mutation.description
        << "\x1f" << mutation.author << "\x1f" << mutation.tags << "\x1f" << mutation.content << "\x1f"
        << mutation.version << "\x1e";
  }
  for (const auto& mutation : request.relationship_mutations) {
    out << "rel\x1f" << kind_str(mutation.kind) << "\x1f" << mutation.relationship_id << "\x1f"
        << (mutation.expected_revision.has_value() ? std::to_string(*mutation.expected_revision) : "-") << "\x1f"
        << mutation.source_object_id << "\x1f" << mutation.target_object_id << "\x1f"
        << domain::to_string(mutation.relationship_type) << "\x1f" << mutation.description << "\x1f"
        << mutation.author << "\x1e";
  }
  return sha256_hex(out.str());
}

domain::RepositoryMetadata row_to_repository(const pqxx::row& row) {
  domain::RepositoryMetadata metadata;
  metadata.repository_id = row["id"].as<std::string>();
  metadata.name = row["name"].as<std::string>();
  metadata.description = row["description"].as<std::string>();
  metadata.author = row["author"].as<std::string>();
  metadata.organization = row["organization"].as<std::string>();
  metadata.tags = row["tags"].as<std::string>();
  metadata.created_at = row["created_at_text"].as<std::string>();
  metadata.updated_at = row["updated_at_text"].as<std::string>();
  return metadata;
}

constexpr auto kRepositorySelectColumns =
    "id::text AS id, name, description, author, organization, tags, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at_text, "
    "to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS updated_at_text";

domain::EngineeringObject row_to_object(const pqxx::row& row) {
  domain::EngineeringObject object;
  object.object_id = row["object_id"].as<std::string>();
  object.repository_id = row["repository_id"].as<std::string>();
  object.revision = row["revision"].as<std::int64_t>();
  object.object_type = domain::object_type_from_string(row["object_type"].as<std::string>())
                            .value_or(domain::ObjectType::Document);
  object.name = row["name"].as<std::string>();
  object.description = row["description"].as<std::string>();
  object.author = row["author"].as<std::string>();
  object.tags = row["tags"].as<std::string>();
  object.content = row["content"].as<std::string>();
  object.version = row["version"].as<std::string>();
  object.commit_id = row["commit_id"].as<std::string>();
  object.created_at = row["created_at_text"].as<std::string>();
  object.is_tombstoned = row["is_tombstoned"].as<bool>();
  return object;
}

constexpr auto kObjectSelectColumns =
    "object_id::text AS object_id, repository_id::text AS repository_id, revision, object_type, name, "
    "description, author, tags, content, version, commit_id::text AS commit_id, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at_text, is_tombstoned";

domain::Relationship row_to_relationship(const pqxx::row& row) {
  domain::Relationship relationship;
  relationship.relationship_id = row["relationship_id"].as<std::string>();
  relationship.repository_id = row["repository_id"].as<std::string>();
  relationship.revision = row["revision"].as<std::int64_t>();
  relationship.source_object_id = row["source_object_id"].as<std::string>();
  relationship.target_object_id = row["target_object_id"].as<std::string>();
  relationship.relationship_type = domain::relationship_type_from_string(row["relationship_type"].as<std::string>())
                                        .value_or(domain::RelationshipType::References);
  relationship.description = row["description"].as<std::string>();
  relationship.author = row["author"].as<std::string>();
  relationship.commit_id = row["commit_id"].as<std::string>();
  relationship.created_at = row["created_at_text"].as<std::string>();
  relationship.is_tombstoned = row["is_tombstoned"].as<bool>();
  return relationship;
}

constexpr auto kRelationshipSelectColumns =
    "relationship_id::text AS relationship_id, repository_id::text AS repository_id, revision, "
    "source_object_id::text AS source_object_id, target_object_id::text AS target_object_id, "
    "relationship_type, description, author, commit_id::text AS commit_id, "
    "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at_text, is_tombstoned";

}  // namespace

ServerRepositoryStore::ServerRepositoryStore(const common::DatabaseConfig& config)
    : pool_(std::make_unique<ConnectionPool>(config, kConnectionPoolSize)) {}

ServerRepositoryStore::~ServerRepositoryStore() = default;

domain::RepositoryMetadata ServerRepositoryStore::create_repository(const domain::RepositoryCreateRequest& request) {
  const std::string fingerprint = fingerprint_of(request);

  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());

  // ADR-0006 SS9/SS21: SERVER-SCOPED idempotency check -- keyed only on
  // operation_id, not on any repository_id (none exists yet).
  const pqxx::result existing =
      txn.exec_params("SELECT repository_id::text AS repository_id, request_fingerprint "
                        "FROM repository_creation_operations WHERE operation_id = $1::uuid",
                        pqxx::params{request.operation_id});
  if (!existing.empty()) {
    if (existing[0]["request_fingerprint"].as<std::string>() != fingerprint) {
      throw IdempotencyConflictError(
          "repository-creation operation_id was already used with different content");
    }
    const std::string repository_id = existing[0]["repository_id"].as<std::string>();
    const pqxx::result repo_row = txn.exec_params(
        std::string("SELECT ") + kRepositorySelectColumns + " FROM repositories WHERE id = $1::uuid",
        pqxx::params{repository_id});
    txn.commit();
    return row_to_repository(repo_row[0]);
  }

  const std::string repository_id = common::generate_uuid_v4();
  const std::string audit_event_id = common::generate_uuid_v4();

  const pqxx::result inserted = txn.exec_params(
      std::string("INSERT INTO repositories (id, name, description, author, organization, tags) "
                    "VALUES ($1::uuid,$2,$3,$4,$5,$6) RETURNING ") +
          kRepositorySelectColumns,
      pqxx::params{repository_id, request.name, request.description, request.author, request.organization,
                    request.tags});

  txn.exec_params(
      "INSERT INTO repository_creation_operations (operation_id, request_fingerprint, repository_id) "
      "VALUES ($1::uuid,$2,$3::uuid)",
      pqxx::params{request.operation_id, fingerprint, repository_id});

  // ADR-0006 SS21: repository-creation MUST produce an audit record, in
  // the SAME atomic boundary as the repository row and idempotency
  // record above (ADR-0006's own repository-creation atomicity
  // correction) -- all committed together by the one txn.commit() below,
  // never as a separate, later write.
  txn.exec_params(
      "INSERT INTO audit_events (event_id, repository_id, event_type, actor) "
      "VALUES ($1::uuid,$2::uuid,'repository_created','')",
      pqxx::params{audit_event_id, repository_id});

  txn.commit();
  return row_to_repository(inserted[0]);
}

std::optional<domain::RepositoryMetadata> ServerRepositoryStore::get_repository(const std::string& repository_id) {
  if (!common::is_uuid_like(repository_id)) {
    return std::nullopt;
  }
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kRepositorySelectColumns + " FROM repositories WHERE id = $1::uuid",
      pqxx::params{repository_id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_repository(result[0]);
}

std::vector<domain::RepositoryMetadata> ServerRepositoryStore::list_repositories() {
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  const pqxx::result result =
      txn.exec(std::string("SELECT ") + kRepositorySelectColumns + " FROM repositories ORDER BY created_at ASC");
  txn.commit();
  std::vector<domain::RepositoryMetadata> repositories;
  repositories.reserve(result.size());
  for (const auto& row : result) {
    repositories.push_back(row_to_repository(row));
  }
  return repositories;
}

domain::CommitResult ServerRepositoryStore::submit_commit(const std::string& repository_id,
                                                              const domain::CommitRequest& request) {
  const std::string fingerprint = fingerprint_of(request);

  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());

  const pqxx::result repo_check =
      txn.exec_params("SELECT 1 FROM repositories WHERE id = $1::uuid", pqxx::params{repository_id});
  if (repo_check.empty()) {
    throw NotFoundError("no repository exists with that id");
  }

  // ADR-0006 SS9/SS26: REPOSITORY-SCOPED idempotency check.
  const pqxx::result existing_commit =
      txn.exec_params("SELECT commit_id::text AS commit_id, request_fingerprint FROM commits "
                        "WHERE repository_id = $1::uuid AND operation_id = $2::uuid",
                        pqxx::params{repository_id, request.operation_id});
  if (!existing_commit.empty()) {
    if (existing_commit[0]["request_fingerprint"].as<std::string>() != fingerprint) {
      throw IdempotencyConflictError("commit operation_id was already used with different content");
    }
    const std::string commit_id = existing_commit[0]["commit_id"].as<std::string>();
    txn.commit();
    auto result = get_commit_with_connection(lease.get(), repository_id, commit_id);
    if (!result.has_value()) {
      throw std::runtime_error("idempotent commit record vanished unexpectedly");
    }
    return *result;
  }

  domain::CommitResult result;
  result.repository_id = repository_id;
  result.commit_id = common::generate_uuid_v4();
  result.operation_id = request.operation_id;
  result.created_at = common::current_timestamp_utc();
  result.audit_event_id = common::generate_uuid_v4();
  int seq = 0;

  // The `commits` row MUST be inserted before any `commit_mutations` row
  // (a bug found and fixed live, WP-SRV-011): `commit_mutations.commit_id`
  // has a foreign key to `commits.commit_id`, so inserting mutations
  // first (as an earlier version of this method did, generating the
  // commits row only at the very end) violated that constraint on every
  // commit. `audit_event_id` is generated here too, ahead of the
  // `audit_events` row it references -- safe, since that column carries
  // no foreign-key constraint (see the schema comment in
  // migrations/V1__initial_schema.sql on why that link is
  // application-enforced rather than database-enforced).
  txn.exec_params(
      "INSERT INTO commits (commit_id, repository_id, operation_id, request_fingerprint, audit_event_id) "
      "VALUES ($1::uuid,$2::uuid,$3::uuid,$4,$5::uuid)",
      pqxx::params{result.commit_id, repository_id, request.operation_id, fingerprint, result.audit_event_id});

  // WP-SRV-012 / ADR-0006 SS10: the relationship_ids THIS SAME commit
  // also deletes -- known directly from the request, independent of
  // processing order, so an object-delete mutation (processed below,
  // before relationships) can recognize "this live relationship IS being
  // deleted in this same commit" without needing relationships to be
  // processed first (the object A + relationships R1/R2 example, SS10).
  std::set<std::string> relationship_deletes_in_commit;
  for (const auto& mutation : request.relationship_mutations) {
    if (mutation.kind == MutationKind::Delete) {
      relationship_deletes_in_commit.insert(mutation.relationship_id);
    }
  }

  // Objects first, then relationships -- so a relationship created in
  // the same commit as its endpoint objects sees those objects' just-
  // inserted `object_heads` rows (read-your-own-writes, within this one
  // transaction), satisfying ADR-0006 SS19's "create an object and
  // connect it in one atomic step" requirement without any special
  // casing.
  for (const auto& mutation : request.object_mutations) {
    if (mutation.kind == MutationKind::Delete) {
      const pqxx::result head = txn.exec_params(
          "SELECT current_revision FROM object_heads WHERE object_id = $1::uuid AND repository_id = $2::uuid "
          "FOR UPDATE",
          pqxx::params{mutation.object_id, repository_id});
      if (head.empty()) {
        throw ValidationError("object does not exist: cannot delete a nonexistent object");
      }
      const std::int64_t current_revision = head[0]["current_revision"].as<std::int64_t>();
      if (!mutation.expected_revision.has_value() || *mutation.expected_revision != current_revision) {
        throw ConcurrencyConflictError("expected_revision does not match the current revision for object");
      }

      // ADR-0006 SS10: an object may not be tombstoned while a live
      // relationship still references it as source or target, unless
      // that relationship is ALSO deleted atomically in this same
      // commit. `FOR UPDATE OF h` locks each live candidate's
      // relationship_heads row for the rest of this transaction, and the
      // relationship create/update path below takes a matching lock on
      // this object's own object_heads row -- together they close the
      // race where a concurrent commit tries to create/leave a live
      // relationship pointing at this object while it is being deleted.
      const pqxx::result live_relationships = txn.exec_params(
          "SELECT h.relationship_id::text AS relationship_id FROM relationship_heads h "
          "JOIN relationships r ON r.relationship_id = h.relationship_id AND r.revision = h.current_revision "
          "WHERE h.repository_id = $2::uuid AND h.is_tombstoned = false "
          "AND (r.source_object_id = $1::uuid OR r.target_object_id = $1::uuid) "
          "FOR UPDATE OF h",
          pqxx::params{mutation.object_id, repository_id});
      for (const auto& row : live_relationships) {
        if (!relationship_deletes_in_commit.count(row["relationship_id"].as<std::string>())) {
          throw ValidationError(
              "cannot delete object: a live relationship still references it and is not deleted in this same "
              "commit");
        }
      }

      const std::int64_t new_revision = current_revision + 1;

      // The tombstone revision's content is copied forward from the
      // current revision -- the client supplies only object_id/
      // expected_revision for a delete (ADR-0006 SS10/SS101).
      const pqxx::result current_row = txn.exec_params(
          std::string("SELECT ") + kObjectSelectColumns +
              " FROM objects WHERE object_id = $1::uuid AND repository_id = $2::uuid AND revision = $3",
          pqxx::params{mutation.object_id, repository_id, current_revision});
      const domain::EngineeringObject current_object = row_to_object(current_row[0]);

      txn.exec_params(
          "UPDATE object_heads SET current_revision = $1, is_tombstoned = true WHERE object_id = $2::uuid",
          pqxx::params{new_revision, mutation.object_id});

      txn.exec_params(
          "INSERT INTO objects (object_id, revision, repository_id, object_type, name, description, author, "
          "tags, content, version, commit_id, is_tombstoned) "
          "VALUES ($1::uuid,$2,$3::uuid,$4,$5,$6,$7,$8,$9,$10,$11::uuid,true)",
          pqxx::params{mutation.object_id, new_revision, repository_id,
                        domain::to_string(current_object.object_type), current_object.name,
                        current_object.description, current_object.author, current_object.tags,
                        current_object.content, current_object.version, result.commit_id});

      txn.exec_params(
          "INSERT INTO commit_mutations (commit_id, seq, is_relationship, entity_id, resulting_revision, "
          "is_delete) VALUES ($1::uuid,$2,false,$3::uuid,$4,true)",
          pqxx::params{result.commit_id, seq++, mutation.object_id, new_revision});

      result.object_results.push_back(domain::MutationResult{false, mutation.object_id, new_revision});
      continue;
    }

    std::int64_t new_revision = 1;
    if (mutation.kind == MutationKind::Update) {
      const pqxx::result head = txn.exec_params(
          "SELECT current_revision FROM object_heads WHERE object_id = $1::uuid AND repository_id = $2::uuid "
          "FOR UPDATE",
          pqxx::params{mutation.object_id, repository_id});
      if (head.empty()) {
        throw ValidationError("object does not exist: cannot update a nonexistent object");
      }
      const std::int64_t current_revision = head[0]["current_revision"].as<std::int64_t>();
      if (!mutation.expected_revision.has_value() || *mutation.expected_revision != current_revision) {
        throw ConcurrencyConflictError("expected_revision does not match the current revision for object");
      }
      new_revision = current_revision + 1;
      // WP-SRV-012 / ADR-0006 SS10: an ordinary update mutation applied
      // against a currently-tombstoned identity is how restoration is
      // expressed -- it always produces a LIVE new revision regardless
      // of the previous revision's tombstone state, with no separate
      // restore operation needed or invented.
      txn.exec_params(
          "UPDATE object_heads SET current_revision = $1, is_tombstoned = false WHERE object_id = $2::uuid",
          pqxx::params{new_revision, mutation.object_id});
    } else {
      try {
        txn.exec_params("INSERT INTO object_heads (object_id, repository_id, current_revision, is_tombstoned) "
                          "VALUES ($1::uuid,$2::uuid,1,false)",
                          pqxx::params{mutation.object_id, repository_id});
      } catch (const pqxx::unique_violation&) {
        throw ValidationError("an object with that id already exists");
      }
    }

    txn.exec_params(
        "INSERT INTO objects (object_id, revision, repository_id, object_type, name, description, author, "
        "tags, content, version, commit_id, is_tombstoned) "
        "VALUES ($1::uuid,$2,$3::uuid,$4,$5,$6,$7,$8,$9,$10,$11::uuid,false)",
        pqxx::params{mutation.object_id, new_revision, repository_id, domain::to_string(mutation.object_type),
                      mutation.name, mutation.description, mutation.author, mutation.tags, mutation.content,
                      mutation.version, result.commit_id});

    txn.exec_params(
        "INSERT INTO commit_mutations (commit_id, seq, is_relationship, entity_id, resulting_revision, "
        "is_delete) VALUES ($1::uuid,$2,false,$3::uuid,$4,false)",
        pqxx::params{result.commit_id, seq++, mutation.object_id, new_revision});

    result.object_results.push_back(domain::MutationResult{false, mutation.object_id, new_revision});
  }

  for (const auto& mutation : request.relationship_mutations) {
    if (mutation.kind == MutationKind::Delete) {
      const pqxx::result head = txn.exec_params(
          "SELECT current_revision FROM relationship_heads WHERE relationship_id = $1::uuid AND "
          "repository_id = $2::uuid FOR UPDATE",
          pqxx::params{mutation.relationship_id, repository_id});
      if (head.empty()) {
        throw ValidationError("relationship does not exist: cannot delete a nonexistent relationship");
      }
      const std::int64_t current_revision = head[0]["current_revision"].as<std::int64_t>();
      if (!mutation.expected_revision.has_value() || *mutation.expected_revision != current_revision) {
        throw ConcurrencyConflictError("expected_revision does not match the current revision for relationship");
      }
      const std::int64_t new_revision = current_revision + 1;

      const pqxx::result current_row = txn.exec_params(
          std::string("SELECT ") + kRelationshipSelectColumns +
              " FROM relationships WHERE relationship_id = $1::uuid AND repository_id = $2::uuid AND revision = $3",
          pqxx::params{mutation.relationship_id, repository_id, current_revision});
      const domain::Relationship current_relationship = row_to_relationship(current_row[0]);

      txn.exec_params(
          "UPDATE relationship_heads SET current_revision = $1, is_tombstoned = true WHERE relationship_id = "
          "$2::uuid",
          pqxx::params{new_revision, mutation.relationship_id});

      txn.exec_params(
          "INSERT INTO relationships (relationship_id, revision, repository_id, source_object_id, "
          "target_object_id, relationship_type, description, author, commit_id, is_tombstoned) "
          "VALUES ($1::uuid,$2,$3::uuid,$4::uuid,$5::uuid,$6,$7,$8,$9::uuid,true)",
          pqxx::params{mutation.relationship_id, new_revision, repository_id,
                        current_relationship.source_object_id, current_relationship.target_object_id,
                        domain::to_string(current_relationship.relationship_type),
                        current_relationship.description, current_relationship.author, result.commit_id});

      txn.exec_params(
          "INSERT INTO commit_mutations (commit_id, seq, is_relationship, entity_id, resulting_revision, "
          "is_delete) VALUES ($1::uuid,$2,true,$3::uuid,$4,true)",
          pqxx::params{result.commit_id, seq++, mutation.relationship_id, new_revision});

      result.relationship_results.push_back(domain::MutationResult{true, mutation.relationship_id, new_revision});
      continue;
    }

    if (mutation.source_object_id == mutation.target_object_id) {
      throw ValidationError("a relationship's source and target must differ");
    }

    // WP-SRV-012: locks both endpoint objects' head rows (in a single
    // query, ascending object_id order -- a consistent lock order across
    // every caller of this code path, so two concurrent relationship
    // mutations touching the same two objects in opposite roles cannot
    // deadlock each other) FOR UPDATE, not a plain SELECT. This
    // serializes relationship create/update against a concurrent commit
    // that is tombstoning one of these same objects (which takes the
    // matching lock on its own object_heads row above), so "does this
    // endpoint currently exist and is it live" cannot go stale before
    // this transaction commits.
    const pqxx::result endpoints = txn.exec_params(
        "SELECT object_id::text AS object_id, is_tombstoned FROM object_heads "
        "WHERE repository_id = $1::uuid AND object_id IN ($2::uuid, $3::uuid) "
        "ORDER BY object_id FOR UPDATE",
        pqxx::params{repository_id, mutation.source_object_id, mutation.target_object_id});
    bool source_live = false;
    bool target_live = false;
    for (const auto& row : endpoints) {
      const std::string id = row["object_id"].as<std::string>();
      const bool tombstoned = row["is_tombstoned"].as<bool>();
      if (id == mutation.source_object_id && !tombstoned) {
        source_live = true;
      }
      if (id == mutation.target_object_id && !tombstoned) {
        target_live = true;
      }
    }
    if (!source_live) {
      throw ValidationError("relationship source_object_id does not exist (or has been deleted) in this repository");
    }
    if (!target_live) {
      throw ValidationError("relationship target_object_id does not exist (or has been deleted) in this repository");
    }

    std::int64_t new_revision = 1;
    if (mutation.kind == MutationKind::Update) {
      const pqxx::result head = txn.exec_params(
          "SELECT current_revision FROM relationship_heads WHERE relationship_id = $1::uuid AND "
          "repository_id = $2::uuid FOR UPDATE",
          pqxx::params{mutation.relationship_id, repository_id});
      if (head.empty()) {
        throw ValidationError("relationship does not exist: cannot update a nonexistent relationship");
      }
      const std::int64_t current_revision = head[0]["current_revision"].as<std::int64_t>();
      if (!mutation.expected_revision.has_value() || *mutation.expected_revision != current_revision) {
        throw ConcurrencyConflictError("expected_revision does not match the current revision for relationship");
      }
      new_revision = current_revision + 1;
      // Restoration, symmetric with the object path above.
      txn.exec_params(
          "UPDATE relationship_heads SET current_revision = $1, is_tombstoned = false WHERE relationship_id = "
          "$2::uuid",
          pqxx::params{new_revision, mutation.relationship_id});
    } else {
      try {
        txn.exec_params(
            "INSERT INTO relationship_heads (relationship_id, repository_id, current_revision, is_tombstoned) "
            "VALUES ($1::uuid,$2::uuid,1,false)",
            pqxx::params{mutation.relationship_id, repository_id});
      } catch (const pqxx::unique_violation&) {
        throw ValidationError("a relationship with that id already exists");
      }
    }

    txn.exec_params(
        "INSERT INTO relationships (relationship_id, revision, repository_id, source_object_id, "
        "target_object_id, relationship_type, description, author, commit_id, is_tombstoned) "
        "VALUES ($1::uuid,$2,$3::uuid,$4::uuid,$5::uuid,$6,$7,$8,$9::uuid,false)",
        pqxx::params{mutation.relationship_id, new_revision, repository_id, mutation.source_object_id,
                      mutation.target_object_id, domain::to_string(mutation.relationship_type),
                      mutation.description, mutation.author, result.commit_id});

    txn.exec_params(
        "INSERT INTO commit_mutations (commit_id, seq, is_relationship, entity_id, resulting_revision, "
        "is_delete) VALUES ($1::uuid,$2,true,$3::uuid,$4,false)",
        pqxx::params{result.commit_id, seq++, mutation.relationship_id, new_revision});

    result.relationship_results.push_back(domain::MutationResult{true, mutation.relationship_id, new_revision});
  }

  // ADR-0006 SS26/SS27: the audit association is part of this same
  // atomic transaction -- not a follow-up write after commit.
  txn.exec_params(
      "INSERT INTO audit_events (event_id, repository_id, event_type, commit_id, actor) "
      "VALUES ($1::uuid,$2::uuid,'commit_applied',$3::uuid,'')",
      pqxx::params{result.audit_event_id, repository_id, result.commit_id});

  txn.commit();
  return result;
}

std::optional<domain::EngineeringObject> ServerRepositoryStore::get_object(const std::string& repository_id,
                                                                               const std::string& object_id) {
  if (!common::is_uuid_like(repository_id) || !common::is_uuid_like(object_id)) {
    return std::nullopt;
  }
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  // Bug fixed live, WP-SRV-011: the original query joined `objects` and
  // `object_heads` in the FROM clause, but `kObjectSelectColumns`'
  // unqualified column list (`object_id::text AS object_id`, etc.) is
  // then ambiguous between the two tables' identically-named columns --
  // PostgreSQL rejected the query outright ("column reference is
  // ambiguous"), regardless of the WHERE clause's own table-qualified
  // references. A correlated subquery against `object_heads` (referencing
  // only `objects` in the FROM/SELECT) sidesteps the ambiguity entirely
  // rather than requiring every column in the shared SELECT-column
  // constant to be individually re-qualified.
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kObjectSelectColumns +
          " FROM objects WHERE object_id = $1::uuid AND repository_id = $2::uuid AND revision = "
          "(SELECT current_revision FROM object_heads WHERE object_id = $1::uuid)",
      pqxx::params{object_id, repository_id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_object(result[0]);
}

std::optional<domain::EngineeringObject> ServerRepositoryStore::get_object_revision(
    const std::string& repository_id, const std::string& object_id, std::int64_t revision) {
  if (!common::is_uuid_like(repository_id) || !common::is_uuid_like(object_id)) {
    return std::nullopt;
  }
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kObjectSelectColumns +
          " FROM objects WHERE object_id = $1::uuid AND repository_id = $2::uuid AND revision = $3",
      pqxx::params{object_id, repository_id, revision});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_object(result[0]);
}

std::vector<domain::EngineeringObject> ServerRepositoryStore::list_objects(const std::string& repository_id) {
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  const pqxx::result repo_check =
      txn.exec_params("SELECT 1 FROM repositories WHERE id = $1::uuid", pqxx::params{repository_id});
  if (repo_check.empty()) {
    throw NotFoundError("no repository exists with that id");
  }
  // Same correlated-subquery shape as get_object -- each row's current
  // revision is looked up against object_heads without joining it (and
  // therefore without object_heads' identically-named columns making the
  // shared kObjectSelectColumns list ambiguous). WP-SRV-012: a tombstoned
  // object is excluded here -- this route enumerates the repository's
  // *current, live* objects (WP-SRV-011B), and a tombstoned object has no
  // live current state, exactly as single-object GET now also treats it.
  // The head's and its current revision row's `is_tombstoned` are always
  // written together (every INSERT/UPDATE pair below keeps them in sync),
  // so filtering on the row's own column is equivalent to filtering on
  // the head's and needs no extra join.
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kObjectSelectColumns +
          " FROM objects WHERE repository_id = $1::uuid AND NOT is_tombstoned AND revision = "
          "(SELECT current_revision FROM object_heads WHERE object_heads.object_id = objects.object_id) "
          "ORDER BY created_at ASC",
      pqxx::params{repository_id});
  txn.commit();
  std::vector<domain::EngineeringObject> objects;
  objects.reserve(result.size());
  for (const auto& row : result) {
    objects.push_back(row_to_object(row));
  }
  return objects;
}

std::optional<domain::Relationship> ServerRepositoryStore::get_relationship(const std::string& repository_id,
                                                                                const std::string& relationship_id) {
  if (!common::is_uuid_like(repository_id) || !common::is_uuid_like(relationship_id)) {
    return std::nullopt;
  }
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  // Same ambiguous-column fix as get_object above.
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kRelationshipSelectColumns +
          " FROM relationships WHERE relationship_id = $1::uuid AND repository_id = $2::uuid AND revision = "
          "(SELECT current_revision FROM relationship_heads WHERE relationship_id = $1::uuid)",
      pqxx::params{relationship_id, repository_id});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_relationship(result[0]);
}

std::optional<domain::Relationship> ServerRepositoryStore::get_relationship_revision(
    const std::string& repository_id, const std::string& relationship_id, std::int64_t revision) {
  if (!common::is_uuid_like(repository_id) || !common::is_uuid_like(relationship_id)) {
    return std::nullopt;
  }
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kRelationshipSelectColumns +
          " FROM relationships WHERE relationship_id = $1::uuid AND repository_id = $2::uuid AND revision = $3",
      pqxx::params{relationship_id, repository_id, revision});
  txn.commit();
  if (result.empty()) {
    return std::nullopt;
  }
  return row_to_relationship(result[0]);
}

std::vector<domain::Relationship> ServerRepositoryStore::list_relationships(const std::string& repository_id) {
  auto lease = pool_->acquire();
  pqxx::work txn(lease.get());
  const pqxx::result repo_check =
      txn.exec_params("SELECT 1 FROM repositories WHERE id = $1::uuid", pqxx::params{repository_id});
  if (repo_check.empty()) {
    throw NotFoundError("no repository exists with that id");
  }
  // WP-SRV-012: excludes tombstoned relationships -- see list_objects'
  // own comment above for why.
  const pqxx::result result = txn.exec_params(
      std::string("SELECT ") + kRelationshipSelectColumns +
          " FROM relationships WHERE repository_id = $1::uuid AND NOT is_tombstoned AND revision = "
          "(SELECT current_revision FROM relationship_heads WHERE relationship_heads.relationship_id = "
          "relationships.relationship_id) ORDER BY created_at ASC",
      pqxx::params{repository_id});
  txn.commit();
  std::vector<domain::Relationship> relationships;
  relationships.reserve(result.size());
  for (const auto& row : result) {
    relationships.push_back(row_to_relationship(row));
  }
  return relationships;
}

std::optional<domain::CommitResult> ServerRepositoryStore::get_commit(const std::string& repository_id,
                                                                          const std::string& commit_id) {
  auto lease = pool_->acquire();
  return get_commit_with_connection(lease.get(), repository_id, commit_id);
}

std::optional<domain::CommitResult> ServerRepositoryStore::get_commit_with_connection(
    pqxx::connection& connection, const std::string& repository_id, const std::string& commit_id) {
  if (!common::is_uuid_like(repository_id) || !common::is_uuid_like(commit_id)) {
    return std::nullopt;
  }
  pqxx::work txn(connection);
  const pqxx::result commit_row = txn.exec_params(
      "SELECT commit_id::text AS commit_id, repository_id::text AS repository_id, operation_id::text AS "
      "operation_id, audit_event_id::text AS audit_event_id, "
      "to_char(created_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at_text "
      "FROM commits WHERE commit_id = $1::uuid AND repository_id = $2::uuid",
      pqxx::params{commit_id, repository_id});
  if (commit_row.empty()) {
    txn.commit();
    return std::nullopt;
  }

  domain::CommitResult result;
  result.commit_id = commit_row[0]["commit_id"].as<std::string>();
  result.repository_id = commit_row[0]["repository_id"].as<std::string>();
  result.operation_id = commit_row[0]["operation_id"].as<std::string>();
  result.audit_event_id = commit_row[0]["audit_event_id"].as<std::string>();
  result.created_at = commit_row[0]["created_at_text"].as<std::string>();

  const pqxx::result mutation_rows = txn.exec_params(
      "SELECT is_relationship, entity_id::text AS entity_id, resulting_revision FROM commit_mutations "
      "WHERE commit_id = $1::uuid ORDER BY seq ASC",
      pqxx::params{commit_id});
  txn.commit();

  for (const auto& row : mutation_rows) {
    domain::MutationResult mutation_result;
    mutation_result.is_relationship = row["is_relationship"].as<bool>();
    mutation_result.id = row["entity_id"].as<std::string>();
    mutation_result.resulting_revision = row["resulting_revision"].as<std::int64_t>();
    if (mutation_result.is_relationship) {
      result.relationship_results.push_back(mutation_result);
    } else {
      result.object_results.push_back(mutation_result);
    }
  }

  return result;
}

}  // namespace oep::server_repository::persistence
