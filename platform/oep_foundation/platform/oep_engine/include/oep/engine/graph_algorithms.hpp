#pragma once

#include <string>
#include <vector>

#include "oep/engine/knowledge_graph.hpp"

namespace oep::engine {

struct ComponentsResult {
    bool success = false;
    std::string error;
    // Every connected component in the graph (undirected connectivity),
    // each component's object ids sorted, components themselves sorted
    // by their first (smallest) id -- deterministic regardless of
    // iteration order.
    std::vector<std::vector<std::string>> components;
};

struct GraphPathResult {
    bool success = false;
    std::string error;
    bool path_exists = false;
    std::vector<std::string> path; // source..target inclusive; meaningful only when path_exists
};

struct ReachabilityResult {
    bool success = false;
    std::string error;
    bool reachable = false;
};

struct NeighborhoodResult {
    bool success = false;
    std::string error;
    std::vector<std::string> object_ids; // sorted, excludes the center object itself
};

struct GraphSubgraphResult {
    bool success = false;
    std::string error;
    std::vector<std::string> object_ids;
    std::vector<std::string> relationship_ids;
};

struct RelationshipExpansionResult {
    bool success = false;
    std::string error;
    std::vector<std::string> relationship_ids; // sorted
};

// WP-EKE-002's Graph Algorithms. Every algorithm is deterministic and a
// pure function of `graph` (no mutation, no Foundation access).
class GraphAlgorithms {
public:
    static ComponentsResult connected_components(const KnowledgeGraph& graph);
    static GraphPathResult shortest_path(const KnowledgeGraph& graph, const std::string& source_object_id,
                                     const std::string& target_object_id);
    static ReachabilityResult reachable(const KnowledgeGraph& graph, const std::string& source_object_id,
                                         const std::string& target_object_id);
    // Every object within `radius` hops of `object_id` (radius 0 == just
    // the object itself, excluded from the result; radius 1 == direct
    // neighbors; etc).
    static NeighborhoodResult neighborhood(const KnowledgeGraph& graph, const std::string& object_id, int radius);
    static GraphSubgraphResult subgraph(const KnowledgeGraph& graph, const std::vector<std::string>& object_ids);
    // Every relationship of `type` touching `object_id`, either direction.
    static RelationshipExpansionResult expand_relationships(const KnowledgeGraph& graph, const std::string& object_id,
                                                              oep::repository::RelationshipType type);
};

} // namespace oep::engine
