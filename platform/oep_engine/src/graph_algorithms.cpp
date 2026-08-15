#include "oep/engine/graph_algorithms.hpp"

#include <algorithm>
#include <deque>
#include <map>
#include <set>

namespace oep::engine {

ComponentsResult GraphAlgorithms::connected_components(const KnowledgeGraph& graph) {
    std::set<std::string> unvisited;
    for (const KnowledgeGraphNode* node : graph.all_nodes()) {
        unvisited.insert(node->object_id);
    }

    std::vector<std::vector<std::string>> components;
    while (!unvisited.empty()) {
        const std::string start = *unvisited.begin();
        std::vector<std::string> component;
        std::deque<std::string> queue{start};
        unvisited.erase(start);
        while (!queue.empty()) {
            const std::string current = queue.front();
            queue.pop_front();
            component.push_back(current);
            for (const KnowledgeGraphEdgeView& edge : graph.edges_of(current)) {
                if (unvisited.erase(edge.neighbor_object_id) != 0) {
                    queue.push_back(edge.neighbor_object_id);
                }
            }
        }
        std::sort(component.begin(), component.end());
        components.push_back(std::move(component));
    }
    std::sort(components.begin(), components.end(),
              [](const std::vector<std::string>& a, const std::vector<std::string>& b) {
                  if (a.empty() || b.empty()) return a.size() < b.size();
                  return a.front() < b.front();
              });
    return ComponentsResult{true, "", components};
}

GraphPathResult GraphAlgorithms::shortest_path(const KnowledgeGraph& graph, const std::string& source_object_id,
                                           const std::string& target_object_id) {
    if (!graph.contains(source_object_id) || !graph.contains(target_object_id)) {
        return GraphPathResult{false, "source and/or target object is not present in the graph", false, {}};
    }
    if (source_object_id == target_object_id) {
        return GraphPathResult{true, "", true, {source_object_id}};
    }
    std::map<std::string, std::string> came_from;
    std::set<std::string> visited{source_object_id};
    std::deque<std::string> queue{source_object_id};
    while (!queue.empty()) {
        const std::string current = queue.front();
        queue.pop_front();
        for (const KnowledgeGraphEdgeView& edge : graph.edges_of(current)) {
            if (!visited.insert(edge.neighbor_object_id).second) continue;
            came_from[edge.neighbor_object_id] = current;
            if (edge.neighbor_object_id == target_object_id) {
                std::vector<std::string> path{target_object_id};
                std::string cursor = target_object_id;
                while (cursor != source_object_id) {
                    cursor = came_from[cursor];
                    path.push_back(cursor);
                }
                std::reverse(path.begin(), path.end());
                return GraphPathResult{true, "", true, path};
            }
            queue.push_back(edge.neighbor_object_id);
        }
    }
    return GraphPathResult{true, "", false, {}};
}

ReachabilityResult GraphAlgorithms::reachable(const KnowledgeGraph& graph, const std::string& source_object_id,
                                               const std::string& target_object_id) {
    const GraphPathResult path = shortest_path(graph, source_object_id, target_object_id);
    return ReachabilityResult{path.success, path.error, path.path_exists};
}

NeighborhoodResult GraphAlgorithms::neighborhood(const KnowledgeGraph& graph, const std::string& object_id, int radius) {
    if (!graph.contains(object_id)) {
        return NeighborhoodResult{false, "object '" + object_id + "' is not present in the graph", {}};
    }
    if (radius < 0) {
        return NeighborhoodResult{false, "radius must be non-negative", {}};
    }
    std::set<std::string> visited{object_id};
    std::deque<std::pair<std::string, int>> queue{{object_id, 0}};
    std::set<std::string> result;
    while (!queue.empty()) {
        const auto [current, depth] = queue.front();
        queue.pop_front();
        if (depth >= radius) continue;
        for (const KnowledgeGraphEdgeView& edge : graph.edges_of(current)) {
            if (visited.insert(edge.neighbor_object_id).second) {
                result.insert(edge.neighbor_object_id);
                queue.emplace_back(edge.neighbor_object_id, depth + 1);
            }
        }
    }
    return NeighborhoodResult{true, "", std::vector<std::string>(result.begin(), result.end())};
}

GraphSubgraphResult GraphAlgorithms::subgraph(const KnowledgeGraph& graph, const std::vector<std::string>& object_ids) {
    std::set<std::string> requested(object_ids.begin(), object_ids.end());
    std::set<std::string> present;
    for (const std::string& id : requested) {
        if (graph.contains(id)) present.insert(id);
    }
    std::vector<std::string> relationship_ids;
    for (const KnowledgeGraphEdge& edge : graph.all_edges()) {
        if (present.count(edge.source_object_id) != 0 && present.count(edge.target_object_id) != 0) {
            relationship_ids.push_back(edge.relationship_id);
        }
    }
    std::sort(relationship_ids.begin(), relationship_ids.end());
    return GraphSubgraphResult{true, "", std::vector<std::string>(present.begin(), present.end()), relationship_ids};
}

RelationshipExpansionResult GraphAlgorithms::expand_relationships(const KnowledgeGraph& graph, const std::string& object_id,
                                                                    oep::repository::RelationshipType type) {
    if (!graph.contains(object_id)) {
        return RelationshipExpansionResult{false, "object '" + object_id + "' is not present in the graph", {}};
    }
    std::set<std::string> ids;
    for (const KnowledgeGraphEdgeView& edge : graph.edges_of(object_id)) {
        if (edge.relationship_type == type) ids.insert(edge.relationship_id);
    }
    return RelationshipExpansionResult{true, "", std::vector<std::string>(ids.begin(), ids.end())};
}

} // namespace oep::engine
