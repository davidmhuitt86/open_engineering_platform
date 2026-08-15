#pragma once

#include <filesystem>
#include <memory>
#include <string>

#include "oep/engine/analysis_engine.hpp"
#include "oep/engine/engineering_context.hpp"
#include "oep/engine/engineering_intelligence_platform.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/reasoning_engine.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_engine.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"

namespace oep::cli::commands {

// Shared plumbing for every `oep session`/`oep inspect`/`oep summary`/
// `oep metrics`/`oep workflow` command (WP-EKE-007): a fully wired
// EngineeringIntelligencePlatform over a fresh, process-local runtime.
// Mirrors reasoning_command.cpp/analysis_command.cpp's
// OpenedReasoningEngine exactly, plus the two additional members
// WP-EKE-007 itself adds at the C API layer (`analysis` and `eip` --
// see oep_api_internal.hpp's own doc comment for why AnalysisEngine
// needs its own instance here rather than reusing ReasoningEngine's
// private one).
//
// Process-local, no persistence -- exactly like every prior EKE
// session-based command (`oep evalidate`, `oep reasoning`): every
// invocation opens the repository, constructs a fresh
// EngineeringIntelligencePlatform (over fresh, EMPTY lower-engine
// state), performs its own operation, then exits. A session_id
// created by ONE `oep session`/`oep workflow` invocation can never be
// resolved by a SEPARATE invocation -- see session_command.hpp and
// workflow_command.hpp for how each command handles this.
struct OpenedIntelligencePlatform {
    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext context;
    oep::engine::KnowledgeGraphEngine kge;
    oep::engine::EngineeringQueryEngine eqe;
    oep::engine::RulesEngine rules;
    oep::engine::ValidationEngine validation;
    oep::engine::ReasoningEngine reasoning;
    oep::engine::AnalysisEngine analysis;
    oep::engine::EngineeringIntelligencePlatform eip;

    explicit OpenedIntelligencePlatform(const std::string& foundation_version)
        : runtime(foundation_version), service(oep::runtime::RuntimeContext(runtime, events)), context(service),
          kge(context), eqe(kge), rules(context, kge, eqe), validation(context, kge, eqe, rules),
          reasoning(context, kge, eqe, rules, validation), analysis(kge),
          eip(context, kge, eqe, rules, validation, analysis, reasoning) {}
};

// Opens `repository_path` only (no graph load/build). Returns nullptr
// (having already printed a descriptive error) on failure.
std::unique_ptr<OpenedIntelligencePlatform> open_intelligence_platform(const std::filesystem::path& repository_path);

// Opens the repository AND gets the Knowledge Graph fully ready
// (EngineeringIntelligencePlatform::graph_ready() requires BOTH
// EngineeringContext::load_graph() and KnowledgeGraphEngine::build_graph()
// to have already succeeded). Returns nullptr (having already printed a
// descriptive error) on failure.
std::unique_ptr<OpenedIntelligencePlatform> open_and_ready_intelligence_platform(
    const std::filesystem::path& repository_path);

} // namespace oep::cli::commands
