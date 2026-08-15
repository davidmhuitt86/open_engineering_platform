#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/engine/runtime_graph.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::engine {

enum class TraversalOrder {
    BreadthFirst,
    DepthFirst,
};

// `relationship_type_filter`: when set, only edges of this
// RelationshipType are followed. `max_depth`: when set, traversal stops
// extending past this many edges from `start_object_id` (the start
// node itself is depth 0); nullopt means unlimited.
struct TraversalOptions {
    TraversalOrder order = TraversalOrder::BreadthFirst;
    std::optional<oep::repository::RelationshipType> relationship_type_filter;
    std::optional<int> max_depth;
};

struct TraversalResult {
    bool success = false;
    std::string error;
    // Visited object ids, in traversal order. Each id appears exactly
    // once even if the graph contains a cycle back to it (cycle-safety
    // is provided by a visited-set, not by the graph being acyclic).
    std::vector<std::string> object_ids;
};

// Traverses `graph` starting at `start_object_id`, per `options`.
// Deterministic: at every node, neighbors are visited in the graph's
// own edge ordering (RuntimeGraph::edges_of, sorted by neighbor id then
// relationship id), so the same graph and options always produce the
// same traversal order. Fails (success == false) only if
// `start_object_id` is not present in `graph`.
TraversalResult traverse(const RuntimeGraph& graph, const std::string& start_object_id,
                          const TraversalOptions& options = {});

} // namespace oep::engine
