#include "workflow_command.hpp"

#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>

#include "intelligence_common.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Pulls `--target <id>` out of `args`, defaulting to an empty string
// when absent (some subcommands, e.g. `inspect --type context`, don't
// require one).
std::string extract_target(std::vector<std::string>& args) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--target" && i + 1 < args.size()) {
            const std::string value = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i), args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            return value;
        }
    }
    return "";
}

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

oep::engine::InspectionTargetKind extract_type(std::vector<std::string>& args) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--type" && i + 1 < args.size()) {
            const std::string value = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i), args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            if (value == "package") return oep::engine::InspectionTargetKind::Package;
            if (value == "context") return oep::engine::InspectionTargetKind::Context;
            return oep::engine::InspectionTargetKind::Object;
        }
    }
    return oep::engine::InspectionTargetKind::Object;
}

std::optional<oep::engine::QueryCategory> category_from_string(const std::string& value) {
    if (value == "object") return oep::engine::QueryCategory::Object;
    if (value == "relationship") return oep::engine::QueryCategory::Relationship;
    if (value == "domain") return oep::engine::QueryCategory::Domain;
    if (value == "type") return oep::engine::QueryCategory::Type;
    if (value == "dependency") return oep::engine::QueryCategory::Dependency;
    if (value == "neighborhood") return oep::engine::QueryCategory::Neighborhood;
    if (value == "path") return oep::engine::QueryCategory::Path;
    if (value == "reference") return oep::engine::QueryCategory::Reference;
    if (value == "metadata") return oep::engine::QueryCategory::Metadata;
    if (value == "composite") return oep::engine::QueryCategory::Composite;
    return std::nullopt;
}

oep::engine::QueryCategory extract_category(std::vector<std::string>& args) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--category" && i + 1 < args.size()) {
            const std::string value = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i), args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            const std::optional<oep::engine::QueryCategory> category = category_from_string(value);
            return category.value_or(oep::engine::QueryCategory::Object);
        }
    }
    return oep::engine::QueryCategory::Object;
}

std::optional<oep::engine::ValidationProfile> profile_from_string(const std::string& value) {
    if (value == "Structural") return oep::engine::ValidationProfile::Structural;
    if (value == "Connectivity") return oep::engine::ValidationProfile::Connectivity;
    if (value == "Documentation") return oep::engine::ValidationProfile::Documentation;
    if (value == "Metadata") return oep::engine::ValidationProfile::Metadata;
    if (value == "Complete") return oep::engine::ValidationProfile::Complete;
    return std::nullopt;
}

oep::engine::ValidationProfile extract_profile(std::vector<std::string>& args) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--profile" && i + 1 < args.size()) {
            const std::string value = args[i + 1];
            args.erase(args.begin() + static_cast<std::ptrdiff_t>(i), args.begin() + static_cast<std::ptrdiff_t>(i) + 2);
            const std::optional<oep::engine::ValidationProfile> profile = profile_from_string(value);
            return profile.value_or(oep::engine::ValidationProfile::Structural);
        }
    }
    return oep::engine::ValidationProfile::Structural;
}

void print_result(const oep::engine::WorkflowResult& result) {
    std::cout << "Workflow: " << oep::engine::to_string(result.kind) << "\n";
    std::cout << "Success: " << (result.success ? "yes" : "no") << "\n";
    std::cout << "Execution time: " << result.execution_time_ms << " ms\n";
    std::cout << "Summary: " << result.summary << "\n";
    std::cout << "Object IDs (" << result.object_ids.size() << "):\n";
    if (result.object_ids.empty()) {
        std::cout << "  (none)\n";
    } else {
        for (const std::string& id : result.object_ids) std::cout << "  " << id << "\n";
    }
}

} // namespace

std::string WorkflowCommand::name() const {
    return "workflow";
}

std::string WorkflowCommand::description() const {
    return "Run one Engineering Intelligence Platform Workflow (WP-EKE-007) in a single invocation: inspect, "
           "query, validate, analyze, reason, recommend";
}

int WorkflowCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'workflow' requires a subcommand (inspect, query, validate, analyze, reason, "
                     "recommend)\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    const std::string& subcommand = args[0];
    const std::vector<std::string> rest(args.begin() + 1, args.end());

    if (subcommand != "inspect" && subcommand != "query" && subcommand != "validate" && subcommand != "analyze" &&
        subcommand != "reason" && subcommand != "recommend") {
        std::cerr << "oep: unknown 'workflow' subcommand '" << subcommand << "'\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    return run(subcommand, rest);
}

int WorkflowCommand::run(const std::string& subcommand, const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const std::string target = extract_target(remaining);
    const oep::engine::InspectionTargetKind type = extract_type(remaining);
    const oep::engine::QueryCategory category = extract_category(remaining);
    const oep::engine::ValidationProfile profile = extract_profile(remaining);
    const std::string objective = extract_objective(remaining);

    if (subcommand == "reason") {
        if (remaining.empty()) {
            std::cerr << "oep: 'workflow reason' requires at least one starting object ID\n";
            std::cerr << "Usage: oep workflow reason --objective <text> <object-id> [<object-id> ...] "
                         "[--repository <path>]\n";
            return 1;
        }
    } else {
        if (target.empty() && !(subcommand == "inspect" && type == oep::engine::InspectionTargetKind::Context)) {
            std::cerr << "oep: 'workflow " << subcommand << "' requires --target <id>\n";
            std::cerr << "Usage: " << usage() << "\n";
            return 1;
        }
        if (!remaining.empty()) {
            std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
            return 1;
        }
    }

    const std::unique_ptr<OpenedIntelligencePlatform> platform = open_and_ready_intelligence_platform(repository_path);
    if (platform == nullptr) return 1;

    const std::string session_id = platform->eip.create_session();

    oep::engine::WorkflowResult result;
    if (subcommand == "inspect") {
        result = platform->eip.inspect(session_id, type, target);
    } else if (subcommand == "query") {
        result = platform->eip.query(session_id, category, target);
    } else if (subcommand == "validate") {
        result = platform->eip.validate(session_id, target, profile);
    } else if (subcommand == "analyze") {
        result = platform->eip.analyze(session_id, target);
    } else if (subcommand == "reason") {
        result = platform->eip.reason(session_id, objective, remaining);
    } else {
        result = platform->eip.recommend(session_id, target);
    }

    print_result(result);
    std::cout << "Session: " << session_id << " (process-local -- see workflow_command.hpp)\n";

    platform->runtime.shutdown();
    return result.success ? 0 : 1;
}

} // namespace oep::cli::commands
