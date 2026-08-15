#include "reasoning_command.hpp"

#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>

#include "oep/engine/engineering_context.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/reasoning_engine.hpp"
#include "oep/engine/reasoning_types.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_engine.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Mirrors analysis_command.cpp's OpenedReasoningEngine exactly.
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

std::unique_ptr<OpenedReasoningEngine> open_and_ready_for_reasoning(const std::filesystem::path& repository_path) {
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

// Pulls `--objective <text>` out of `args`, defaulting to an empty
// objective when absent (ReasoningEngine::create_reasoning_session
// accepts any string).
std::string extract_objective(std::vector<std::string>& args) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--objective" && i + 1 < args.size()) {
            const std::string value = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i), args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            return value;
        }
    }
    return "";
}

void print_report(const oep::engine::ReasoningReport& report) {
    std::cout << "Session: " << report.session().session_id() << "\n";
    std::cout << "Objective: " << report.session().objective() << "\n";
    std::cout << "Execution time: " << report.execution_time_ms() << " ms\n";
    std::cout << "Conclusions (" << report.session().conclusions().size() << "):\n";
    if (report.session().conclusions().empty()) {
        std::cout << "  (none)\n";
    } else {
        for (const oep::engine::EngineeringConclusion& conclusion : report.session().conclusions()) {
            std::cout << "  [" << conclusion.conclusion_id() << "] (confidence " << conclusion.confidence()
                       << "): " << conclusion.statement() << "\n";
        }
    }
    std::cout << "Recommendations (" << report.recommendations().size() << "):\n";
    if (report.recommendations().empty()) {
        std::cout << "  (none)\n";
    } else {
        for (const oep::engine::EngineeringRecommendation& recommendation : report.recommendations()) {
            std::cout << "  [" << recommendation.recommendation_id() << "] ("
                       << oep::engine::to_string(recommendation.kind()) << ", " << recommendation.object_id()
                       << "): " << recommendation.message() << "\n";
        }
    }
}

} // namespace

std::string ReasoningCommand::name() const {
    return "reasoning";
}

std::string ReasoningCommand::description() const {
    return "Run the Engineering Reasoning Engine (WP-EKE-006) over one or more starting objects: execute, report, "
           "evidence, recommendations";
}

int ReasoningCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'reasoning' requires a subcommand (execute, report, evidence, recommendations)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "execute") return run_execute(rest);
    if (subcommand == "report") return report(rest);
    if (subcommand == "evidence") return evidence(rest);
    if (subcommand == "recommendations") return recommendations(rest);

    std::cerr << "oep: unknown 'reasoning' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int ReasoningCommand::run_execute(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::string objective = extract_objective(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'reasoning execute' requires at least one starting object ID\n";
        std::cerr << "Usage: oep reasoning execute <object-id> [<object-id> ...] [--objective <text>] "
                     "[--repository <path>]\n";
        return 1;
    }
    const std::vector<std::string> starting_objects = remaining;

    const std::unique_ptr<OpenedReasoningEngine> engine = open_and_ready_for_reasoning(repository_path);
    if (engine == nullptr) return 1;

    const std::string session_id = engine->reasoning.create_reasoning_session(objective, starting_objects);
    const std::optional<oep::engine::ReasoningReport> reasoning_report = engine->reasoning.execute_reasoning(session_id);
    if (!reasoning_report.has_value()) {
        std::cerr << "oep: internal error -- just-created session not found\n";
        engine->runtime.shutdown();
        return 1;
    }

    print_report(*reasoning_report);
    engine->runtime.shutdown();
    return 0;
}

