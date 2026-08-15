#pragma once

#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/query_cache.hpp"
#include "oep/engine/query_types.hpp"

namespace oep::engine {

// WP-EKE-003's Engineering Query Engine (EQE) -- named distinctly from
// WP-EKE-001's `oep::engine::QueryEngine` (a static helper class of
// find_by_* functions) to avoid a symbol collision; this is the new
// work package's top-level facade, exposing the five-method Runtime
// API it specifies: plan_query, execute_query, query_statistics,
// query_cache, clear_query_cache.
//
// Consumes the Knowledge Graph Engine ONLY (constructor takes a
// KnowledgeGraphEngine&, which itself only holds an
// EngineeringContext&) -- never a RuntimeService, FoundationRuntime,
// or repository storage. Read-only: never modifies the Knowledge
// Graph, never persists anything, never opens a transaction, never
// performs reasoning or inference (every query category is a lookup/
// filter/traversal over already-materialized graph data, nothing more).
class EngineeringQueryEngine {
public:
    explicit EngineeringQueryEngine(KnowledgeGraphEngine& knowledge_graph_engine)
        : knowledge_graph_engine_(knowledge_graph_engine) {}

    // Builds (or returns the cached) QueryPlan for `request`. Never
    // executes the query.
    QueryPlan plan_query(const QueryRequest& request);

    // Executes `plan` (or returns the cached EngineeringQueryResult for an
    // identical request, if one is cached). Also updates
    // query_statistics() to reflect this call.
    EngineeringQueryResult execute_query(const QueryPlan& plan);

    // Convenience: plan_query(request) followed by execute_query(plan)
    // in one call -- the common path.
    EngineeringQueryResult execute_query(const QueryRequest& request);

    // The most recently executed query's statistics. Zero-valued
    // (default QueryStatistics{}) if no query has been executed yet on
    // this EngineeringQueryEngine instance.
    const QueryStatistics& query_statistics() const { return last_statistics_; }

    const QueryCache& query_cache() const { return cache_; }

    // Discards every cached plan and result. Per WP-EKE-003, "Cache
    // invalidation shall occur only when EngineeringContext
    // refreshes" -- callers MUST call this after rebuilding/refreshing
    // the Knowledge Graph (KnowledgeGraphEngine::build_graph/
    // refresh_graph), since this class has no way to detect that on
    // its own (the same caller-driven synchronization limitation
    // WP-EKE-002 already documents for its own incremental updates).
    void clear_query_cache() { cache_.clear(); }

private:
    KnowledgeGraphEngine& knowledge_graph_engine_;
    QueryCache cache_;
    QueryStatistics last_statistics_;
};

} // namespace oep::engine
