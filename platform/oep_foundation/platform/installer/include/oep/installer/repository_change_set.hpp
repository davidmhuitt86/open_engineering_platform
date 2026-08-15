#pragma once

#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::installer {

// The kind of mutation one change entry represents. WP-REP-008's Merge
// Engine planner (merge_engine.hpp) only ever produces Create entries —
// a differing pre-existing record is reported as a conflict, never
// silently overwritten (see MergeConflictKind) — but Update/Delete are
// part of RepositoryChangeSet's own vocabulary as the canonical
// representation for ANY Repository mutation, not merge-specific, so a
// future work package (or a different planner) can produce them without
// a schema change here.
enum class ChangeKind {
    Create,
    Update,
    Delete,
};

std::string to_string(ChangeKind kind);

// One Engineering Object mutation, immutable (WP-REP-008 requirement
// #4: RepositoryChangeSet is the canonical, immutable mutation
// representation). `object` carries the full record for Create/Update
// (and, for Delete, at minimum a populated object_id — the rest may be
// the last-known snapshot, useful for provenance/audit but not required
// to act on the Delete). `source_repository_id`/`source_object_id`
// preserve WHERE this change came from (WP-REP-008 requirement #5,
// "preserve complete ownership and provenance metadata") — for a merge
// sourced from a package archive, this is the package's own id/version
// string and the object's id as declared in that archive, which today
// are the same identifiers Foundation already uses (object identity is
// global, not archive-local), but keeping them as distinct fields keeps
// this type honest about provenance for future sources (e.g. a
// differently-identified external system) without a later schema change.
class ObjectChange {
public:
    ObjectChange(ChangeKind kind, oep::repository::EngineeringObject object, std::string source_repository_id,
                 std::string source_object_id)
        : kind_(kind),
          object_(std::move(object)),
          source_repository_id_(std::move(source_repository_id)),
          source_object_id_(std::move(source_object_id)) {}

    ChangeKind kind() const { return kind_; }
    const oep::repository::EngineeringObject& object() const { return object_; }
    const std::string& source_repository_id() const { return source_repository_id_; }
    const std::string& source_object_id() const { return source_object_id_; }

private:
    ChangeKind kind_;
    oep::repository::EngineeringObject object_;
    std::string source_repository_id_;
    std::string source_object_id_;
};

// One Relationship mutation, immutable. Same provenance rationale as
// ObjectChange.
class RelationshipChange {
public:
    RelationshipChange(ChangeKind kind, oep::repository::Relationship relationship, std::string source_repository_id,
                        std::string source_relationship_id)
        : kind_(kind),
          relationship_(std::move(relationship)),
          source_repository_id_(std::move(source_repository_id)),
          source_relationship_id_(std::move(source_relationship_id)) {}

    ChangeKind kind() const { return kind_; }
    const oep::repository::Relationship& relationship() const { return relationship_; }
    const std::string& source_repository_id() const { return source_repository_id_; }
    const std::string& source_relationship_id() const { return source_relationship_id_; }

private:
    ChangeKind kind_;
    oep::repository::Relationship relationship_;
    std::string source_repository_id_;
    std::string source_relationship_id_;
};

// The canonical, immutable representation of a set of Repository
// mutations (WP-REP-008 requirement #4), produced by a side-effect-free
// planning step (e.g. MergeEngine::plan_merge, requirement #6) and later
// applied — verbatim, entry by entry — inside exactly one Repository
// Transaction (requirement #2: state is never mutated outside a
// Transaction). A RepositoryChangeSet never mutates anything itself; it
// is pure data, carried between planning and application.
class RepositoryChangeSet {
public:
    // Default: an empty change set. Exists only so RepositoryChangeSet
    // can be a member of default-constructible Result types (e.g.
    // RuntimeMergePlanResult) elsewhere in the codebase; every
    // MEANINGFUL RepositoryChangeSet is still produced exclusively via
    // the constructor below, at planning time.
    RepositoryChangeSet() = default;

    RepositoryChangeSet(std::string source_repository_id, std::string description,
                         std::vector<ObjectChange> object_changes, std::vector<RelationshipChange> relationship_changes)
        : source_repository_id_(std::move(source_repository_id)),
          description_(std::move(description)),
          object_changes_(std::move(object_changes)),
          relationship_changes_(std::move(relationship_changes)) {}

    // Identifies where this change set came from as a whole (for
    // WP-REP-008's Merge Engine, the source package's packageId@version)
    // — provenance at the change-set level, distinct from (but usually
    // matching) each entry's own source_repository_id.
    const std::string& source_repository_id() const { return source_repository_id_; }
    const std::string& description() const { return description_; }
    const std::vector<ObjectChange>& object_changes() const { return object_changes_; }
    const std::vector<RelationshipChange>& relationship_changes() const { return relationship_changes_; }

    bool empty() const { return object_changes_.empty() && relationship_changes_.empty(); }

private:
    std::string source_repository_id_;
    std::string description_;
    std::vector<ObjectChange> object_changes_;
    std::vector<RelationshipChange> relationship_changes_;
};

} // namespace oep::installer
