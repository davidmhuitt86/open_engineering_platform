#include "inspect_command.hpp"

#include <filesystem>
#include <iostream>
#include <memory>

#include "intelligence_common.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

namespace {

// Pulls `--type <object|package|context>` out of `args`, defaulting to
// Object when absent.
oep::engine::InspectionTargetKind extract_target_kind(std::vector<std::string>& args) {
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

std::string InspectCommand::name() const {
    return "inspect";
}

std::string InspectCommand::description() const {
    return "Run the Engineering Intelligence Platform's Service Orchestrator inspect (WP-EKE-007) over an object, "
           "package, or the whole context";
}

int InspectCommand::execute(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const oep::engine::InspectionTargetKind kind = extract_target_kind(remaining);

    if (kind != oep::engine::InspectionTargetKind::Context && remaining.empty()) {
        std::cerr << "oep: 'inspect' requires a target ID unless --type context is used\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::string target_id = remaining.empty() ? "" : remaining.front();
    if (!remaining.empty()) remaining.erase(remaining.begin());
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedIntelligencePlatform> platform = open_and_ready_intelligence_platform(repository_path);
    if (platform == nullptr) return 1;

    oep::engine::InspectionReport report =
        kind == oep::engine::InspectionTargetKind::Object    ? platform->eip.inspect_object(target_id)
        : kind == oep::engine::InspectionTargetKind::Package ? platform->eip.inspect_package(target_id)
                                                               : platform->eip.inspect_context();

    std::cout << "Target kind: " << oep::engine::to_string(report.kind()) << "\n";
    if (!report.target_id().empty()) std::cout << "Target: " << report.target_id() << "\n";
    print_id_list("Object IDs", report.object_ids());
    std::cout << "Validation pass count: " << report.validation_pass_count() << "\n";
    std::cout << "Validation finding count: " << report.validation_finding_count() << "\n";
    std::cout << "Summary: " << report.summary() << "\n";

    platform->runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
