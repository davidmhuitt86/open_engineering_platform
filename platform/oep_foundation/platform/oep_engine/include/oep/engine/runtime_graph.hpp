#pragma once

#include <map>
#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::engine {

// WP-EKE-001: the Engineering Knowledge Runtime's OWN in-memory graph,
// built entirely from data the Engine already loaded through
// RuntimeService (see object_loader.hpp) — never from a live
// ObjectStore/RelationshipStore. This is a deliberate architectural
// duplication of shape (not logic) relative to
// oep::repository::GraphEngine: that class is a Foundation/Repository-
// layer concept, built directly against persistence and owned by
// FoundationRuntime; RuntimeGraph is an Engine-layer concept, built
// against whatever snapshot of objects/relationships the Engine most
// recently loaded, and knows nothing about persistence, transactions,
// trust, or storage paths. See platform/oep_engine's own README for the
// full rationale.

// One edge touching a node, from that node's point of view.
// `outgoing` is true when the node is the relationship's
// source_object_id (the relationship "points away" from this node).
struct GraphEdge {
    std::string relationship_id;
    std::string neighbor_object_id;
    oep::repository::RelationshipType relationship_type;
    bool outgoing = true;
};

// Builds and holds an in-memory graph over a snapshot of Engineering
// Objects (nodes) and Relationships (edges), with type/tag indexes for
// O(1) category lookups instead of a linear scan per query. Never
// mutates or persists anything; `build` fully replaces prior content.
//
// A relationship whose source or target object is not present in the
// object snapshot passed to `build` is excluded from the graph — this
// mirrors oep::repository::GraphEngine's own documented behavior for a
// dangling reference.
class RuntimeGraph {
public:
    RuntimeGraph() = default;

    void build(std::vector<oep::repository::EngineeringObject> objects,
               std::vector<oep::repository::Relationship> relationships);
    void clear();

    bool contains(const std::string& object_id) const;
    const oep::repository::EngineeringObject* find_object(const std::string& object_id) const;

    // Every object currently in the graph, sorted by object_id
    // (determinism, matching the rest of this codebase's convention).
    std::vector<const oep::repository::EngineeringObject*> all_objects() const;
    const std::vector<oep::repository::Relationship>& all_relationships() const { return relationships_; }

    // Edges touching `object_id`, sorted by neighbor_object_id then
    // relationship_id. Empty (not an error) if `object_id` is not in
    // the graph or has no edges.
    std::vector<GraphEdge> edges_of(const std::string& object_id) const;

    // Indexes, per WP-EKE-001's "Support ... Indexes" requirement.
    std::vector<std::string> object_ids_by_type(oep::repository::ObjectType type) const;

    // "Find by Domain" (WP-EKE-001's Graph Queries) is implemented
    // against EngineeringObject::tags — Foundation's Five Primitive
    // Rule (CLAUDE.md) forbids introducing a new "domain" field on
    // Engineering Objects without architectural approval, and `tags`
    // is the only existing free-form classification field on the
    // primitive; this method (and QueryEngine::find_by_domain, which
    // calls it) treat "domain" and "tag" as the same concept. See the
    // Engine README for this documented mapping.
    std::vector<std::string> object_ids_by_tag(const std::string& tag) const;

    std::size_t object_count() const { return objects_.size(); }
    std::size_t relationship_count() const { return relationships_.size(); }

private:
    std::map<std::string, oep::repository::EngineeringObject> objects_;
    std::vector<oep::repository::Relationship> relationships_;
    std::map<std::string, std::vector<GraphEdge>> adjacency_;
    std::map<oep::repository::ObjectType, std::vector<std::string>> by_type_;
    std::map<std::string, std::vector<std::string>> by_tag_;
};

} // namespace oep::engine
