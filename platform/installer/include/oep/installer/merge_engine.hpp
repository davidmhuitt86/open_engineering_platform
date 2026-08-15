#pragma once

#include <string>
#include <vector>

#include "oep/installer/oep_package_manifest.hpp"
#include "oep/installer/repository_change_set.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::installer {

// WP-REP-008's Merge Engine generalizes package installation
// (WP-REP-001) into an explicit plan-then-apply pipeline built on the
// canonical RepositoryChangeSet (repository_change_set.hpp): instead of
// install_package's "try to create each object, roll back the whole
// transaction if any create fails," a merge is first PLANNED —
// side-effect-free (requirement #6), comparing every object/relationship
// the source package declares against the target repository's existing
// content — producing a RepositoryChangeSet of everything that is
// genuinely NEW, plus a deterministic (requirement #7) list of
// conflicts for anything that already exists with DIFFERENT content.
// Only a conflict-free plan may be applied (by the caller, via
// FoundationRuntime::execute_merge — this module never mutates a
// repository itself). An object/relationship that already exists with
// IDENTICAL content is treated as an idempotent no-op: merge is safe to
// retry, unlike install_package's hard "already installed" rejection.
//
// This module never touches the network, never resolves federation or
// distributed synchronization, and never applies anything itself — it
// only compares and reports. Trust verification and Dependency
// Resolution are NOT performed here; FoundationRuntime::execute_merge
// (and its own plan_merge, which calls this planner) sequences those
// two subsystems BEFORE calling into this module, preserving the
// Trust-before-Dependency-before-Merge ordering WP-REP-008 requires at
// the Runtime level, exactly mirroring how install_package already
// sequences Trust-before-Dependency-before-Transaction.

enum class MergeConflictKind {
    // An Engineering Object with this object_id already exists in the
    // target repository, with content (name/description/author/version/
    // tags/object_type) that differs from the source's declaration.
    ObjectContentConflict,
    // A Relationship with this relationship_id already exists in the
    // target repository, with content that differs from the source's
    // declaration.
    RelationshipContentConflict,
    // The source declares a Relationship whose source_object_id or
    // target_object_id is neither already present in the target
    // repository NOR included as a Create in this same plan — merging
    // it would create a dangling reference.
    RelationshipMissingEndpoint,
};

std::string to_string(MergeConflictKind kind);

struct MergeConflict {
    MergeConflictKind kind = MergeConflictKind::ObjectContentConflict;
    std::string entity_id;
    std::string detail;
};

// The side-effect-free result of planning a merge (requirement #6):
// what WOULD change, and what stands in the way. `conflicts` is
// computed deterministically (requirement #7) — see plan_merge's own
// doc comment for the exact, stable ordering rule. `change_set` always
// reflects the non-conflicting portion of the source (objects/
// relationships that are new or already identical are simply omitted
// as no-ops for the identical case, included as Create entries for the
// new case); it is meaningful to inspect even when conflicts is
// non-empty, but FoundationRuntime::execute_merge refuses to apply any
// plan with conflicts.
struct MergePlan {
    RepositoryChangeSet change_set;
    std::vector<MergeConflict> conflicts;

    bool mergeable() const { return conflicts.empty(); }
};

// Plans merging `source_objects`/`source_relationships` (typically a
// package archive's Repository Fragment, per PKG-001 §7) into a target
// repository's current content, identified by `source_id` (used as the
// RepositoryChangeSet's provenance identifier — e.g. "packageId@version").
// Pure function: reads `target_objects`/`target_relationships`, writes
// nothing anywhere.
//
// Deterministic conflict ordering (requirement #7): conflicts are
// reported in the exact order their source entities appear in
// `source_objects` then `source_relationships` — never in target
// iteration order, hash order, or any other order that could vary
// between runs of the same input on different machines or filesystem
// orderings.
MergePlan plan_merge(const std::string& source_id, const std::vector<oep::repository::EngineeringObject>& source_objects,
                      const std::vector<oep::repository::Relationship>& source_relationships,
                      const std::vector<oep::repository::EngineeringObject>& target_objects,
                      const std::vector<oep::repository::Relationship>& target_relationships);

} // namespace oep::installer
