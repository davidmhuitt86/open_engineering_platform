#pragma once

#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/query_types.hpp"

namespace oep::engine {

// WP-EKE-003's Query Executor. Executes an already-built QueryPlan
// against `engine`'s currently built graph -- read-only: never
// mutates the graph, never persists anything, never reasons/infers
// (pure lookups/traversals/filters over already-materialized data).
// Deterministic: the same plan against the same graph state always
// produces the same EngineeringQueryResult (same object_ids/relationship_ids
// order).
class QueryExecutor {
public:
    static EngineeringQueryResult execute(const QueryPlan& plan, const KnowledgeGraphEngine& engine);
};

} // namespace oep::engine
