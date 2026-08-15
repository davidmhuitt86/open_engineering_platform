#include "oep/engine/runtime_graph.hpp"

#include <algorithm>

namespace oep::engine {

void RuntimeGraph::build(std::vector<oep::repository::EngineeringObject> objects,
                          std::vector<oep::repository::Relationship> relationships) {
    clear();

    for (oep::repository::EngineeringObject& object : objects) {
        const std::string object_id = object.object_id;
        by_type_[object.object_type].push_back(object_id);
        for (const std::string& tag : object.tags) {
            by_tag_[tag].push_back(object_id);
        }
        objects_.emplace(object_id, std::move(object));
    }
    for (auto& [type, ids] : by_type_) {
        std::sort(ids.begin(), ids.end());
    }
    for (auto& [tag, ids] : by_tag_) {
        std::sort(ids.begin(), ids.end());
    }

    for (const oep::repository::Relationship& relationship : relationships) {
        if (objects_.find(relationship.source_object_id) == objects_.end() ||
            objects_.find(relationship.target_object_id) == objects_.end()) {
            continue; // dangling reference -- excluded, per this class's documented contract
        }
        relationships_.push_back(relationship);
        adjacency_[relationship.source_object_id].push_back(
            GraphEdge{relationship.relationship_id, relationship.target_object_id, relationship.relationship_type, true});
        adjacency_[relationship.target_object_id].push_back(
            GraphEdge{relationship.relationship_id, relationship.source_object_id, relationship.relationship_type, false});
    }
    for (auto& [id, edges] : adjacency_) {
        std::sort(edges.begin(), edges.end(), [](const GraphEdge& a, const GraphEdge& b) {
            if (a.neighbor_object_id != b.neighbor_object_id) return a.neighbor_object_id < b.neighbor_object_id;
            return a.relationship_id < b.relationship_id;
        });
    }
}

void RuntimeGraph::clear() {
    objects_.clear();
    relationships_.clear();
    adjacency_.clear();
    by_type_.clear();
    by_tag_.clear();
}

bool RuntimeGraph::contains(const std::string& object_id) const {
    return objects_.find(object_id) != objects_.end();
}

const oep::repository::EngineeringObject* RuntimeGraph::find_object(const std::string& object_id) const {
    const auto found = objects_.find(object_id);
    return found == objects_.end() ? nullptr : &found->second;
}

std::vector<const oep::repository::EngineeringObject*> RuntimeGraph::all_objects() const {
    std::vector<const oep::repository::EngineeringObject*> result;
    result.reserve(objects_.size());
    for (const auto& [id, object] : objects_) {
        result.push_back(&object);
    }
    return result;
}

std::vector<GraphEdge> RuntimeGraph::edges_of(const std::string& object_id) const {
    const auto found = adjacency_.find(object_id);
    return found == adjacency_.end() ? std::vector<GraphEdge>{} : found->second;
}

std::vector<std::string> RuntimeGraph::object_ids_by_type(oep::repository::ObjectType type) const {
    const auto found = by_type_.find(type);
    return found == by_type_.end() ? std::vector<std::string>{} : found->second;
}

std::vector<std::string> RuntimeGraph::object_ids_by_tag(const std::string& tag) const {
    const auto found = by_tag_.find(tag);
    return found == by_tag_.end() ? std::vector<std::string>{} : found->second;
}

} // namespace oep::engine
