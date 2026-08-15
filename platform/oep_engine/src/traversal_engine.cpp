#include "oep/engine/traversal_engine.hpp"

#include <deque>
#include <set>

namespace oep::engine {

namespace {

std::vector<GraphEdge> filtered_edges(const RuntimeGraph& graph, const std::string& object_id,
                                       const TraversalOptions& options) {
    std::vector<GraphEdge> edges = graph.edges_of(object_id);
    if (!options.relationship_type_filter.has_value()) {
        return edges;
    }
    std::vector<GraphEdge> filtered;
    for (const GraphEdge& edge : edges) {
        if (edge.relationship_type == *options.relationship_type_filter) {
            filtered.push_back(edge);
        }
    }
    return filtered;
}

TraversalResult traverse_breadth_first(const RuntimeGraph& graph, const std::string& start_object_id,
                                        const TraversalOptions& options) {
    TraversalResult result;
    result.success = true;

    std::set<std::string> visited;
    std::deque<std::pair<std::string, int>> queue; // (object_id, depth)
    queue.emplace_back(start_object_id, 0);
    visited.insert(start_object_id);

    while (!queue.empty()) {
        const auto [current_id, depth] = queue.front();
        queue.pop_front();
        result.object_ids.push_back(current_id);

        if (options.max_depth.has_value() && depth >= *options.max_depth) {
            continue;
        }
        for (const GraphEdge& edge : filtered_edges(graph, current_id, options)) {
            if (visited.insert(edge.neighbor_object_id).second) {
                queue.emplace_back(edge.neighbor_object_id, depth + 1);
            }
        }
    }
    return result;
}

void traverse_depth_first_recursive(const RuntimeGraph& graph, const std::string& current_id, int depth,
                                     const TraversalOptions& options, std::set<std::string>& visited,
                                     std::vector<std::string>& out) {
    out.push_back(current_id);
    if (options.max_depth.has_value() && depth >= *options.max_depth) {
        return;
    }
    for (const GraphEdge& edge : filtered_edges(graph, current_id, options)) {
        if (visited.insert(edge.neighbor_object_id).second) {
            traverse_depth_first_recursive(graph, edge.neighbor_object_id, depth + 1, options, visited, out);
        }
    }
}

TraversalResult traverse_depth_first(const RuntimeGraph& graph, const std::string& start_object_id,
                                      const TraversalOptions& options) {
    TraversalResult result;
    result.success = true;
    std::set<std::string> visited{start_object_id};
    traverse_depth_first_recursive(graph, start_object_id, 0, options, visited, result.object_ids);
    return result;
}

} // namespace

TraversalResult traverse(const RuntimeGraph& graph, const std::string& start_object_id, const TraversalOptions& options) {
    if (!graph.contains(start_object_id)) {
        return TraversalResult{false, "object '" + start_object_id + "' is not present in the loaded graph", {}};
    }
    return options.order == TraversalOrder::BreadthFirst ? traverse_breadth_first(graph, start_object_id, options)
                                                           : traverse_depth_first(graph, start_object_id, options);
}

} // namespace oep::engine
