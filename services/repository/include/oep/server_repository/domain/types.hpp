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
};

/// One mutation within a commit (ADR-0006 SS8). `expected_revision`
/// absent means "must not already exist" (a create); present means "must
/// currently be at this revision" (an update, ADR-0004 SS10).
struct ObjectMutation {
  bool is_update = false;
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

struct RelationshipMutation {
  bool is_update = false;
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
/// Delete mutations are explicitly out of scope for this first slice
/// (WP-SRV-011 Scope Exclusions).
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
