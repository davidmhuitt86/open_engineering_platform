#include "oep/engine/knowledge_graph.hpp"

#include <algorithm>

namespace oep::engine {

void KnowledgeGraph::index_node(const KnowledgeGraphNode& node) {
    by_type_[node.object_type].insert(node.object_id);
    for (const std::string& domain : node.domains) {
        by_domain_[domain].insert(node.object_id);
    }
    if (!node.publisher_id.empty()) {
        by_publisher_[node.publisher_id].insert(node.object_id);
    }
    if (!node.package_id.empty()) {
        by_package_[node.package_id].insert(node.object_id);
    }
}

void KnowledgeGraph::deindex_node(const KnowledgeGraphNode& node) {
    auto erase_from = [&node](std::map<std::string, std::set<std::string>>& index, const std::string& key) {
        auto found = index.find(key);
        if (found != index.end()) {
            found->second.erase(node.object_id);
            if (found->second.empty()) index.erase(found);
        }
    };
    auto type_found = by_type_.find(node.object_type);
    if (type_found != by_type_.end()) {
        type_found->second.erase(node.object_id);
        if (type_found->second.empty()) by_type_.erase(type_found);
    }
    for (const std::string& domain : node.domains) {
        erase_from(by_domain_, domain);
    }
    if (!node.publisher_id.empty()) erase_from(by_publisher_, node.publisher_id);
    if (!node.package_id.empty()) erase_from(by_package_, node.package_id);
}

void KnowledgeGraph::index_edge(const KnowledgeGraphEdge& edge) {
    if (nodes_.find(edge.source_object_id) == nodes_.end() || nodes_.find(edge.target_object_id) == nodes_.end()) {
        return; // dangling -- recorded in edges_, but not adjacency/relationship-type index
    }
    adjacency_[edge.source_object_id].push_back(
        KnowledgeGraphEdgeView{edge.relationship_id, edge.target_object_id, edge.relationship_type, true});
    adjacency_[edge.target_object_id].push_back(
        KnowledgeGraphEdgeView{edge.relationship_id, edge.source_object_id, edge.relationship_type, false});
    by_relationship_type_[edge.relationship_type].insert(edge.source_object_id);
    by_relationship_type_[edge.relationship_type].insert(edge.target_object_id);
}

void KnowledgeGraph::build(std::vector<KnowledgeGraphNode> nodes, std::vector<KnowledgeGraphEdge> edges) {
    clear();
    for (KnowledgeGraphNode& node : nodes) {
        const std::string id = node.object_id;
        nodes_.emplace(id, std::move(node));
    }
    for (const auto& [id, node] : nodes_) {
        index_node(node);
    }
    edges_ = std::move(edges);
    for (const KnowledgeGraphEdge& edge : edges_) {
        index_edge(edge);
    }
    for (auto& [id, views] : adjacency_) {
        std::sort(views.begin(), views.end(), [](const KnowledgeGraphEdgeView& a, const KnowledgeGraphEdgeView& b) {
            if (a.neighbor_object_id != b.neighbor_object_id) return a.neighbor_object_id < b.neighbor_object_id;
            return a.relationship_id < b.relationship_id;
        });
    }
}

void KnowledgeGraph::clear() {
    nodes_.clear();
    edges_.clear();
    adjacency_.clear();
    by_type_.clear();
    by_domain_.clear();
    by_relationship_type_.clear();
    by_publisher_.clear();
    by_package_.clear();
}

void KnowledgeGraph::add_object(KnowledgeGraphNode node) {
    const std::string id = node.object_id;
    const auto existing = nodes_.find(id);
    if (existing != nodes_.end()) {
        deindex_node(existing->second);
        existing->second = std::move(node);
        index_node(existing->second);
        return;
    }
    nodes_.emplace(id, node);
    index_node(nodes_.at(id));
    // A previously-dangling edge referencing this object may now be
    // connectable -- rebuild adjacency/relationship-type indexes so
    // incremental add stays fully synchronized (WP-EKE-002 requirement).
    reindex();
}

bool KnowledgeGraph::remove_object(const std::string& object_id) {
    const auto found = nodes_.find(object_id);
    if (found == nodes_.end()) return false;
    deindex_node(found->second);
    nodes_.erase(found);
    edges_.erase(std::remove_if(edges_.begin(), edges_.end(),
                                 [&](const KnowledgeGraphEdge& edge) {
                                     return edge.source_object_id == object_id || edge.target_object_id == object_id;
                                 }),
                 edges_.end());
    reindex();
    return true;
}

void KnowledgeGraph::add_relationship(KnowledgeGraphEdge edge) {
    remove_relationship(edge.relationship_id); // replace-in-place semantics
    edges_.push_back(edge);
    index_edge(edge);
    auto sort_adjacency_for = [this](const std::string& id) {
        auto found = adjacency_.find(id);
        if (found == adjacency_.end()) return;
        std::sort(found->second.begin(), found->second.end(),
                  [](const KnowledgeGraphEdgeView& a, const KnowledgeGraphEdgeView& b) {
                      if (a.neighbor_object_id != b.neighbor_object_id) return a.neighbor_object_id < b.neighbor_object_id;
                      return a.relationship_id < b.relationship_id;
                  });
    };
    sort_adjacency_for(edge.source_object_id);
    sort_adjacency_for(edge.target_object_id);
}

bool KnowledgeGraph::remove_relationship(const std::string& relationship_id) {
    const std::size_t before = edges_.size();
    edges_.erase(std::remove_if(edges_.begin(), edges_.end(),
                                 [&](const KnowledgeGraphEdge& edge) { return edge.relationship_id == relationship_id; }),
                 edges_.end());
    if (edges_.size() == before) return false;
    reindex();
    return true;
}

void KnowledgeGraph::reindex() {
    adjacency_.clear();
    by_type_.clear();
    by_domain_.clear();
    by_relationship_type_.clear();
    by_publisher_.clear();
    by_package_.clear();
    for (const auto& [id, node] : nodes_) {
        index_node(node);
    }
    for (const KnowledgeGraphEdge& edge : edges_) {
        index_edge(edge);
    }
    for (auto& [id, views] : adjacency_) {
        std::sort(views.begin(), views.end(), [](const KnowledgeGraphEdgeView& a, const KnowledgeGraphEdgeView& b) {
            if (a.neighbor_object_id != b.neighbor_object_id) return a.neighbor_object_id < b.neighbor_object_id;
            return a.relationship_id < b.relationship_id;
        });
    }
}

bool KnowledgeGraph::contains(const std::string& object_id) const {
    return nodes_.find(object_id) != nodes_.end();
}

const KnowledgeGraphNode* KnowledgeGraph::find_node(const std::string& object_id) const {
    const auto found = nodes_.find(object_id);
    return found == nodes_.end() ? nullptr : &found->second;
}

std::vector<const KnowledgeGraphNode*> KnowledgeGraph::all_nodes() const {
    std::vector<const KnowledgeGraphNode*> result;
    result.reserve(nodes_.size());
    for (const auto& [id, node] : nodes_) {
        result.push_back(&node);
    }
    return result;
}

std::vector<KnowledgeGraphEdgeView> KnowledgeGraph::edges_of(const std::string& object_id) const {
    const auto found = adjacency_.find(object_id);
    return found == adjacency_.end() ? std::vector<KnowledgeGraphEdgeView>{} : found->second;
}

namespace {
std::vector<std::string> to_sorted_vector(const std::set<std::string>& ids) {
    return std::vector<std::string>(ids.begin(), ids.end());
}
} // namespace

std::vector<std::string> KnowledgeGraph::ids_by_object_type(oep::repository::ObjectType type) const {
    const auto found = by_type_.find(type);
    return found == by_type_.end() ? std::vector<std::string>{} : to_sorted_vector(found->second);
}

std::vector<std::string> KnowledgeGraph::ids_by_domain(const std::string& domain) const {
    const auto found = by_domain_.find(domain);
    return found == by_domain_.end() ? std::vector<std::string>{} : to_sorted_vector(found->second);
}

std::vector<std::string> KnowledgeGraph::ids_by_relationship_type(oep::repository::RelationshipType type) const {
    const auto found = by_relationship_type_.find(type);
    return found == by_relationship_type_.end() ? std::vector<std::string>{} : to_sorted_vector(found->second);
}

std::vector<std::string> KnowledgeGraph::ids_by_publisher(const std::string& publisher_id) const {
    const auto found = by_publisher_.find(publisher_id);
    return found == by_publisher_.end() ? std::vector<std::string>{} : to_sorted_vector(found->second);
}

std::vector<std::string> KnowledgeGraph::ids_by_package(const std::string& package_id) const {
    const auto found = by_package_.find(package_id);
    return found == by_package_.end() ? std::vector<std::string>{} : to_sorted_vector(found->second);
}

std::vector<std::string> KnowledgeGraph::outgoing_neighbors(const std::string& object_id) const {
    std::set<std::string> ids;
    for (const KnowledgeGraphEdgeView& view : edges_of(object_id)) {
        if (view.outgoing) ids.insert(view.neighbor_object_id);
    }
    return to_sorted_vector(ids);
}

std::vector<std::string> KnowledgeGraph::incoming_neighbors(const std::string& object_id) const {
    std::set<std::string> ids;
    for (const KnowledgeGraphEdgeView& view : edges_of(object_id)) {
        if (!view.outgoing) ids.insert(view.neighbor_object_id);
    }
    return to_sorted_vector(ids);
}

} // namespace oep::engine
