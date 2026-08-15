#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

#include "oep/engine/analysis_engine.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/reasoning_types.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_engine.hpp"

namespace oep::engine {

// WP-EKE-006's Reasoning Engine: the top-level facade, exposing the
// eight-method Runtime API the work package specifies:
// analyze_dependencies/analyze_impact/analyze_root_cause/
// analyze_reachability (pass-through to AnalysisEngine, held here so
// the Runtime API has one entry point per this work package's naming),
// create_reasoning_session/execute_reasoning/reasoning_report/
// engineering_recommendations (the Reasoning Engine's own
// responsibility).
//
// Consumes EngineeringContext, the Knowledge Graph, the Query Engine,
// the Rules Engine, and the Validation Engine ONLY -- never
// FoundationRuntime/RuntimeService/repository storage directly.
// Deterministic, evidence-based, fully explainable: every
// EngineeringConclusion and EngineeringRecommendation this class
// produces carries a non-empty supporting-evidence id list referencing
// concrete EvidenceNodes in that session's own EvidenceGraph, each of
// which in turn names exactly which Object/Relationship/query/rule/
// finding it came from. Nothing here calls an external AI service or
// performs probabilistic inference -- `confidence` is a documented,
// deterministic arithmetic function of evidence count (see
// reasoning_engine.cpp).
class ReasoningEngine {
public:
    ReasoningEngine(EngineeringContext& engineering_context, KnowledgeGraphEngine& knowledge_graph_engine,
                     EngineeringQueryEngine& query_engine, RulesEngine& rules_engine, ValidationEngine& validation_engine)
        : engineering_context_(engineering_context),
          knowledge_graph_engine_(knowledge_graph_engine),
          query_engine_(query_engine),
          rules_engine_(rules_engine),
          validation_engine_(validation_engine),
          analysis_engine_(knowledge_graph_engine) {}

    bool graph_ready() const { return knowledge_graph_engine_.graph_built(); }

    // Direct pass-through to AnalysisEngine (WP-EKE-006's own Runtime
    // API names these at the Reasoning Engine level).
    DependencyReport analyze_dependencies(const std::string& object_id) const {
        return analysis_engine_.analyze_dependencies(object_id);
    }
    ImpactReport analyze_impact(const std::string& object_id) const { return analysis_engine_.analyze_impact(object_id); }
    ReachabilityReport analyze_reachability(const std::string& source_object_id, const std::string& target_object_id) const {
        return analysis_engine_.analyze_reachability(source_object_id, target_object_id);
    }
    // Root cause analysis first validates `symptom_object_id` and its
    // dependencies (Complete profile) to discover which have
    // outstanding findings, then delegates to AnalysisEngine.
    RootCauseReport analyze_root_cause(const std::string& symptom_object_id);

    // Starts a new ReasoningSession for `objective`, scoped to
    // `starting_objects`. Returns its session_id (a UUIDv4).
    std::string create_reasoning_session(std::string objective, std::vector<std::string> starting_objects);

    // Runs the session: for each starting object, performs dependency/
    // impact/root-cause analysis, validates it (Complete profile),
    // builds this session's Evidence Graph from every object/finding/
    // rule touched, derives EngineeringConclusions, and generates
    // EngineeringRecommendations -- all evidence-referenced. Finalizes
    // the session (end time, queries/rules/validation summaries) and
    // returns the resulting ReasoningReport. Returns nullopt if
    // `session_id` was never created, or if graph_ready() is false.
    std::optional<ReasoningReport> execute_reasoning(const std::string& session_id);

    std::optional<ReasoningReport> reasoning_report(const std::string& session_id) const;
    std::vector<EngineeringRecommendation> engineering_recommendations(const std::string& session_id) const;

private:
    EngineeringContext& engineering_context_;
    KnowledgeGraphEngine& knowledge_graph_engine_;
    EngineeringQueryEngine& query_engine_;
    RulesEngine& rules_engine_;
    ValidationEngine& validation_engine_;
    AnalysisEngine analysis_engine_;

    struct SessionState {
        std::string start_time_utc;
        std::string objective;
        std::vector<std::string> starting_objects;
        std::optional<ReasoningReport> last_report;
    };
    std::map<std::string, SessionState> sessions_;
};

} // namespace oep::engine
