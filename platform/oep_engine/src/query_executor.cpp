#include "oep/engine/query_executor.hpp"

#include "oep/engine/graph_algorithms.hpp"

#include <algorithm>
#include <chrono>
#include <deque>
#include <set>

namespace oep::engine {

namespace {

bool node_matches_filter(const KnowledgeGraphNode& node, const QueryFilter& filter) {
    if (filter.object_type.has_value() && node.object_type != *filter.object_type) return false;
    if (filter.domain.has_value() &&
        std::find(node.domains.begin(), node.domains.end(), *filter.domain) == node.domains.end()) {
        return false;
    }
    if (filter.publisher_id.has_value() && node.publisher_id != *filter.publisher_id) return false;
    if (filter.package_id.has_value() && node.package_id != *filter.package_id) return false;
    for (const std::string& tag : filter.tags) {
        if (std::find(node.domains.begin(), node.domains.end(), tag) == node.domains.end()) return false;
    }
    return true;
}

struct ExecutionOutcome {
    std::vector<std::string> object_ids;
    std::vector<std::string> relationship_ids;
    std::size_t objects_examined = 0;
    std::size_t relationships_examined = 0;
    int traversal_depth = 0;
    std::string traversal_summary;
};

ExecutionOutcome execute_object(const QueryPlan& plan, const KnowledgeGraph& graph) {
    ExecutionOutcome outcome;
    outcome.objects_examined = 1;
    if (graph.contains(plan.request().primary_object_id())) {
        outcome.object_ids = {plan.request().primary_object_id()};
    }
    outcome.traversal_summary = "direct object_id lookup";
    return outcome;
}

ExecutionOutcome execute_index_lookup(const QueryPlan& plan, const char* summary) {
    ExecutionOutcome outcome;
    outcome.object_ids = plan.execution_order();
    outcome.objects_examined = outcome.object_ids.size();
    outcome.traversal_summary = summary;
    return outcome;
}

ExecutionOutcome execute_dependency(const QueryPlan& plan, const KnowledgeGraph& graph) {
    ExecutionOutcome outcome;
    const std::string& start = plan.request().primary_object_id();
    if (!graph.contains(start)) {
        outcome.traversal_summary = "start object not present in graph";
        return outcome;
    }
    const bool incoming = plan.filter().outgoing_only.has_value() && !*plan.filter().outgoing_only;

    std::set<std::string> visited{start};
    std::deque<std::pair<std::string, int>> queue{{start, 0}};
    int max_depth_seen = 0;
    while (!queue.empty()) {
        const auto [current, depth] = queue.front();
        queue.pop_front();
        max_depth_seen = std::max(max_depth_seen, depth);
        ++outcome.objects_examined;
        for (const KnowledgeGraphEdgeView& edge : graph.edges_of(current)) {
            ++outcome.relationships_examined;
            if (edge.relationship_type != oep::repository::RelationshipType::DependsOn) continue;
            if (edge.outgoing == incoming) continue; // want outgoing edges unless incoming was requested
            outcome.relationship_ids.push_back(edge.relationship_id);
            if (visited.insert(edge.neighbor_object_id).second) {
                queue.emplace_back(edge.neighbor_object_id, depth + 1);
            }
        }
    }
    outcome.object_ids.assign(visited.begin(), visited.end());
    std::sort(outcome.relationship_ids.begin(), outcome.relationship_ids.end());
    outcome.relationship_ids.erase(std::unique(outcome.relationship_ids.begin(), outcome.relationship_ids.end()),
                                    outcome.relationship_ids.end());
    outcome.traversal_depth = max_depth_seen;
    outcome.traversal_summary = incoming ? "transitive incoming DependsOn closure" : "transitive outgoing DependsOn closure";
    return outcome;
}

ExecutionOutcome execute_neighborhood(const QueryPlan& plan, const KnowledgeGraph& graph) {
    ExecutionOutcome outcome;
    const int radius = plan.filter().max_depth.value_or(1);
    const NeighborhoodResult result = GraphAlgorithms::neighborhood(graph, plan.request().primary_object_id(), radius);
    outcome.object_ids = result.object_ids;
    outcome.objects_examined = result.object_ids.size();
    outcome.traversal_depth = radius;
    outcome.traversal_summary = result.success ? "breadth-first neighborhood, radius " + std::to_string(radius)
                                                : result.error;
    return outcome;
}

ExecutionOutcome execute_path(const QueryPlan& plan, const KnowledgeGraph& graph) {
    ExecutionOutcome outcome;
    const GraphPathResult result =
        GraphAlgorithms::shortest_path(graph, plan.request().primary_object_id(), plan.request().secondary_object_id());
    if (result.success && result.path_exists) {
        outcome.object_ids = result.path;
        outcome.traversal_depth = static_cast<int>(result.path.size()) - 1;
    }
    outcome.objects_examined = graph.node_count(); // BFS explored up to the whole graph in the worst case
    outcome.traversal_summary = result.success ? (result.path_exists ? "shortest path found" : "no path exists")
                                                : result.error;
    return outcome;
}

ExecutionOutcome execute_reference(const QueryPlan& plan, const KnowledgeGraph& graph) {
    ExecutionOutcome outcome;
    const std::string& id = plan.request().primary_object_id();
    if (!graph.contains(id)) {
        outcome.traversal_summary = "object not present in graph";
        return outcome;
    }
    const std::optional<bool>& outgoing_only = plan.filter().outgoing_only;
    std::set<std::string> ids;
    for (const KnowledgeGraphEdgeView& edge : graph.edges_of(id)) {
        ++outcome.relationships_examined;
        if (edge.relationship_type != oep::repository::RelationshipType::References) continue;
        if (outgoing_only.has_value() && edge.outgoing != *outgoing_only) continue;
        ids.insert(edge.neighbor_object_id);
    }
    outcome.object_ids.assign(ids.begin(), ids.end());
    outcome.objects_examined = outcome.object_ids.size();
    outcome.traversal_summary = "direct References edges";
    return outcome;
}

ExecutionOutcome execute_metadata_or_composite(const QueryPlan& plan, const KnowledgeGraph& graph) {
    ExecutionOutcome outcome;
    for (const KnowledgeGraphNode* node : graph.all_nodes()) {
        ++outcome.objects_examined;
        if (node_matches_filter(*node, plan.filter())) {
            outcome.object_ids.push_back(node->object_id);
        }
    }
    outcome.traversal_summary = "full node scan with filter predicate";
    return outcome;
}

} // namespace

EngineeringQueryResult QueryExecutor::execute(const QueryPlan& plan, const KnowledgeGraphEngine& engine) {
    const auto start_time = std::chrono::steady_clock::now();
    const KnowledgeGraph& graph = engine.graph();

    ExecutionOutcome outcome;
    switch (plan.category()) {
        case QueryCategory::Object: outcome = execute_object(plan, graph); break;
        case QueryCategory::Relationship: outcome = execute_index_lookup(plan, "relationship_type index lookup"); break;
        case QueryCategory::Domain: outcome = execute_index_lookup(plan, "domain index lookup"); break;
        case QueryCategory::Type: outcome = execute_index_lookup(plan, "object_type index lookup"); break;
        case QueryCategory::Dependency: outcome = execute_dependency(plan, graph); break;
        case QueryCategory::Neighborhood: outcome = execute_neighborhood(plan, graph); break;
        case QueryCategory::Path: outcome = execute_path(plan, graph); break;
        case QueryCategory::Reference: outcome = execute_reference(plan, graph); break;
        case QueryCategory::Metadata:
        case QueryCategory::Composite: outcome = execute_metadata_or_composite(plan, graph); break;
    }

    const auto end_time = std::chrono::steady_clock::now();
    const double elapsed_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();

    QueryStatistics statistics;
    statistics.execution_time_ms = elapsed_ms;
    statistics.objects_examined = outcome.objects_examined;
    statistics.relationships_examined = outcome.relationships_examined;
    statistics.traversal_depth = outcome.traversal_depth;
    statistics.indexes_used = plan.indexes_used();
    statistics.result_count = outcome.object_ids.size() + outcome.relationship_ids.size();

    return EngineeringQueryResult(std::move(outcome.object_ids), std::move(outcome.relationship_ids), std::move(statistics),
                        outcome.traversal_summary);
}

} // namespace oep::engine
