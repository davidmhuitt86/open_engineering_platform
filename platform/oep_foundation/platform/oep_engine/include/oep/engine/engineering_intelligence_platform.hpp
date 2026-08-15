#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/engine/analysis_engine.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/intelligence_types.hpp"
#include "oep/engine/knowledge_session_manager.hpp"
#include "oep/engine/reasoning_engine.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_engine.hpp"

namespace oep::engine {

// WP-EKE-007's Engineering Intelligence Platform (EIP): the top-level
// orchestration layer of platform/oep_engine, composing every
// lower-level engine (Knowledge Graph, Query, Rules, Validation,
// Analysis, Reasoning) into ONE unified engineering runtime. Consumes
// only the PUBLIC APIs of those engines (constructor references) --
// never FoundationRuntime/RuntimeService/repository storage directly,
// and never repeats or reimplements any lower engine's logic; every
// method here is sequencing/composition, exactly like every prior
// "engine on top of engines" this codebase has built (WP-EKE-005's
// ValidationEngine composing RulesEngine, WP-EKE-006's ReasoningEngine
// composing AnalysisEngine+RulesEngine+ValidationEngine).
//
// DESIGN NOTE on the work package's eight named Responsibilities
// (Engineering Intelligence Platform, Knowledge Session Manager,
// Workflow Engine, Service Orchestrator, Unified Engineering API,
// Context Manager, Shared Cache Manager, Runtime Metrics, Engine
// Pipeline): only ONE of these -- the Knowledge Session Manager -- is
// realized as its own separate public class
// (knowledge_session_manager.hpp), because session bookkeeping is a
// genuinely independent concern with its own lifecycle (Create/Resume/
// Clone/Close/Export, tested in isolation). The other seven are
// realized as THIS class's own methods and private helpers, not
// separate public types -- this is a deliberate reading of "Unified
// Engineering API: Implement a single façade... Consumers should not
// know which engine performs the work," taken to its logical
// conclusion: a Workflow Engine, Service Orchestrator, Context
// Manager, Shared Cache Manager, and Runtime Metrics collector that
// were each their own separately-instantiated public class would
// themselves be additional "which engine performs the work" surface
// area for a consumer to learn -- exactly what the Unified API
// principle argues against. Every one of those five responsibilities
// is still fully implemented and independently testable via this
// class's own public methods (workflows via inspect/validate/analyze/
// reason/recommend, orchestration via inspect_object/inspect_package/
// inspect_context/engineering_summary/engineering_health/
// engineering_dependencies/engineering_trace/engineering_recommendations,
// context management via create/resume/clone/close/switch_session,
// caching via invalidate_caches(), metrics via runtime_metrics()) --
// see the "Engine Pipeline" note on execute_workflow's own doc comment
// for how these compose internally.
class EngineeringIntelligencePlatform {
public:
    EngineeringIntelligencePlatform(EngineeringContext& engineering_context, KnowledgeGraphEngine& knowledge_graph_engine,
                                     EngineeringQueryEngine& query_engine, RulesEngine& rules_engine,
                                     ValidationEngine& validation_engine, AnalysisEngine& analysis_engine,
                                     ReasoningEngine& reasoning_engine)
        : engineering_context_(engineering_context),
          knowledge_graph_engine_(knowledge_graph_engine),
          query_engine_(query_engine),
          rules_engine_(rules_engine),
          validation_engine_(validation_engine),
          analysis_engine_(analysis_engine),
          reasoning_engine_(reasoning_engine) {}

    bool graph_ready() const { return knowledge_graph_engine_.graph_built(); }

    // ---------------------------------------------------------------
    // Knowledge Session Manager (Context Manager: "Loaded Knowledge
    // Sessions", "Session Switching", "Resource Cleanup")
    // ---------------------------------------------------------------

    std::string create_session() { return sessions_.create_session(); }
    bool resume_session(const std::string& session_id) { return sessions_.resume_session(session_id); }
    std::optional<std::string> clone_session(const std::string& session_id) { return sessions_.clone_session(session_id); }
    bool close_session(const std::string& session_id);
    std::optional<KnowledgeSession> get_session(const std::string& session_id) const { return sessions_.get_session(session_id); }
    std::vector<std::string> list_sessions() const { return sessions_.list_sessions(); }
    std::optional<std::string> export_session_summary(const std::string& session_id) const {
        return sessions_.export_summary(session_id);
    }

