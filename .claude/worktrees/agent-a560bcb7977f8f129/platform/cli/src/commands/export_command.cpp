#include "export_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string ExportCommand::name() const {
    return "export";
}

std::string ExportCommand::description() const {
    return "Export the repository to a single deterministic archive";
}

int ExportCommand::execute(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    const bool include_packages = extract_flag(remaining, "--include-packages");

    if (remaining.empty()) {
        std::cerr << "oep: 'export' requires an output file\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path output_file = remaining[0];

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::runtime::RuntimeExportResult result = runtime.export_repository(output_file, include_packages);
    if (!result.success) {
        std::cerr << "oep: export failed: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Exported repository to '" << output_file.string() << "'\n";
    std::cout << "  Objects:       " << result.manifest.object_count << "\n";
    std::cout << "  Relationships: " << result.manifest.relationship_count << "\n";
    std::cout << "  Packages:      " << result.manifest.package_count << "\n";

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
