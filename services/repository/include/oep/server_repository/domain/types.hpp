#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

// WP-SRV-011 / ADR-0006 SS3, SS5: these types are an INDEPENDENT,
// server-side definition of Engineering Object / Relationship shape --
// they deliberately mirror Foundation's own OEP-SPEC-004/005 field names
// and semantics (same identity scheme, same type/relationship
// enumerations) but do not include or link against
// `platform/oep_foundation` in any way. This is the ADR-0006-mandated
// boundary: "MAY reuse Foundation domain types or validation primitives
// where architecturally appropriate, but MUST NOT silently import
// Foundation's repository persistence model." Reusing the *shape* (so a
// published object's fields translate directly) without reusing the
// *implementation* (so this service has no build/link dependency on
// Foundation, and Foundation is not made to depend on the server in any
// way) is exactly the distinction ADR-0004 SS9 requires.

namespace oep::server_repository::domain {

// Mirrors Foundation's ObjectType (engineering_object.hpp) exactly.
enum class ObjectType {
  Document,
  Diagram,
  Component,
  Procedure,
  Project,
  Image,
};

[[nodiscard]] std::string to_string(ObjectType type);
[[nodiscard]] std::optional<ObjectType> object_type_from_string(const std::string& value);

// Mirrors Foundation's RelationshipType (relationship.hpp) exactly.
enum class RelationshipType {
  References,
  Contains,
  DependsOn,
  ConnectedTo,
  Documents,
  Implements,
};

[[nodiscard]] std::string to_string(RelationshipType type);
[[nodiscard]] std::optional<RelationshipType> relationship_type_from_string(const std::string& value);

/// A server-resident repository (ADR-0004 SS4): identity + metadata only
/// -- membership (which objects/relationships belong to it) is not
/// carried on this struct, it is a property of the objects/relationships
/// themselves (their own `repository_id`).
struct RepositoryMetadata {
  std::string repository_id;
  std::string name;
  std::string description;
  std::string author;
  std::string organization;
  // Comma-separated (ADR-0006 SS16 does not mandate a wire array
  // representation; a flat string is the simplest persistence-layer
  // shape and is translated to/from a JSON array at the API boundary).
  std::string tags;
  std::string created_at;
  std::string updated_at;
};

/// A server-resident Engineering Object at a specific revision
/// (ADR-0004 SS7, SS6).
struct EngineeringObject {
  std::string object_id;
  std::string repository_id;
  std::int64_t revision = 0;
  ObjectType object_type = ObjectType::Document;
  std::string name;
  std::string description;
  std::string author;
  std::string tags;
  std::string content;
  std::string version = "1.0.0";
  std::string commit_id;
  std::string created_at;
  // WP-SRV-012 / ADR-0006 SS10: true iff THIS revision is the tombstone
  // revision (a delete mutation). Never true for revisions before the
  // delete, and false again for any later revision that restores the
  // object (a normal, non-delete mutation applied after a tombstone).
  bool is_tombstoned = false;
};

/// A server-resident Relationship at a specific revision (ADR-0004 SS7,
/// SS7 of the contract).
struct Relationship {
  std::string relationship_id;
  std::string repository_id;
  std::int64_t revision = 0;
  std::string source_object_id;
  std::string target_object_id;
  RelationshipType relationship_type = RelationshipType::References;
  std::string description;
  std::string author;
  std::string commit_id;
  std::string created_at;
  bool is_tombstoned = false;
};

/// WP-SRV-012 / ADR-0006 SS10: a mutation is one of three kinds. `Delete`
/// creates a tombstone revision -- a specific kind of mutation, not a
/// different, non-revisioned operation (ADR-0006 SS10) -- and, symmetrically,
/// a `Create`/`Update` mutation applied against a currently-tombstoned
/// identity is how restoration is expressed (ADR-0006 SS10: "restored...
/// by a subsequent create-shaped mutation"): no separate restore operation
/// exists or is needed.
enum class MutationKind { Create, Update, Delete };

/// One mutation within a commit (ADR-0006 SS8). `expected_revision`
/// absent means "must not already exist" (a create); present means "must
/// currently be at this revision" (an update or delete, ADR-0004 SS10).
/// A `Delete` mutation carries only `object_id`/`expected_revision` --
/// the remaining fields are unused (the tombstone revision's content is
/// copied forward from the current revision by the server, not supplied
/// by the client, ADR-0006 SS10).
struct ObjectMutation {
  MutationKind kind = MutationKind::Create;
  std::string object_id;
  std::optional<std::int64_t> expected_revision;
  ObjectType object_type = ObjectType::Document;
  std::string name;
  std::string description;
  std::string author;
  std::string tags;
  std::string content;
  std::string version = "1.0.0";
};

/// Same shape as `ObjectMutation`; a `Delete` mutation carries only
/// `relationship_id`/`expected_revision`.
struct RelationshipMutation {
  MutationKind kind = MutationKind::Create;
  std::string relationship_id;
  std::optional<std::int64_t> expected_revision;
  std::string source_object_id;
  std::string target_object_id;
  RelationshipType relationship_type = RelationshipType::References;
  std::string description;
  std::string author;
};

/// A single atomic commit request (ADR-0006 SS8): a client-generated,
/// repository-scoped operation identity plus the mutations it covers.
struct CommitRequest {
  std::string operation_id;
  std::vector<ObjectMutation> object_mutations;
  std::vector<RelationshipMutation> relationship_mutations;
};

struct MutationResult {
  bool is_relationship = false;
  std::string id;
  std::int64_t resulting_revision = 0;
};

/// What a successful commit returns (ADR-0006 SS19/SS23).
struct CommitResult {
  std::string commit_id;
  std::string operation_id;
  std::string repository_id;
  std::vector<MutationResult> object_results;
  std::vector<MutationResult> relationship_results;
  std::string audit_event_id;
  std::string created_at;
};

/// A repository-creation request (ADR-0006 SS21): server-scoped
/// operation identity (SS9) + the initial metadata.
struct RepositoryCreateRequest {
  std::string operation_id;
  std::string name;
  std::string description;
  std::string author;
  std::string organization;
  std::string tags;
};

}  // namespace oep::server_repository::domain
