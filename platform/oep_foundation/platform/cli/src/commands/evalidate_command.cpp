#include "evalidate_command.hpp"

#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>

#include "oep/engine/engineering_context.hpp"
#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/rule_types.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_engine.hpp"
#include "oep/engine/validation_types.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"
#include "oep/runtime/runtime_service.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Mirrors rules_command.cpp's OpenedRulesEngine, plus `validation`
// (oep::engine::ValidationEngine, constructed from `context`/`kge`/
// `eqe`/`rules` -- never from `service`/`runtime` directly, per
// WP-EKE-005's layering requirement). `rules` starts with an EMPTY Rule
// Registry every time -- see evalidate_command.hpp's header doc
// comment.
struct OpenedValidationEngine {
    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext context;
    oep::engine::KnowledgeGraphEngine kge;
    oep::engine::EngineeringQueryEngine eqe;
    oep::engine::RulesEngine rules;
    oep::engine::ValidationEngine validation;

    explicit OpenedValidationEngine(const std::string& foundation_version)
        : runtime(foundation_version), service(oep::runtime::RuntimeContext(runtime, events)), context(service),
          kge(context), eqe(kge), rules(context, kge, eqe), validation(context, kge, eqe, rules) {}
};

std::unique_ptr<OpenedValidationEngine> open_repository(const std::filesystem::path& repository_path) {
    auto engine = std::make_unique<OpenedValidationEngine>(kFoundationVersion);
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
// validation (ValidationEngine::graph_ready() requires BOTH
// EngineeringContext::load_graph() and KnowledgeGraphEngine::build_graph()
// to have already succeeded). Returns nullptr (having already printed a
// descriptive error) on failure.
std::unique_ptr<OpenedValidationEngine> open_and_ready_for_validation(const std::filesystem::path& repository_path) {
    std::unique_ptr<OpenedValidationEngine> engine = open_repository(repository_path);
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

std::optional<oep::engine::ValidationProfile> profile_from_string(const std::string& value) {
    if (value == "Structural") return oep::engine::ValidationProfile::Structural;
    if (value == "Connectivity") return oep::engine::ValidationProfile::Connectivity;
    if (value == "Documentation") return oep::engine::ValidationProfile::Documentation;
    if (value == "Metadata") return oep::engine::ValidationProfile::Metadata;
    if (value == "Complete") return oep::engine::ValidationProfile::Complete;
    return std::nullopt;
}

// Pulls `--profile <name>` out of `args`, defaulting to Complete
// (the "run every enabled rule" profile) when absent. Returns
// nullopt only when `--profile` is given an unrecognized value.
std::optional<oep::engine::ValidationProfile> extract_profile(std::vector<std::string>& args) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--profile" && i + 1 < args.size()) {
            const std::string value = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i), args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            return profile_from_string(value);
        }
    }
    return oep::engine::ValidationProfile::Complete;
}

// Exit-code convention for every validate-and-print subcommand below:
// exit 0 iff the report has zero Error-severity AND zero
// Critical-severity findings (Info/Warning findings do not fail the
// build). This mirrors 'oep rules evaluate'/'oep rules register
// --evaluate' returning 0 only for an unambiguous Passed result.
int print_report_and_exit_code(const oep::engine::ValidationReport& report) {
    std::cout << "Profile-selected rules evaluated: " << report.statistics().rules_evaluated << "\n";
    std::cout << "Pass: " << report.pass_count() << "  Warning: " << report.warning_count()
               << "  Error: " << report.error_count() << "  Critical: " << report.critical_count() << "\n";
    std::cout << "Execution time: " << report.execution_time_ms() << " ms\n";
    std::cout << "Findings (" << report.findings().size() << "):\n";
    if (report.findings().empty()) {
        std::cout << "  (none)\n";
    } else {
        for (const oep::engine::ValidationFinding& finding : report.findings()) {
            std::cout << "  [" << oep::engine::to_string(finding.severity()) << "] " << finding.finding_id() << " ("
                       << finding.rule_id() << ", " << oep::engine::to_string(finding.category()) << "): "
                       << finding.message() << "\n";
            if (!finding.recommendation().empty()) {
                std::cout << "    Recommendation: " << finding.recommendation() << "\n";
            }
        }
    }
    return (report.error_count() == 0 && report.critical_count() == 0) ? 0 : 1;
}

} // namespace

std::string EValidateCommand::name() const {
    return "evalidate";
}

std::string EValidateCommand::description() const {
    return "Run Engineering Validation profiles (WP-EKE-005) against a single object, package, or the whole "
           "Engineering Context: profiles, object, package, context, report";
}

int EValidateCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'evalidate' requires a subcommand (profiles, object, package, context, report)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand == "profiles") return profiles(rest);
    if (subcommand == "object") return object(rest);
    if (subcommand == "package") return package(rest);
    if (subcommand == "context") return context(rest);
    if (subcommand == "report") return report(rest);

    std::cerr << "oep: unknown 'evalidate' subcommand '" << subcommand << "'\n";
    std::cerr << "Usage: " << usage() << "\n";
    return 1;
}

