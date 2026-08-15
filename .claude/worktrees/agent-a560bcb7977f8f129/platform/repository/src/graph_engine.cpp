#include "oep/repository/graph_engine.hpp"

#include <algorithm>
#include <deque>
#include <set>

namespace oep::repository {

namespace {

bool neighbor_less(const GraphNeighbor& a, const GraphNeighbor& b) {
    if (a.object_id != b.object_id) return a.object_id < b.object_id;
    return a.relationship_id < b.relationship_id;
}

} // namespace

void GraphEngine::build_graph(const ObjectStore& objects, const RelationshipStore& relationships) {
    adjacency_.clear();

    const ListObjectsResult object_result = objects.list_all();
    if (!object_result.success) {
        return;
    }
    for (const EngineeringObject& object : object_result.objects) {
        adjacency_[object.object_id]; // ensure every valid object is a node, even if isolated
    }

    const ListRelationshipsResult relationship_result = relationships.list_all();
    if (!relationship_result.success) {
        return;
    }
    for (const Relationship& relationship : relationship_result.relationships) {
        if (!has_node(relationship.source_object_id) || !has_node(relationship.target_object_id)) {
            continue; // invalid graph elements do not participate in traversal
        }

        adjacency_[relationship.source_object_id].push_back(
            {relationship.target_object_id, relationship.relationship_id, relationship.relationship_type});
        adjacency_[relationship.target_object_id].push_back(
            {relationship.source_object_id, relationship.relationship_id, relationship.relationship_type});
    }

    for (auto& [object_id, neighbors] : adjacency_) {
        std::sort(neighbors.begin(), neighbors.end(), neighbor_less);
    }
}

void GraphEngine::clear_graph() {
    adjacency_.clear();
}

bool GraphEngine::has_node(const std::string& object_id) const {
    return adjacency_.find(object_id) != adjacency_.end();
}

NeighborsResult GraphEngine::get_neighbors(const std::string& object_id) const {
    const auto it = adjacency_.find(object_id);
    if (it == adjacency_.end()) {
        return {false, "no object with id '" + object_id + "' in the graph", {}};
    }
    return {true, "", it->second};
}

TraversalResult GraphEngine::traverse_breadth_first(const std::string& start_object_id) const {
    if (!has_node(start_object_id)) {
        return {false, "no object with id '" + start_object_id + "' in the graph", {}};
    }

    std::vector<std::string> order;
    std::set<std::string> visited;
    std::deque<std::string> queue;

    queue.push_back(start_object_id);
    visited.insert(start_object_id);

    while (!queue.empty()) {
        const std::string current = queue.front();
        queue.pop_front();
        order.push_back(current);

        for (const GraphNeighbor& neighbor : adjacency_.at(current)) {
            if (visited.insert(neighbor.object_id).second) {
                queue.push_back(neighbor.object_id);
            }
        }
    }

    return {true, "", order};
}

TraversalResult GraphEngine::traverse_depth_first(const std::string& start_object_id) const {
    if (!has_node(start_object_id)) {
        return {false, "no object with id '" + start_object_id + "' in the graph", {}};
    }

    std::vector<std::string> order;
    std::set<std::string> visited;
    std::vector<std::string> stack;

    stack.push_back(start_object_id);

    while (!stack.empty()) {
        const std::string current = stack.back();
        stack.pop_back();

        if (!visited.insert(current).second) {
            continue;
        }
        order.push_back(current);

        // Push in reverse sorted order so the smallest-id neighbor is
        // processed first (stack is last-in-first-out).
        const std::vector<GraphNeighbor>& neighbors = adjacency_.at(current);
        for (auto it = neighbors.rbegin(); it != neighbors.rend(); ++it) {
            if (visited.find(it->object_id) == visited.end()) {
                stack.push_back(it->object_id);
            }
        }
    }

    return {true, "", order};
}

PathExistsResult GraphEngine::path_exists(const std::string& source_object_id,
                                           const std::string& target_object_id) const {
    if (!has_node(source_object_id)) {
        return {false, "no object with id '" + source_object_id + "' in the graph", false};
    }
    if (!has_node(target_object_id)) {
        return {false, "no object with id '" + target_object_id + "' in the graph", false};
    }

    if (source_object_id == target_object_id) {
        return {true, "", true};
    }

    const TraversalResult reachable = traverse_breadth_first(source_object_id);
    const bool found =
        std::find(reachable.object_ids.begin(), reachable.object_ids.end(), target_object_id) !=
        reachable.object_ids.end();

    return {true, "", found};
}

} // namespace oep::repository
