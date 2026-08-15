#pragma once

#include <string>
#include <vector>

#include "oep/engine/engineering_context.hpp"
#include "oep/engine/graph_algorithms.hpp"
#include "oep/engine/graph_statistics.hpp"
#include "oep/engine/graph_validator.hpp"
#include "oep/engine/knowledge_graph.hpp"

namespace oep::engine {

// WP-EKE-002's Knowledge Graph Engine (EKGE): constructs, maintains,
// validates, and exposes the canonical in-memory Knowledge Graph.
//
// Consumes EngineeringContext ONLY -- never a RuntimeService, never
// FoundationRuntime, never repository storage. Every method here that
// touches Foundation data does so exclusively through the
// EngineeringContext& supplied at construction (which itself only
// holds a RuntimeService&); this class never opens a transaction,
// never persists anything, and never modifies packages.
class KnowledgeGraphEngine {
public:
    explicit KnowledgeGraphEngine(EngineeringContext& context) : context_(context) {}

    struct BuildResult {
        bool success = false;
        std::string error;
        std::size_t objects = 0;
        std::size_t relationships = 0;
    };

    // Full graph construction (WP-EKE-002's "Full graph construction"):
    // reloads everything from EngineeringContext (calling
    // context.load_graph() to (re)hydrate it), resolves each object's
    // package/publisher ownership via context.find_owner(), and
    // (re)builds the Knowledge Graph and every index from scratch.
    // Deterministic: the same repository content always produces the
    // same graph and index contents.
    BuildResult build_graph();

    // "Graph refresh" / "Graph rebuild": identical to build_graph() --
    // both fully re-pull from EngineeringContext and rebuild. Exposed
    // as a separate, equally-named method because WP-EKE-002 names both
    // operations explicitly in its Runtime API; true incremental
    // updates (which do NOT require a full re-pull) are the
    // object_added/removed and relationship_added/removed methods below.
    BuildResult refresh_graph();

    bool graph_built() const { return built_; }
    const KnowledgeGraph& graph() const { return graph_; }

    // ---------------------------------------------------------------
    // Incremental Updates (WP-EKE-002)
    // ---------------------------------------------------------------
    //
    // Do not require rebuilding the entire graph. Since
    // EngineeringContext/RuntimeService have no event-subscription
    // mechanism (WP-REP-006 deliberately ships Repository Events as
    // publish-only infrastructure with no subscribers yet), the
    // Knowledge Graph Engine cannot detect a Foundation-side mutation
    // on its own -- these methods are CALLER-DRIVEN: a caller that just
    // performed (or otherwise learned of) a mutation elsewhere invokes
    // the matching method here to keep this engine's already-built
    // graph synchronized, without paying for a full rebuild.

    // Re-fetches `object_id` via EngineeringContext (lazy load) and
    // its ownership via find_owner(), then adds/replaces the
    // corresponding node. Returns false if the object could not be
    // found or the graph has not been built yet.
    bool object_added(const std::string& object_id);

    // Removes `object_id` and every edge touching it. Returns false if
    // the graph has not been built yet (removing an object that was
    // never in the graph is a harmless no-op, not a failure).
    bool object_removed(const std::string& object_id);

    // Adds/replaces the given relationship directly -- the caller
    // already has the Relationship record (e.g. from having just
    // created it via RuntimeService), so this does not re-fetch it.
    bool relationship_added(const oep::repository::Relationship& relationship);
    bool relationship_removed(const std::string& relationship_id);

    // Recomputes every index from the graph's current content without
    // touching that content ("Graph Reindex").
    void graph_reindex();

    // ---------------------------------------------------------------
    // Validation, Algorithms, Statistics, Serialization
    // ---------------------------------------------------------------

    // Validates the graph as it was last built/refreshed (using the
    // RAW node/edge lists retained from that build, so missing-endpoint
    // and similar issues are genuinely detectable -- see
    // graph_validator.hpp). Never mutates the graph.
    GraphValidationReport validate_graph() const;

    GraphStatistics graph_statistics() const;
    ComponentsResult connected_components() const;
    GraphPathResult shortest_path(const std::string& source_object_id, const std::string& target_object_id) const;
    ReachabilityResult reachable(const std::string& source_object_id, const std::string& target_object_id) const;
    NeighborhoodResult neighborhood(const std::string& object_id, int radius) const;
    GraphSubgraphResult subgraph(const std::vector<std::string>& object_ids) const;
    RelationshipExpansionResult expand_relationships(const std::string& object_id,
                                                       oep::repository::RelationshipType type) const;

    std::string export_json() const;
    std::string export_graphml_placeholder() const;

private:
    EngineeringContext& context_;
    KnowledgeGraph graph_;
    std::vector<KnowledgeGraphNode> raw_nodes_;
    std::vector<KnowledgeGraphEdge> raw_edges_;
    bool built_ = false;

    KnowledgeGraphNode node_from(const oep::repository::EngineeringObject& object) const;
};

} // namespace oep::engine