int EValidateCommand::profiles(const std::vector<std::string>& args) const {
    if (!args.empty()) {
        std::cerr << "oep: unrecognized argument '" << args.front() << "'\n";
        return 1;
    }
    // Static data -- no repository needed (see evalidate_command.hpp).
    std::cout << "Validation profiles:\n";
    std::cout << "  " << oep::engine::to_string(oep::engine::ValidationProfile::Structural) << "\n";
    std::cout << "  " << oep::engine::to_string(oep::engine::ValidationProfile::Connectivity) << "\n";
    std::cout << "  " << oep::engine::to_string(oep::engine::ValidationProfile::Documentation) << "\n";
    std::cout << "  " << oep::engine::to_string(oep::engine::ValidationProfile::Metadata) << "\n";
    std::cout << "  " << oep::engine::to_string(oep::engine::ValidationProfile::Complete) << "\n";
    return 0;
}

int EValidateCommand::object(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::optional<oep::engine::ValidationProfile> profile = extract_profile(remaining);

    if (!profile.has_value()) {
        std::cerr << "oep: unrecognized --profile value\n";
        return 1;
    }
    if (remaining.empty()) {
        std::cerr << "oep: 'evalidate object' requires an object ID\n";
        std::cerr << "Usage: oep evalidate object <object-id> [--profile <name>] [--repository <path>]\n";
        return 1;
    }
    const std::string object_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedValidationEngine> engine = open_and_ready_for_validation(repository_path);
    if (engine == nullptr) return 1;

    const std::string session_id = engine->validation.create_validation_session(*profile);
    const std::optional<oep::engine::ValidationReport> validation_report =
        engine->validation.validate_object(session_id, object_id);
    if (!validation_report.has_value()) {
        std::cerr << "oep: internal error -- just-created session not found\n";
        engine->runtime.shutdown();
        return 1;
    }

    const int exit_code = print_report_and_exit_code(*validation_report);
    engine->runtime.shutdown();
    return exit_code;
}

int EValidateCommand::package(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::optional<oep::engine::ValidationProfile> profile = extract_profile(remaining);

    if (!profile.has_value()) {
        std::cerr << "oep: unrecognized --profile value\n";
        return 1;
    }
    if (remaining.empty()) {
        std::cerr << "oep: 'evalidate package' requires a package ID\n";
        std::cerr << "Usage: oep evalidate package <package-id> [--profile <name>] [--repository <path>]\n";
        return 1;
    }
    const std::string package_id = remaining.front();
    remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedValidationEngine> engine = open_and_ready_for_validation(repository_path);
    if (engine == nullptr) return 1;

    const std::string session_id = engine->validation.create_validation_session(*profile);
    const std::optional<oep::engine::ValidationReport> validation_report =
        engine->validation.validate_package(session_id, package_id);
    if (!validation_report.has_value()) {
        std::cerr << "oep: internal error -- just-created session not found\n";
        engine->runtime.shutdown();
        return 1;
    }

    const int exit_code = print_report_and_exit_code(*validation_report);
    engine->runtime.shutdown();
    return exit_code;
}

int EValidateCommand::context(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::optional<oep::engine::ValidationProfile> profile = extract_profile(remaining);

    if (!profile.has_value()) {
        std::cerr << "oep: unrecognized --profile value\n";
        return 1;
    }
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedValidationEngine> engine = open_and_ready_for_validation(repository_path);
    if (engine == nullptr) return 1;

    const std::string session_id = engine->validation.create_validation_session(*profile);
    const std::optional<oep::engine::ValidationReport> validation_report = engine->validation.validate_context(session_id);
    if (!validation_report.has_value()) {
        std::cerr << "oep: internal error -- just-created session not found\n";
        engine->runtime.shutdown();
        return 1;
    }

    const int exit_code = print_report_and_exit_code(*validation_report);
    engine->runtime.shutdown();
    return exit_code;
}

int EValidateCommand::report(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    if (remaining.empty()) {
        std::cerr << "oep: 'evalidate report' requires a session ID\n";
        std::cerr << "Usage: oep evalidate report <session-id> [--repository <path>]\n";
        std::cerr << "Note: ValidationSessions are held in-memory and process-local (see evalidate_command.hpp) -- "
                     "a session_id from an EARLIER 'oep evalidate' invocation can never be found here, because "
                     "each invocation constructs a fresh, empty ValidationEngine. This subcommand can only ever "
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

    const std::unique_ptr<OpenedValidationEngine> engine = open_repository(repository_path);
    if (engine == nullptr) return 1;

    const std::optional<oep::engine::ValidationReport> validation_report = engine->validation.validation_report(session_id);
    if (!validation_report.has_value()) {
        std::cerr << "oep: session_id '" << session_id
                   << "' has no report on this handle (ValidationSessions are process-local and not persisted -- "
                      "create and validate a session first with 'oep evalidate object/package/context' in the "
                      "same invocation)\n";
        engine->runtime.shutdown();
        return 1;
    }

    const int exit_code = print_report_and_exit_code(*validation_report);
    engine->runtime.shutdown();
    return exit_code;
}

} // namespace oep::cli::commands
