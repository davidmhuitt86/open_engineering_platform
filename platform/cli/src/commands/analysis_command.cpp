#include "analysis_command.hpp"

#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>

#include "oep/engine/analysis_types.hpp"
#include "oep/engine/engineering_context.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/reasoning_engine.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_engine.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Mirrors evalidate_command.cpp's OpenedValidationEngine, plus
// `reasoning` (oep::engine::ReasoningEngine, constructed from
// `context`/`kge`/`eqe`/`rules`/`validation` -- never from
// `service`/`runtime` directly, per WP-EKE-006's layering requirement).
// `rules` starts with an EMPTY Rule Registry every time -- see
// analysis_command.hpp's header doc comment.
struct OpenedReasoningEngine {
    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext context;
    oep::engine::KnowledgeGraphEngine kge;
    oep::engine::EngineeringQueryEngine eqe;
    oep::engine::RulesEngine rules;
    oep::engine::ValidationEngine validation;
    oep::engine::ReasoningEngine reasoning;

    explicit OpenedReasoningEngine(const std::string& foundation_version)
        : runtime(foundation_version), service(oep::runtime::RuntimeContext(runtime, events)), context(service),
          kge(context), eqe(kge), rules(context, kge, eqe), validation(context, kge, eqe, rules),
          reasoning(context, kge, eqe, rules, validation) {}
};

std::unique_ptr<OpenedReasoningEngine> open_repository(const std::filesystem::path& repository_path) {
    auto engine = std::make_unique<OpenedReasoningEngine>(kFoundationVersion);
    engine->runtime.initialize();

    const oep::runtime::RuntimeResult opened = engine->runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    return engine;
}

// Opens the repository and gets the Knowledge Graph fully ready for
// analysis (ReasoningEngine::graph_ready() requires BOTH
// EngineeringContext::load_graph() and KnowledgeGraphEngine::build_graph()
// to have already succeeded). Returns nullptr (having already printed a
// descriptive error) on failure.
std::unique_ptr<OpenedReasoningEngine> open_and_ready_for_analysis(const std::filesystem::path& repository_path) {
    std::unique_ptr<OpenedReasoningEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return nullptr;

    const oep::engine::EngineeringContext::LoadGraphResult loaded = engine->context.load_graph();
    if (!loaded.success) {
        std::cerr << "oep: could not load the Runtime Graph: " << loaded.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    const oep::engine::KnowledgeGraphEngine::BuildResult built = engine->kge.build_graph();
    if (!built.success) {
        std::cerr << "oep: could not build the Knowledge Graph: " << built.error << "\n";
        engine->runtime.shutdown();
        return nullptr;
    }

    return engine;
}

void print_id_list(const std::string& label, const std::vector<std::string>& ids) {
    std::cout << label << " (" << ids.size() << "):\n";
    if (ids.empty()) {
        std::cout << "  (none)\n";
        return;
    }
    for (const std::string& id : ids) {
        std::cout << "  " << id << "\n";
    }
}

} // namespace

std::string AnalysisCommand::name() const {
    return "analysis";
}

std::string AnalysisCommand::description() const {
    return "Run Engineering Analysis (WP-EKE-006) against the Knowledge Graph: dependencies, impact, root-cause, "
           "reachability";
}

int AnalysisCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'analysis' requires a subcommand (dependencies, impact, root-cause, reachability)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "dependencies") return dependencies(rest);
    if (subcommand == "impact") return impact(rest);
    if (subcommand == "root-cause") return root_cause(rest);
    if (subcommand == "reachability") return reachability(rest);

    std::cerr << "oep: unknown 'analysis' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int AnalysisCommand::dependencies(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'analysis dependencies' requires an object ID\n";
        std::cerr << "Usage: oep analysis dependencies <object-id> [--repository <path>]\n";
        return 1;
    }
    const std::string object_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedReasoningEngine> engine = open_and_ready_for_analysis(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::DependencyReport report = engine->reasoning.analyze_dependencies(object_id);
    std::cout << "Object: " << report.object_id() << "\n";
    std::cout << "Max depth: " << report.max_depth() << "\n";
    print_id_list("Dependency objects", report.dependency_object_ids());
    print_id_list("Dependency relationships", report.dependency_relationship_ids());
    std::cout << "Evidence: " << report.evidence() << "\n";

    engine->runtime.shutdown();
    return 0;
}

int AnalysisCommand::impact(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'analysis impact' requires an object ID\n";
        std::cerr << "Usage: oep analysis impact <object-id> [--repository <path>]\n";
        return 1;
    }
    const std::string object_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedReasoningEngine> engine = open_and_ready_for_analysis(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::ImpactReport report = engine->reasoning.analyze_impact(object_id);
    std::cout << "Object: " << report.object_id() << "\n";
    std::cout << "Max depth: " << report.max_depth() << "\n";
    print_id_list("Affected objects", report.affected_object_ids());
    print_id_list("Affected relationships", report.affected_relationship_ids());
    std::cout << "Evidence: " << report.evidence() << "\n";

    engine->runtime.shutdown();
    return 0;
}

int AnalysisCommand::root_cause(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'analysis root-cause' requires a symptom object ID\n";
        std::cerr << "Usage: oep analysis root-cause <symptom-object-id> [--repository <path>]\n";
        return 1;
    }
    const std::string symptom_object_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedReasoningEngine> engine = open_and_ready_for_analysis(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::RootCauseReport report = engine->reasoning.analyze_root_cause(symptom_object_id);
    std::cout << "Symptom object: " << report.symptom_object_id() << "\n";
    print_id_list("Candidate root causes", report.candidate_root_causes());
    print_id_list("Failure chain", report.failure_chain());
    std::cout << "Evidence: " << report.evidence() << "\n";
    if (report.candidate_root_causes().empty()) {
        std::cout << "Note: no candidate root causes were found against this invocation's EMPTY, process-local "
                     "Rule Registry (see analysis_command.hpp) -- register rules via the Public C API in a "
                     "longer-lived process for a meaningful result.\n";
    }

    engine->runtime.shutdown();
    return 0;
}

int AnalysisCommand::reachability(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.size() < 2) {
        std::cerr << "oep: 'analysis reachability' requires a source object ID and a target object ID\n";
        std::cerr << "Usage: oep analysis reachability <source-id> <target-id> [--repository <path>]\n";
        return 1;
    }
    const std::string source_id = remaining[0];
    const std::string target_id = remaining[1];
    remaining.erase(remaining.begin(), remaining.begin() + 2);
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedReasoningEngine> engine = open_and_ready_for_analysis(repository_path);
    if (engine == nullptr) return 1;

    const oep::engine::ReachabilityReport report = engine->reasoning.analyze_reachability(source_id, target_id);
    std::cout << "Source: " << report.source_object_id() << "\n";
    std::cout << "Target: " << report.target_object_id() << "\n";
    std::cout << "Reachable: " << (report.reachable() ? "yes" : "no") << "\n";
    print_id_list("Path", report.path());
    std::cout << "Evidence: " << report.evidence() << "\n";

    engine->runtime.shutdown();
    return report.reachable() ? 0 : 1;
}

} // namespace oep::cli::commands
