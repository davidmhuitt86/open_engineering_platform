#include "summary_command.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <memory>

#include "intelligence_common.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string SummaryCommand::name() const {
    return "summary";
}

std::string SummaryCommand::description() const {
    return "Run the Engineering Intelligence Platform's engineering_summary and engineering_health (WP-EKE-007) "
           "against the Knowledge Graph";
}

int SummaryCommand::execute(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);

    bool health_only = false;
    const auto it = std::find(remaining.begin(), remaining.end(), "--health-only");
    if (it != remaining.end()) {
        health_only = true;
        remaining.erase(it);
    }
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedIntelligencePlatform> platform = open_and_ready_intelligence_platform(repository_path);
    if (platform == nullptr) return 1;

    if (!health_only) {
        const oep::engine::EngineeringSummaryReport summary = platform->eip.engineering_summary();
        std::cout << "Objects: " << summary.object_count() << "\n";
        std::cout << "Relationships: " << summary.relationship_count() << "\n";
        std::cout << "Connected components: " << summary.connected_component_count() << "\n";
        std::cout << "Validation passed: " << summary.validation_pass_count() << "\n";
        std::cout << "Validation findings: " << summary.validation_finding_count() << "\n";
        std::cout << "Summary: " << summary.summary() << "\n";
    }

    const oep::engine::EngineeringHealthReport health = platform->eip.engineering_health();
    std::cout << "Health score: " << health.health_score() << "/100\n";
    std::cout << "Passed: " << health.passed() << "\n";
    std::cout << "Failed: " << health.failed() << "\n";
    std::cout << "Warnings: " << health.warnings() << "\n";
    std::cout << "Errors: " << health.errors() << "\n";
    std::cout << "Critical: " << health.critical() << "\n";
    std::cout << "Summary: " << health.summary() << "\n";

    platform->runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
