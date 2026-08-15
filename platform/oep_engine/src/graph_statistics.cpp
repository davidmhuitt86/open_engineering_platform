#include "oep/engine/graph_statistics.hpp"

#include "oep/engine/graph_algorithms.hpp"

#include <algorithm>
#include <deque>
#include <map>
#include <set>

namespace oep::engine {

namespace {

int eccentricity_from(const KnowledgeGraph& graph, const std::string& start) {
    std::map<std::string, int> depth{{start, 0}};
    std::deque<std::string> queue{start};
    int max_depth = 0;
    while (!queue.empty()) {
        const std::string current = queue.front();
        queue.pop_front();
        for (const KnowledgeGraphEdgeView& edge : graph.edges_of(current)) {
            if (depth.find(edge.neighbor_object_id) == depth.end()) {
                depth[edge.neighbor_object_id] = depth[current] + 1;
                max_depth = std::max(max_depth, depth[edge.neighbor_object_id]);
                queue.push_back(edge.neighbor_object_id);
            }
        }
    }
    return max_depth;
}

} // namespace

GraphStatistics compute_statistics(const KnowledgeGraph& graph) {
    GraphStatistics stats;
    stats.object_count = graph.node_count();
    stats.relationship_count = graph.edge_count();

    const ComponentsResult components = GraphAlgorithms::connected_components(graph);
    stats.connected_component_count = components.components.size();

    const double n = static_cast<double>(stats.object_count);
    const double e = static_cast<double>(stats.relationship_count);
    stats.density = n > 1.0 ? (2.0 * e) / (n * (n - 1.0)) : 0.0;
    stats.average_degree = n > 0.0 ? (2.0 * e) / n : 0.0;

    // all_nodes() rebuilds and returns a new vector on every call (O(V)); the
    // result is invariant for the remainder of this function, so it is
    // computed once and reused below instead of being requested twice more.
    const std::vector<const KnowledgeGraphNode*> nodes = graph.all_nodes();

    int max_depth = 0;
    for (const KnowledgeGraphNode* node : nodes) {
        max_depth = std::max(max_depth, eccentricity_from(graph, node->object_id));
    }
    stats.maximum_depth = max_depth;

    std::map<oep::repository::RelationshipType, std::size_t> type_counts;
    for (const KnowledgeGraphEdge& edge : graph.all_edges()) {
        ++type_counts[edge.relationship_type];
    }
    for (const auto& [type, count] : type_counts) {
        stats.relationship_distribution.push_back({type, count});
    }

    std::map<std::string, std::size_t> domain_counts;
    for (const KnowledgeGraphNode* node : nodes) {
        for (const std::string& domain : node->domains) {
            ++domain_counts[domain];
        }
    }
    for (const auto& [domain, count] : domain_counts) {
        stats.domain_distribution.push_back({domain, count});
    }

    return stats;
}

} // namespace oep::engine
