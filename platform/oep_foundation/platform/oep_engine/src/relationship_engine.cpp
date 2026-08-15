#include "oep/engine/relationship_engine.hpp"

#include <algorithm>
#include <set>

namespace oep::engine {

namespace {

RelatedObjectsResult not_found(const std::string& object_id) {
    return RelatedObjectsResult{false, "object '" + object_id + "' is not present in the loaded graph", {}};
}

RelatedObjectsResult sorted_unique(std::vector<std::string> ids) {
    std::sort(ids.begin(), ids.end());
    ids.erase(std::unique(ids.begin(), ids.end()), ids.end());
    return RelatedObjectsResult{true, "", std::move(ids)};
}

} // namespace

RelatedObjectsResult RelationshipEngine::parents(const RuntimeGraph& graph, const std::string& object_id) {
    if (!graph.contains(object_id)) return not_found(object_id);
    std::vector<std::string> ids;
    for (const GraphEdge& edge : graph.edges_of(object_id)) {
        if (edge.relationship_type == oep::repository::RelationshipType::Contains && !edge.outgoing) {
            ids.push_back(edge.neighbor_object_id);
        }
    }
    return sorted_unique(std::move(ids));
}

RelatedObjectsResult RelationshipEngine::children(const RuntimeGraph& graph, const std::string& object_id) {
    if (!graph.contains(object_id)) return not_found(object_id);
    std::vector<std::string> ids;
    for (const GraphEdge& edge : graph.edges_of(object_id)) {
        if (edge.relationship_type == oep::repository::RelationshipType::Contains && edge.outgoing) {
            ids.push_back(edge.neighbor_object_id);
        }
    }
    return sorted_unique(std::move(ids));
}

RelatedObjectsResult RelationshipEngine::neighbors(const RuntimeGraph& graph, const std::string& object_id) {
    if (!graph.contains(object_id)) return not_found(object_id);
    std::vector<std::string> ids;
    for (const GraphEdge& edge : graph.edges_of(object_id)) {
        ids.push_back(edge.neighbor_object_id);
    }
    return sorted_unique(std::move(ids));
}

RelatedObjectsResult RelationshipEngine::references(const RuntimeGraph& graph, const std::string& object_id) {
    if (!graph.contains(object_id)) return not_found(object_id);
    std::vector<std::string> ids;
    for (const GraphEdge& edge : graph.edges_of(object_id)) {
        if (edge.relationship_type == oep::repository::RelationshipType::References && edge.outgoing) {
            ids.push_back(edge.neighbor_object_id);
        }
    }
    return sorted_unique(std::move(ids));
}

RelatedObjectsResult RelationshipEngine::dependencies(const RuntimeGraph& graph, const std::string& object_id) {
    if (!graph.contains(object_id)) return not_found(object_id);
    std::vector<std::string> ids;
    for (const GraphEdge& edge : graph.edges_of(object_id)) {
        if (edge.relationship_type == oep::repository::RelationshipType::DependsOn && edge.outgoing) {
            ids.push_back(edge.neighbor_object_id);
        }
    }
    return sorted_unique(std::move(ids));
}

} // namespace oep::engine
