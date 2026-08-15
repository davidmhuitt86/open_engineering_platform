#pragma once

#include <map>
#include <string>
#include <vector>

#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/repository/relationship_store.hpp"

namespace oep::repository {

struct GraphNeighbor {
    std::string object_id;
    std::string relationship_id;
    RelationshipType relationship_type;
};

struct NeighborsResult {
    bool success = false;
    std::string error;
    std::vector<GraphNeighbor> neighbors;
};

struct TraversalResult {
    bool success = false;
    std::string error;
    std::vector<std::string> object_ids; // in traversal order
};

struct PathExistsResult {
    bool success = false;
    std::string error;
    bool path_exists = false;
};

// An in-memory graph over a repository's Engineering Objects (nodes)
// and Relationships (edges), per OEP-SPEC-007-GRAPH_TRAVERSAL. Built
// on demand from an ObjectStore/RelationshipStore; never persisted,
// never modifies repository contents.
//
// Relationships are directional by identity (OEP-SPEC-005), but for
// connectivity purposes (neighbor discovery, traversal, path
// existence) this graph treats every relationship as connecting its
// two objects in both directions; the connecting relationship's
// declared type and ID are preserved on the edge so callers can see
// the original semantics.
//
// A relationship whose source or target object no longer exists is
// excluded from the graph.
class GraphEngine {
public:
    void build_graph(const ObjectStore& objects, const RelationshipStore& relationships);
    void clear_graph();

    // Every object directly connected to `object_id`, sorted by
    // neighbor object_id (then relationship_id) for determinism.
    NeighborsResult get_neighbors(const std::string& object_id) const;

    // Deterministic breadth-first traversal starting at `start_object_id`.
    TraversalResult traverse_breadth_first(const std::string& start_object_id) const;

    // Deterministic depth-first (pre-order) traversal starting at `start_object_id`.
    TraversalResult traverse_depth_first(const std::string& start_object_id) const;

    // Reports only whether a path exists; does not compute the path itself.
    PathExistsResult path_exists(const std::string& source_object_id, const std::string& target_object_id) const;

private:
    std::map<std::string, std::vector<GraphNeighbor>> adjacency_;

    bool has_node(const std::string& object_id) const;
};

} // namespace oep::repository
