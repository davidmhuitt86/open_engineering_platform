#pragma once

#include <string>
#include <vector>

#include "oep/engine/runtime_graph.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::engine {

struct QueryResult {
    bool success = false;
    std::string error;
    std::vector<std::string> object_ids;
};

struct PathResult {
    bool success = false;
    std::string error;
    bool path_exists = false;
    // Object ids from source to target inclusive, in path order.
    // Meaningful only when path_exists is true.
    std::vector<std::string> path;
};

struct SubgraphResult {
    bool success = false;
    std::string error;
    std::vector<std::string> object_ids;
    std::vector<std::string> relationship_ids;
};

// WP-EKE-001's Query Engine: semantic, read-only queries over an
// already-loaded RuntimeGraph. Every method here is a pure function of
// `graph` — no Foundation/RuntimeService access.
class QueryEngine {
public:
    static QueryResult find_by_id(const RuntimeGraph& graph, const std::string& object_id);
    static QueryResult find_by_type(const RuntimeGraph& graph, oep::repository::ObjectType type);

    // See RuntimeGraph::object_ids_by_tag's doc comment for why "domain"
    // is mapped onto EngineeringObject::tags.
    static QueryResult find_by_domain(const RuntimeGraph& graph, const std::string& domain);

    // Every object that is an endpoint (source or target) of at least
    // one Relationship of `type`.
    static QueryResult find_by_relationship(const RuntimeGraph& graph, oep::repository::RelationshipType type);

    // Breadth-first shortest path (fewest edges; the graph is unweighted)
    // between `source_object_id` and `target_object_id`, treating every
    // relationship as bidirectional for connectivity purposes — the
    // same convention oep::repository::GraphEngine::path_exists uses,
    // extended here to also reconstruct the path itself.
    static PathResult shortest_path(const RuntimeGraph& graph, const std::string& source_object_id,
                                     const std::string& target_object_id);

    // Every object reachable from `start_object_id` by any path
    // (undirected reachability) — the connected component containing
    // it.
    static QueryResult connected_component(const RuntimeGraph& graph, const std::string& start_object_id);

    // The induced subgraph over exactly `object_ids`: every id that
    // exists in `graph` (nonexistent ids are silently skipped, not an
    // error — a subgraph is a filter, not a lookup), plus every
    // relationship in `graph` whose source AND target are both in that
    // set.
    static SubgraphResult subgraph(const RuntimeGraph& graph, const std::vector<std::string>& object_ids);
};

} // namespace oep::engine
