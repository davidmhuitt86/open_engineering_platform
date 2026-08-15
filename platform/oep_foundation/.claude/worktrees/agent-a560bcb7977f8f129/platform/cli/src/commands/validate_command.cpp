#include "validate_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"

namespace oep::cli::commands {

std::string ValidateCommand::name() const {
    return "validate";
}

std::string ValidateCommand::description() const {
    return "Validate repository integrity and report health";
}

int ValidateCommand::execute(const std::vector<std::string>& args) const {
    const std::filesystem::path repository_path =
        args.empty() ? std::filesystem::current_path() : std::filesystem::path(args[0]);

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::validation::ValidationReport report = runtime.validator()->validate_repository();

    std::cout << "Repository status: " << oep::validation::to_string(report.status) << "\n";
    std::cout << "Errors: " << report.error_count << "  Warnings: " << report.warning_count
               << "  Information: " << report.information_count << "\n";
    for (const oep::validation::ValidationFinding& finding : report.findings) {
        std::cout << "  [" << oep::validation::to_string(finding.severity) << "] " << finding.category << ": "
                   << finding.message << "\n";
    }

    runtime.shutdown();
    return report.status == oep::validation::RepositoryStatus::Healthy ? 0 : 1;
}

} // namespace oep::cli::commands
