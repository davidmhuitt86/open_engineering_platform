#include "oep/engine/query_planner.hpp"

namespace oep::engine {

QueryPlan QueryPlanner::plan(const QueryRequest& request, const KnowledgeGraphEngine& engine) {
    const KnowledgeGraph& graph = engine.graph();
    const QueryFilter& filter = request.filter();

    TraversalStrategy strategy = TraversalStrategy::None;
    std::vector<std::string> indexes_used;
    double estimated_cost = 1.0;
    std::vector<std::string> execution_order;

    switch (request.category()) {
        case QueryCategory::Object: {
            indexes_used = {"object_id"};
            estimated_cost = 1.0;
            if (graph.contains(request.primary_object_id())) {
                execution_order = {request.primary_object_id()};
            }
            break;
        }
        case QueryCategory::Relationship: {
            indexes_used = {"relationship_type"};
            if (filter.relationship_type.has_value()) {
                execution_order = graph.ids_by_relationship_type(*filter.relationship_type);
            }
            estimated_cost = static_cast<double>(execution_order.size());
            break;
        }
        case QueryCategory::Domain: {
            indexes_used = {"domain"};
            execution_order = graph.ids_by_domain(filter.domain.value_or(""));
            estimated_cost = static_cast<double>(execution_order.size());
            break;
        }
        case QueryCategory::Type: {
            indexes_used = {"object_type"};
            if (filter.object_type.has_value()) {
                execution_order = graph.ids_by_object_type(*filter.object_type);
            }
            estimated_cost = static_cast<double>(execution_order.size());
            break;
        }
        case QueryCategory::Dependency: {
            strategy = TraversalStrategy::BreadthFirst;
            indexes_used = {"adjacency:DependsOn"};
            if (graph.contains(request.primary_object_id())) {
                execution_order = {request.primary_object_id()}; // seed only -- planning never traverses
            }
            estimated_cost = static_cast<double>(graph.edge_count()); // worst case, unknown without traversing
            break;
        }
        case QueryCategory::Neighborhood: {
            strategy = TraversalStrategy::BreadthFirst;
            indexes_used = {"adjacency"};
            if (graph.contains(request.primary_object_id())) {
                execution_order = {request.primary_object_id()};
            }
            const int radius = filter.max_depth.value_or(1);
            estimated_cost = static_cast<double>(radius) * static_cast<double>(graph.edge_count() + 1);
            break;
        }
        case QueryCategory::Path: {
            strategy = TraversalStrategy::BreadthFirst;
            indexes_used = {"adjacency"};
            if (graph.contains(request.primary_object_id()) && graph.contains(request.secondary_object_id())) {
                execution_order = {request.primary_object_id(), request.secondary_object_id()};
            }
            estimated_cost = static_cast<double>(graph.node_count() + graph.edge_count());
            break;
        }
        case QueryCategory::Reference: {
            strategy = TraversalStrategy::None;
            indexes_used = {"adjacency:References"};
            if (graph.contains(request.primary_object_id())) {
                execution_order = {request.primary_object_id()};
            }
            estimated_cost = static_cast<double>(graph.edges_of(request.primary_object_id()).size());
            break;
        }
        case QueryCategory::Metadata: {
            strategy = TraversalStrategy::None;
            indexes_used = {"publisher", "package", "tags"};
            estimated_cost = static_cast<double>(graph.node_count()); // full scan -- see query_executor.cpp
            for (const auto* node : graph.all_nodes()) {
                execution_order.push_back(node->object_id);
            }
            break;
        }
        case QueryCategory::Composite: {
            strategy = TraversalStrategy::None;
            indexes_used = {"object_type", "domain", "publisher", "package", "tags"};
            estimated_cost = static_cast<double>(graph.node_count());
            for (const auto* node : graph.all_nodes()) {
                execution_order.push_back(node->object_id);
            }
            break;
        }
    }

    return QueryPlan(request, strategy, indexes_used, estimated_cost, execution_order);
}

} // namespace oep::engine