    // "Session Switching": which session subsequent workflow calls
    // append history to by default when a caller does not explicitly
    // pass a session_id to a Service Orchestrator method (the
    // inspect_object/engineering_summary/etc. methods below never
    // require a session at all -- they are stateless; only the
    // Workflow methods (inspect/validate/analyze/reason/recommend)
    // are session-scoped, and always take an explicit session_id
    // rather than relying on this "current" pointer -- current_session
    // exists purely as a Context Manager convenience for a caller
    // (e.g. the CLI) that wants a single active session without
    // re-passing its id everywhere). Returns false if `session_id` is
    // unknown or closed.
    bool switch_session(const std::string& session_id);
    const std::string& current_session_id() const { return current_session_id_; }

    // "Resource Cleanup": closes every open session and clears every
    // lower engine's cache (see invalidate_caches()).
    void cleanup();

    // ---------------------------------------------------------------
    // Workflow Engine ("Each workflow executes through the platform
    // without exposing internal engines")
    // ---------------------------------------------------------------

    // "Query" workflow: not itself one of this work package's nine
    // named Runtime API entries (those are inspect/validate/analyze/
    // reason/recommend, plus session/summary/metrics management), but
    // WP-EKE-007's own Workflow Engine section names Query as one of
    // the six supported workflows -- included here as the natural
    // completion, exactly the same pattern every prior WP-EKE work
    // package has followed when a section's own capability list is
    // broader than its literal minimal Runtime API list.
    WorkflowResult query(const std::string& session_id, QueryCategory category, const std::string& primary_object_id);

    WorkflowResult inspect(const std::string& session_id, InspectionTargetKind kind, const std::string& target_id);
    WorkflowResult validate(const std::string& session_id, const std::string& object_id, ValidationProfile profile);
    WorkflowResult analyze(const std::string& session_id, const std::string& object_id);
    WorkflowResult reason(const std::string& session_id, const std::string& objective,
                           const std::vector<std::string>& starting_objects);
    WorkflowResult recommend(const std::string& session_id, const std::string& object_id);

    // ---------------------------------------------------------------
    // Service Orchestrator ("The caller never invokes multiple engines
    // directly") -- stateless (no session required); the Workflow
    // methods above call these internally and additionally record
    // session history.
    // ---------------------------------------------------------------

    InspectionReport inspect_object(const std::string& object_id);
    InspectionReport inspect_package(const std::string& package_id);
    InspectionReport inspect_context();
    EngineeringSummaryReport engineering_summary();
    EngineeringHealthReport engineering_health();
    DependencyReport engineering_dependencies(const std::string& object_id);
    ReachabilityReport engineering_trace(const std::string& source_object_id, const std::string& target_object_id);
    std::vector<EngineeringRecommendation> engineering_recommendations(const std::string& object_id);

    // ---------------------------------------------------------------
    // Shared Cache Manager
    // ---------------------------------------------------------------

    // Deterministic invalidation: clears the Query Engine's cache
    // (WP-EKE-003's QueryCache, the only lower engine that maintains an
    // actual cache today -- Knowledge Graph/Analysis/Reasoning always
    // compute fresh, so "coordinating" them here means this is the
    // ONE call site a caller needs, regardless of which lower engines
    // gain their own caches in a future work package).
    void invalidate_caches();

    // ---------------------------------------------------------------
    // Runtime Metrics
    // ---------------------------------------------------------------

    RuntimeMetrics runtime_metrics() const;

private:
    EngineeringContext& engineering_context_;
    KnowledgeGraphEngine& knowledge_graph_engine_;
    EngineeringQueryEngine& query_engine_;
    RulesEngine& rules_engine_;
    ValidationEngine& validation_engine_;
    AnalysisEngine& analysis_engine_;
    ReasoningEngine& reasoning_engine_;

    KnowledgeSessionManager sessions_;
    std::string current_session_id_;
    RuntimeMetrics metrics_;
};

} // namespace oep::engine