int ReasoningCommand::report(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'reasoning report' requires a session ID\n";
        std::cerr << "Usage: oep reasoning report <session-id> [--repository <path>]\n";
        std::cerr << "Note: ReasoningSessions are held in-memory and process-local (see reasoning_command.hpp) -- "
                     "a session_id from an EARLIER 'oep reasoning' invocation can never be found here, because "
                     "each invocation constructs a fresh, empty ReasoningEngine. This subcommand can only ever "
                     "observe a session created earlier in THIS SAME process, which a separate CLI invocation "
                     "can never be; it exists for completeness and single-process testing, not cross-invocation "
                     "lookup.\n";
        return 1;
    }
    const std::string session_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedReasoningEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    const std::optional<oep::engine::ReasoningReport> reasoning_report = engine->reasoning.reasoning_report(session_id);
    if (!reasoning_report.has_value()) {
        std::cerr << "oep: session_id '" << session_id
                   << "' has no report on this handle (ReasoningSessions are process-local and not persisted -- "
                      "create and execute a session first with 'oep reasoning execute' in the same invocation)\n";
        engine->runtime.shutdown();
        return 1;
    }

    print_report(*reasoning_report);
    engine->runtime.shutdown();
    return 0;
}

int ReasoningCommand::evidence(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'reasoning evidence' requires a session ID\n";
        std::cerr << "Usage: oep reasoning evidence <session-id> [<evidence-id>] [--repository <path>]\n";
        std::cerr << "Note: ReasoningSessions are process-local (see reasoning_command.hpp) -- a session_id from "
                     "an earlier, separate invocation can never be found here.\n";
        return 1;
    }
    const std::string session_id = remaining.front();
    remaining.erase(remaining.begin());
    const std::optional<std::string> evidence_id =
        remaining.empty() ? std::nullopt : std::optional<std::string>(remaining.front());
    if (!remaining.empty()) remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedReasoningEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    const std::optional<oep::engine::ReasoningReport> reasoning_report = engine->reasoning.reasoning_report(session_id);
    if (!reasoning_report.has_value()) {
        std::cerr << "oep: session_id '" << session_id
                   << "' has no report on this handle (ReasoningSessions are process-local and not persisted -- "
                      "create and execute a session first with 'oep reasoning execute' in the same invocation)\n";
        engine->runtime.shutdown();
        return 1;
    }

    const oep::engine::EvidenceGraph& graph = reasoning_report->session().evidence();
    if (!evidence_id.has_value()) {
        // No evidence_id given: list the whole Evidence Graph's nodes.
        std::cout << "Evidence nodes (" << graph.nodes().size() << "):\n";
        for (const oep::engine::EvidenceNode& node : graph.nodes()) {
            std::cout << "  [" << node.evidence_id() << "] " << oep::engine::to_string(node.kind()) << " ref="
                       << node.reference_id() << ": " << node.detail() << "\n";
        }
        engine->runtime.shutdown();
        return 0;
    }

    for (const oep::engine::EvidenceNode& node : graph.nodes()) {
        if (node.evidence_id() == *evidence_id) {
            std::cout << "Evidence: " << node.evidence_id() << "\n";
            std::cout << "Kind: " << oep::engine::to_string(node.kind()) << "\n";
            std::cout << "Reference: " << node.reference_id() << "\n";
            std::cout << "Detail: " << node.detail() << "\n";
            engine->runtime.shutdown();
            return 0;
        }
    }
    std::cerr << "oep: evidence_id '" << *evidence_id << "' was not found in this session's Evidence Graph\n";
    engine->runtime.shutdown();
    return 1;
}

int ReasoningCommand::recommendations(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'reasoning recommendations' requires a session ID\n";
        std::cerr << "Usage: oep reasoning recommendations <session-id> [--repository <path>]\n";
        return 1;
    }
    const std::string session_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedReasoningEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    const std::vector<oep::engine::EngineeringRecommendation> recs = engine->reasoning.engineering_recommendations(session_id);
    std::cout << "Recommendations (" << recs.size() << "):\n";
    if (recs.empty()) {
        std::cout << "  (none -- or session_id '" << session_id
                   << "' is not a session executed earlier in this same invocation; ReasoningSessions are "
                      "process-local, see reasoning_command.hpp)\n";
    } else {
        for (const oep::engine::EngineeringRecommendation& recommendation : recs) {
            std::cout << "  [" << recommendation.recommendation_id() << "] ("
                       << oep::engine::to_string(recommendation.kind()) << ", " << recommendation.object_id()
                       << "): " << recommendation.message() << "\n";
        }
    }

    engine->runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
