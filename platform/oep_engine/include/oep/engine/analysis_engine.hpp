#pragma once

#include <optional>

#include "oep/engine/analysis_types.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/validation_engine.hpp"

namespace oep::engine {

// WP-EKE-006's Analysis Engine: four deterministic structural analyses
// over the Knowledge Graph -- analyze_dependencies, analyze_impact,
// analyze_reachability (the three of the work package's own Runtime
// API that need no rules/validation input, pure graph algorithms
// reused from WP-EKE-002's GraphAlgorithms), and analyze_root_cause
// (which additionally consults a ValidationEngine's most recent report
// for a session, to find which of an object's dependencies have
// outstanding validation findings). Consumes the Knowledge Graph
// Engine and (for root-cause only) a ValidationEngine -- never
// FoundationRuntime/RuntimeService/repository storage.
class AnalysisEngine {
public:
    explicit AnalysisEngine(KnowledgeGraphEngine& knowledge_graph_engine) : knowledge_graph_engine_(knowledge_graph_engine) {}

    DependencyReport analyze_dependencies(const std::string& object_id) const;
    ImpactReport analyze_impact(const std::string& object_id) const;
    ReachabilityReport analyze_reachability(const std::string& source_object_id, const std::string& target_object_id) const;

    // Root cause analysis needs to know which objects currently have
    // validation findings -- `finding_object_ids` is supplied by the
    // caller (typically every affected_objects() entry across a
    // ValidationReport's findings, e.g. from ValidationEngine), since
    // AnalysisEngine itself has no opinion on which ValidationSession
    // or profile to consult; this keeps AnalysisEngine a pure function
    // of the Knowledge Graph plus whatever finding set the caller
    // already computed via the Validation Engine.
    RootCauseReport analyze_root_cause(const std::string& symptom_object_id,
                                        const std::vector<std::string>& finding_object_ids) const;

private:
    KnowledgeGraphEngine& knowledge_graph_engine_;
};

} // namespace oep::engine
