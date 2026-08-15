#pragma once

#include <string>
#include <vector>

#include "oep/engine/object_loader.hpp"
#include "oep/engine/query_engine.hpp"
#include "oep/engine/relationship_engine.hpp"
#include "oep/engine/runtime_graph.hpp"
#include "oep/engine/traversal_engine.hpp"
#include "oep/runtime/runtime_service.hpp"

namespace oep::engine {

// WP-EKE-001's EngineeringContext: the Engineering Knowledge Runtime's
// single entry point, combining the Object Loader (caches), the Runtime
// Graph (indexes), and the Relationship/Query/Traversal Engines
// (knowledge services) behind the six-method Public Runtime API the
// work package specifies: load_object, load_graph, query, traverse,
// related_objects, dependency_graph.
//
// EngineeringContext consumes Foundation EXCLUSIVELY through the
// oep::runtime::RuntimeService reference supplied at construction — it
// never touches FoundationRuntime's storage accessors, never opens a
// Repository Transaction, never verifies trust, and never resolves
// package dependencies (all of that belongs to Foundation, per
// WP-EKE-001's "The EKR SHALL NOT" list). `dependency_graph` below
// walks Engineering Object DependsOn RELATIONSHIPS (an engineering
// semantics concept, RelationshipType::DependsOn) — an entirely
// different thing from Foundation's Dependency Resolution Engine
// (WP-REP-005), which resolves PACKAGE manifest dependencies before
// install. The two share a name in English only.
class EngineeringContext {
public:
    explicit EngineeringContext(oep::runtime::RuntimeService& service) : service_(service), loader_(service) {}

    // Lazy: loads (and caches) exactly one object, without touching or
    // rebuilding the graph.
    ObjectLoader::LoadObjectResult load_object(const std::string& object_id) { return loader_.load_object(object_id); }

    struct LoadGraphResult {
        bool success = false;
        std::string error;
        std::size_t objects_loaded = 0;
        std::size_t relationships_loaded = 0;
    };

    // Batch loading + graph hydration: fetches every object and
    // relationship via the Object Loader, then (re)builds the Runtime
    // Graph from that snapshot. Must be called (and succeed) before
    // query/traverse/related_objects/dependency_graph — those report a
    // clear "graph not loaded" error otherwise, rather than silently
    // operating on an empty graph.
    LoadGraphResult load_graph();

    bool graph_loaded() const { return graph_loaded_; }
    const RuntimeGraph& graph() const { return graph_; }

    enum class QueryKind {
        ById,
        ByType,
        ByDomain,
        ByRelationship,
        ShortestPath,
        ConnectedComponent,
        Subgraph,
    };

    // A single discriminated request type covers every Graph Query
    // WP-EKE-001 lists (Find by ID/Type/Domain/Relationship, Shortest
    // path, Connected graph, Subgraph) behind the one `query()` method
    // the work package's Public Runtime API names — callers populate
    // only the field(s) `kind` needs; the rest are ignored.
    struct QueryRequest {
        QueryKind kind = QueryKind::ById;
        std::string object_id;                  // ById, ConnectedComponent
        oep::repository::ObjectType object_type = oep::repository::ObjectType::Document; // ByType
        std::string domain;                      // ByDomain
        oep::repository::RelationshipType relationship_type =
            oep::repository::RelationshipType::References; // ByRelationship
        std::string source_object_id;            // ShortestPath
        std::string target_object_id;            // ShortestPath
        std::vector<std::string> object_ids;      // Subgraph
    };

    QueryResult query(const QueryRequest& request) const;
    PathResult shortest_path(const std::string& source_object_id, const std::string& target_object_id) const;
    SubgraphResult subgraph(const std::vector<std::string>& object_ids) const;

    TraversalResult traverse(const std::string& start_object_id, const TraversalOptions& options = {}) const;

    // Every object directly connected to `object_id` (RelationshipEngine::neighbors).
    RelatedObjectsResult related_objects(const std::string& object_id) const;

    struct DependencyGraphResult {
        bool success = false;
        std::string error;
        std::vector<std::string> object_ids;
        std::vector<std::string> relationship_ids;
    };

    // The full transitive closure of `object_id`'s outgoing DependsOn
    // relationships: `object_id` itself, plus every object reachable by
    // following only DependsOn edges outward.
    DependencyGraphResult dependency_graph(const std::string& object_id) const;

    // Package ownership for `object_id`, WP-EKE-002's only channel for
    // knowing which package/publisher contributed an Engineering
    // Object -- still exclusively through RuntimeService (see
    // RuntimeService::find_package_owner), never the Repository
    // Registry directly.
    struct OwnerInfo {
        bool has_owner = false;
        std::string package_id;
        std::string publisher_id;
        std::string publisher_name;
    };
    OwnerInfo find_owner(const std::string& object_id) const;

private:
    oep::runtime::RuntimeService& service_;
    ObjectLoader loader_;
    RuntimeGraph graph_;
    bool graph_loaded_ = false;
};

} // namespace oep::engine
