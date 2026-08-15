#include "oep/engine/engineering_context.hpp"

#include <algorithm>
#include <deque>
#include <set>

namespace oep::engine {

EngineeringContext::LoadGraphResult EngineeringContext::load_graph() {
    const ObjectLoader::LoadAllResult loaded = loader_.load_all();
    if (!loaded.success) {
        graph_loaded_ = false;
        return LoadGraphResult{false, loaded.error, 0, 0};
    }
    graph_.build(loaded.objects, loaded.relationships);
    graph_loaded_ = true;
    return LoadGraphResult{true, "", loaded.objects.size(), loaded.relationships.size()};
}

namespace {
QueryResult graph_not_loaded_query() {
    return QueryResult{false, "the Runtime Graph has not been loaded -- call load_graph() first", {}};
}
} // namespace

QueryResult EngineeringContext::query(const QueryRequest& request) const {
    if (!graph_loaded_) return graph_not_loaded_query();
    switch (request.kind) {
        case QueryKind::ById:
            return QueryEngine::find_by_id(graph_, request.object_id);
        case QueryKind::ByType:
            return QueryEngine::find_by_type(graph_, request.object_type);
        case QueryKind::ByDomain:
            return QueryEngine::find_by_domain(graph_, request.domain);
        case QueryKind::ByRelationship:
            return QueryEngine::find_by_relationship(graph_, request.relationship_type);
        case QueryKind::ConnectedComponent:
            return QueryEngine::connected_component(graph_, request.object_id);
        case QueryKind::ShortestPath: {
            const PathResult path = QueryEngine::shortest_path(graph_, request.source_object_id, request.target_object_id);
            return QueryResult{path.success, path.error, path.path};
        }
        case QueryKind::Subgraph: {
            const SubgraphResult sub = QueryEngine::subgraph(graph_, request.object_ids);
            return QueryResult{sub.success, sub.error, sub.object_ids};
        }
    }
    return QueryResult{false, "unrecognized query kind", {}};
}

PathResult EngineeringContext::shortest_path(const std::string& source_object_id,
                                              const std::string& target_object_id) const {
    if (!graph_loaded_) return PathResult{false, "the Runtime Graph has not been loaded -- call load_graph() first", false, {}};
    return QueryEngine::shortest_path(graph_, source_object_id, target_object_id);
}

SubgraphResult EngineeringContext::subgraph(const std::vector<std::string>& object_ids) const {
    if (!graph_loaded_) {
        return SubgraphResult{false, "the Runtime Graph has not been loaded -- call load_graph() first", {}, {}};
    }
    return QueryEngine::subgraph(graph_, object_ids);
}

TraversalResult EngineeringContext::traverse(const std::string& start_object_id, const TraversalOptions& options) const {
    if (!graph_loaded_) {
        return TraversalResult{false, "the Runtime Graph has not been loaded -- call load_graph() first", {}};
    }
    return oep::engine::traverse(graph_, start_object_id, options);
}

RelatedObjectsResult EngineeringContext::related_objects(const std::string& object_id) const {
    if (!graph_loaded_) {
        return RelatedObjectsResult{false, "the Runtime Graph has not been loaded -- call load_graph() first", {}};
    }
    return RelationshipEngine::neighbors(graph_, object_id);
}

EngineeringContext::DependencyGraphResult EngineeringContext::dependency_graph(const std::string& object_id) const {
    if (!graph_loaded_) {
        return DependencyGraphResult{false, "the Runtime Graph has not been loaded -- call load_graph() first", {}, {}};
    }
    if (!graph_.contains(object_id)) {
        return DependencyGraphResult{false, "object '" + object_id + "' is not present in the loaded graph", {}, {}};
    }

    std::set<std::string> visited{object_id};
    std::deque<std::string> queue{object_id};
    std::vector<std::string> relationship_ids;

    while (!queue.empty()) {
        const std::string current = queue.front();
        queue.pop_front();
        for (const GraphEdge& edge : graph_.edges_of(current)) {
            if (edge.relationship_type != oep::repository::RelationshipType::DependsOn || !edge.outgoing) continue;
            relationship_ids.push_back(edge.relationship_id);
            if (visited.insert(edge.neighbor_object_id).second) {
                queue.push_back(edge.neighbor_object_id);
            }
        }
    }
    std::sort(relationship_ids.begin(), relationship_ids.end());
    return DependencyGraphResult{true, "", std::vector<std::string>(visited.begin(), visited.end()), relationship_ids};
}

EngineeringContext::OwnerInfo EngineeringContext::find_owner(const std::string& object_id) const {
    const oep::runtime::RuntimeService::FindPackageOwnerResponse response =
        service_.find_package_owner(oep::runtime::RuntimeService::FindPackageOwnerRequest(object_id));
    if (!response.success || response.kind == oep::installer::OwnedEntityKind::None) {
        return OwnerInfo{};
    }
    OwnerInfo info;
    info.has_owner = true;
    info.package_id = response.owner.package_id;
    info.publisher_id = response.owner.publisher_id;
    info.publisher_name = response.owner.publisher_name;
    return info;
}

} // namespace oep::engine
