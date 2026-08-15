#include "import_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string ImportCommand::name() const {
    return "import";
}

std::string ImportCommand::description() const {
    return "Reconstruct a repository from an exported archive";
}

int ImportCommand::execute(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path destination = extract_path_option(remaining, "--destination");
    const bool overwrite = extract_flag(remaining, "--overwrite");

    if (remaining.empty()) {
        std::cerr << "oep: 'import' requires an archive file\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }
    const std::filesystem::path archive_file = remaining[0];

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeImportResult result = runtime.import_repository(archive_file, destination, overwrite);
    if (!result.success) {
        std::cerr << "oep: import failed: " << result.error << "\n";
        runtime.shutdown();
        return 1;
    }

    std::cout << "Imported repository to '" << destination.string() << "'\n";
    std::cout << "  Objects:       " << result.manifest.object_count << "\n";
    std::cout << "  Relationships: " << result.manifest.relationship_count << "\n";
    std::cout << "  Packages:      " << result.manifest.package_count << "\n";

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
