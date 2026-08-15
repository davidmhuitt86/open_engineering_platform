#pragma once

#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/query_types.hpp"

namespace oep::engine {

// WP-EKE-003's Query Planner. Builds an immutable QueryPlan for
// `request` against `engine`'s CURRENTLY BUILT graph -- "Planning
// shall never execute the query": plan() only ever consults the
// graph's indexes' sizes/membership (all O(1)/O(log n) lookups already
// maintained by KnowledgeGraph) to choose a strategy and estimate cost;
// it never walks an edge, never visits an object's data beyond
// checking membership, and never allocates a result. Deterministic:
// the same request against the same graph state always produces the
// same plan (same strategy, same indexes_used, same execution_order).
class QueryPlanner {
public:
    static QueryPlan plan(const QueryRequest& request, const KnowledgeGraphEngine& engine);
};

} // namespace oep::engine
