#include "oep/engine/query_engine.hpp"

#include <algorithm>
#include <deque>
#include <map>
#include <set>

namespace oep::engine {

QueryResult QueryEngine::find_by_id(const RuntimeGraph& graph, const std::string& object_id) {
    if (!graph.contains(object_id)) {
        return QueryResult{true, "", {}};
    }
    return QueryResult{true, "", {object_id}};
}

QueryResult QueryEngine::find_by_type(const RuntimeGraph& graph, oep::repository::ObjectType type) {
    return QueryResult{true, "", graph.object_ids_by_type(type)};
}

QueryResult QueryEngine::find_by_domain(const RuntimeGraph& graph, const std::string& domain) {
    return QueryResult{true, "", graph.object_ids_by_tag(domain)};
}

QueryResult QueryEngine::find_by_relationship(const RuntimeGraph& graph, oep::repository::RelationshipType type) {
    std::set<std::string> ids;
    for (const oep::repository::Relationship& relationship : graph.all_relationships()) {
        if (relationship.relationship_type == type) {
            ids.insert(relationship.source_object_id);
            ids.insert(relationship.target_object_id);
        }
    }
    return QueryResult{true, "", std::vector<std::string>(ids.begin(), ids.end())};
}

PathResult QueryEngine::shortest_path(const RuntimeGraph& graph, const std::string& source_object_id,
                                       const std::string& target_object_id) {
    if (!graph.contains(source_object_id) || !graph.contains(target_object_id)) {
        return PathResult{false, "source and/or target object is not present in the loaded graph", false, {}};
    }
    if (source_object_id == target_object_id) {
        return PathResult{true, "", true, {source_object_id}};
    }

    std::map<std::string, std::string> came_from;
    std::set<std::string> visited{source_object_id};
    std::deque<std::string> queue{source_object_id};

    while (!queue.empty()) {
        const std::string current = queue.front();
        queue.pop_front();
        for (const GraphEdge& edge : graph.edges_of(current)) {
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
                return PathResult{true, "", true, path};
            }
            queue.push_back(edge.neighbor_object_id);
        }
    }
    return PathResult{true, "", false, {}};
}

QueryResult QueryEngine::connected_component(const RuntimeGraph& graph, const std::string& start_object_id) {
    if (!graph.contains(start_object_id)) {
        return QueryResult{false, "object '" + start_object_id + "' is not present in the loaded graph", {}};
    }
    std::set<std::string> visited{start_object_id};
    std::deque<std::string> queue{start_object_id};
    while (!queue.empty()) {
        const std::string current = queue.front();
        queue.pop_front();
        for (const GraphEdge& edge : graph.edges_of(current)) {
            if (visited.insert(edge.neighbor_object_id).second) {
                queue.push_back(edge.neighbor_object_id);
            }
        }
    }
    return QueryResult{true, "", std::vector<std::string>(visited.begin(), visited.end())};
}

SubgraphResult QueryEngine::subgraph(const RuntimeGraph& graph, const std::vector<std::string>& object_ids) {
    std::set<std::string> requested(object_ids.begin(), object_ids.end());
    std::set<std::string> present;
    for (const std::string& id : requested) {
        if (graph.contains(id)) present.insert(id);
    }
    std::vector<std::string> relationship_ids;
    for (const oep::repository::Relationship& relationship : graph.all_relationships()) {
        if (present.count(relationship.source_object_id) != 0 && present.count(relationship.target_object_id) != 0) {
            relationship_ids.push_back(relationship.relationship_id);
        }
    }
    std::sort(relationship_ids.begin(), relationship_ids.end());
    return SubgraphResult{true, "", std::vector<std::string>(present.begin(), present.end()), relationship_ids};
}

} // namespace oep::engine
