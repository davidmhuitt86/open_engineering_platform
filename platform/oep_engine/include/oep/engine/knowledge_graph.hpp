#pragma once

#include <map>
#include <set>
#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::engine {

// WP-EKE-002: one node in the canonical Knowledge Graph -- an
// Engineering Object plus the ownership metadata (package/publisher)
// KnowledgeGraphEngine resolved for it via EngineeringContext::find_owner.
// `domains` mirrors EngineeringObject::tags (see RuntimeGraph's own doc
// comment, WP-EKE-001, for why "domain" maps onto the existing `tags`
// field rather than a new primitive).
struct KnowledgeGraphNode {
    std::string object_id;
    oep::repository::ObjectType object_type = oep::repository::ObjectType::Document;
    std::string name;
    std::vector<std::string> domains;
    std::string package_id;    // empty if the object was not contributed by any installed package
    std::string publisher_id;  // empty if package_id is empty or the package has no recorded publisher
};

struct KnowledgeGraphEdge {
    std::string relationship_id;
    std::string source_object_id;
    std::string target_object_id;
    oep::repository::RelationshipType relationship_type = oep::repository::RelationshipType::References;
};

// One edge as seen from one of its endpoints.
struct KnowledgeGraphEdgeView {
    std::string relationship_id;
    std::string neighbor_object_id;
    oep::repository::RelationshipType relationship_type;
    bool outgoing = true;
};

// The canonical, in-memory Knowledge Graph (WP-EKE-002). Exists only in
// memory (never persisted -- serialization, see graph_serialization.hpp,
// is a read-only EXPORT for diagnostics, not a save/load mechanism).
// Distinct from RuntimeGraph (WP-EKE-001): KnowledgeGraph adds Domain/
// Publisher/Package/Direction indexes RuntimeGraph does not have, and
// supports true incremental mutation (add/remove a single node or edge
// without rebuilding), per this work package's own requirements.
//
// A relationship whose source or target is not (yet) a node in the
// graph is simply not connected to anything by edges_of/adjacency —
// build() still records it in all_edges() (unlike RuntimeGraph, which
// excludes dangling edges outright) specifically so
// GraphIntegrityValidator can detect "missing endpoint" issues against
// the graph's actual input, not a pre-filtered view of it.
class KnowledgeGraph {
public:
    KnowledgeGraph() = default;

    // Full construction: replaces all prior content. Deterministic --
    // the same nodes/edges always produce the same indexes and edge
    // ordering, regardless of input order.
    void build(std::vector<KnowledgeGraphNode> nodes, std::vector<KnowledgeGraphEdge> edges);
    void clear();

    // Incremental updates (WP-EKE-002 requirement: do not require
    // rebuilding the entire graph). Each keeps every index synchronized.
    // add_object on an already-present object_id replaces it in place
    // (its edges are unaffected). add_relationship on an already-present
    // relationship_id replaces it (old edge views removed, new ones
    // added). remove_object also removes every edge touching it.
    void add_object(KnowledgeGraphNode node);
    bool remove_object(const std::string& object_id); // false if not present
    void add_relationship(KnowledgeGraphEdge edge);
    bool remove_relationship(const std::string& relationship_id); // false if not present

    // Recomputes every index from the current node/edge lists, from
    // scratch. Never changes graph CONTENT (nodes/edges), only index
    // structures -- meaningful as an explicit "trust the indexes less,
    // trust the content more" operation (WP-EKE-002's "Graph Reindex"),
    // even though add/remove above already keep indexes synchronized
    // incrementally.
    void reindex();

    bool contains(const std::string& object_id) const;
    const KnowledgeGraphNode* find_node(const std::string& object_id) const;
    std::vector<const KnowledgeGraphNode*> all_nodes() const; // sorted by object_id
    const std::vector<KnowledgeGraphEdge>& all_edges() const { return edges_; } // insertion order

    // Edges touching `object_id` whose OTHER endpoint is also a node in
    // the graph (i.e. connectivity-relevant edges) -- sorted by
    // neighbor id then relationship id.
    std::vector<KnowledgeGraphEdgeView> edges_of(const std::string& object_id) const;

    // Indexes (WP-EKE-002's Relationship Index).
    std::vector<std::string> ids_by_object_type(oep::repository::ObjectType type) const;
    std::vector<std::string> ids_by_domain(const std::string& domain) const;
    std::vector<std::string> ids_by_relationship_type(oep::repository::RelationshipType type) const;
    std::vector<std::string> ids_by_publisher(const std::string& publisher_id) const;
    std::vector<std::string> ids_by_package(const std::string& package_id) const;
    // Direction index: objects for which `object_id` is the source (outgoing) / target (incoming).
    std::vector<std::string> outgoing_neighbors(const std::string& object_id) const;
    std::vector<std::string> incoming_neighbors(const std::string& object_id) const;

    std::size_t node_count() const { return nodes_.size(); }
    std::size_t edge_count() const { return edges_.size(); }

private:
    std::map<std::string, KnowledgeGraphNode> nodes_;
    std::vector<KnowledgeGraphEdge> edges_;
    std::map<std::string, std::vector<KnowledgeGraphEdgeView>> adjacency_;
    std::map<oep::repository::ObjectType, std::set<std::string>> by_type_;
    std::map<std::string, std::set<std::string>> by_domain_;
    std::map<oep::repository::RelationshipType, std::set<std::string>> by_relationship_type_;
    std::map<std::string, std::set<std::string>> by_publisher_;
    std::map<std::string, std::set<std::string>> by_package_;

    void index_node(const KnowledgeGraphNode& node);
    void deindex_node(const KnowledgeGraphNode& node);
    void index_edge(const KnowledgeGraphEdge& edge);
};

} // namespace oep::engine
