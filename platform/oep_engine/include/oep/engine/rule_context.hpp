#pragma once

#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/graph_statistics.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/rule_types.hpp"

namespace oep::engine {

// WP-EKE-004's immutable RuleEvaluationContext: gives a RuleEvaluator
// access to exactly EngineeringContext, the Knowledge Graph, the Query
// Engine, Graph Statistics, and Configuration -- the five things the
// work package names, and nothing else (no FoundationRuntime, no
// RuntimeService, no repository storage). References are non-owning;
// the referenced engines must outlive every RuleEvaluationContext built
// from them. `graph_statistics` is a snapshot taken at construction
// time (WP-EKE-002's `compute_statistics`, not a live reference), since
// statistics are themselves the RESULT of a computation, not a
// queryable service.
class RuleEvaluationContext {
public:
    RuleEvaluationContext(EngineeringContext& engineering_context, KnowledgeGraphEngine& knowledge_graph_engine,
                           EngineeringQueryEngine& query_engine, GraphStatistics graph_statistics,
                           RuleConfiguration configuration)
        : engineering_context_(engineering_context),
          knowledge_graph_engine_(knowledge_graph_engine),
          query_engine_(query_engine),
          graph_statistics_(std::move(graph_statistics)),
          configuration_(std::move(configuration)) {}

    EngineeringContext& engineering_context() const { return engineering_context_; }
    KnowledgeGraphEngine& knowledge_graph_engine() const { return knowledge_graph_engine_; }
    EngineeringQueryEngine& query_engine() const { return query_engine_; }
    const KnowledgeGraph& graph() const { return knowledge_graph_engine_.graph(); }
    const GraphStatistics& graph_statistics() const { return graph_statistics_; }
    const RuleConfiguration& configuration() const { return configuration_; }

private:
    EngineeringContext& engineering_context_;
    KnowledgeGraphEngine& knowledge_graph_engine_;
    EngineeringQueryEngine& query_engine_;
    GraphStatistics graph_statistics_;
    RuleConfiguration configuration_;
};

} // namespace oep::engine
