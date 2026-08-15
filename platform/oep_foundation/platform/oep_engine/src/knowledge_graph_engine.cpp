#include "oep/engine/knowledge_graph_engine.hpp"

#include "oep/engine/graph_serialization.hpp"

#include <algorithm>

namespace oep::engine {

KnowledgeGraphNode KnowledgeGraphEngine::node_from(const oep::repository::EngineeringObject& object) const {
    KnowledgeGraphNode node;
    node.object_id = object.object_id;
    node.object_type = object.object_type;
    node.name = object.name;
    node.domains = object.tags;
    const EngineeringContext::OwnerInfo owner = context_.find_owner(object.object_id);
    if (owner.has_owner) {
        node.package_id = owner.package_id;
        node.publisher_id = owner.publisher_id;
    }
    return node;
}

KnowledgeGraphEngine::BuildResult KnowledgeGraphEngine::build_graph() {
    const EngineeringContext::LoadGraphResult loaded = context_.load_graph();
    if (!loaded.success) {
        built_ = false;
        return BuildResult{false, loaded.error, 0, 0};
    }

    raw_nodes_.clear();
    raw_edges_.clear();
    for (const oep::repository::EngineeringObject* object : context_.graph().all_objects()) {
        raw_nodes_.push_back(node_from(*object));
    }
    for (const oep::repository::Relationship& relationship : context_.graph().all_relationships()) {
        raw_edges_.push_back(KnowledgeGraphEdge{relationship.relationship_id, relationship.source_object_id,
                                                 relationship.target_object_id, relationship.relationship_type});
    }

    graph_.build(raw_nodes_, raw_edges_);
    built_ = true;
    return BuildResult{true, "", raw_nodes_.size(), raw_edges_.size()};
}

KnowledgeGraphEngine::BuildResult KnowledgeGraphEngine::refresh_graph() {
    return build_graph();
}

bool KnowledgeGraphEngine::object_added(const std::string& object_id) {
    if (!built_) return false;
    const ObjectLoader::LoadObjectResult loaded = context_.load_object(object_id);
    if (!loaded.success || !loaded.found) return false;

    const KnowledgeGraphNode node = node_from(loaded.object);
    // Keep the raw (pre-index) node list in sync too, so validate_graph
    // and a subsequent build/refresh see this addition.
    bool replaced = false;
    for (KnowledgeGraphNode& existing : raw_nodes_) {
        if (existing.object_id == object_id) {
            existing = node;
            replaced = true;
            break;
        }
    }
    if (!replaced) raw_nodes_.push_back(node);

    graph_.add_object(node);
    return true;
}

bool KnowledgeGraphEngine::object_removed(const std::string& object_id) {
    if (!built_) return false;
    raw_nodes_.erase(std::remove_if(raw_nodes_.begin(), raw_nodes_.end(),
                                     [&](const KnowledgeGraphNode& node) { return node.object_id == object_id; }),
                      raw_nodes_.end());
    raw_edges_.erase(std::remove_if(raw_edges_.begin(), raw_edges_.end(),
                                     [&](const KnowledgeGraphEdge& edge) {
                                         return edge.source_object_id == object_id || edge.target_object_id == object_id;
                                     }),
                      raw_edges_.end());
    return graph_.remove_object(object_id);
}

bool KnowledgeGraphEngine::relationship_added(const oep::repository::Relationship& relationship) {
    if (!built_) return false;
    const KnowledgeGraphEdge edge{relationship.relationship_id, relationship.source_object_id,
                                   relationship.target_object_id, relationship.relationship_type};
    bool replaced = false;
    for (KnowledgeGraphEdge& existing : raw_edges_) {
        if (existing.relationship_id == edge.relationship_id) {
            existing = edge;
            replaced = true;
            break;
        }
    }
    if (!replaced) raw_edges_.push_back(edge);

    graph_.add_relationship(edge);
    return true;
}

bool KnowledgeGraphEngine::relationship_removed(const std::string& relationship_id) {
    if (!built_) return false;
    raw_edges_.erase(std::remove_if(raw_edges_.begin(), raw_edges_.end(),
                                     [&](const KnowledgeGraphEdge& edge) { return edge.relationship_id == relationship_id; }),
                      raw_edges_.end());
    return graph_.remove_relationship(relationship_id);
}

void KnowledgeGraphEngine::graph_reindex() {
    graph_.reindex();
}

GraphValidationReport KnowledgeGraphEngine::validate_graph() const {
    return oep::engine::validate_graph(raw_nodes_, raw_edges_);
}

GraphStatistics KnowledgeGraphEngine::graph_statistics() const {
    return compute_statistics(graph_);
}

ComponentsResult KnowledgeGraphEngine::connected_components() const {
    return GraphAlgorithms::connected_components(graph_);
}

GraphPathResult KnowledgeGraphEngine::shortest_path(const std::string& source_object_id,
                                                const std::string& target_object_id) const {
    return GraphAlgorithms::shortest_path(graph_, source_object_id, target_object_id);
}

ReachabilityResult KnowledgeGraphEngine::reachable(const std::string& source_object_id,
                                                    const std::string& target_object_id) const {
    return GraphAlgorithms::reachable(graph_, source_object_id, target_object_id);
}

NeighborhoodResult KnowledgeGraphEngine::neighborhood(const std::string& object_id, int radius) const {
    return GraphAlgorithms::neighborhood(graph_, object_id, radius);
}

GraphSubgraphResult KnowledgeGraphEngine::subgraph(const std::vector<std::string>& object_ids) const {
    return GraphAlgorithms::subgraph(graph_, object_ids);
}

RelationshipExpansionResult KnowledgeGraphEngine::expand_relationships(const std::string& object_id,
                                                                        oep::repository::RelationshipType type) const {
    return GraphAlgorithms::expand_relationships(graph_, object_id, type);
}

std::string KnowledgeGraphEngine::export_json() const {
    return oep::engine::to_json(graph_);
}

std::string KnowledgeGraphEngine::export_graphml_placeholder() const {
    return oep::engine::to_graphml_placeholder(graph_);
}

} // namespace oep::engine
