#include "status_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"

namespace oep::cli::commands {

std::string StatusCommand::name() const {
    return "status";
}

std::string StatusCommand::description() const {
    return "Display Foundation Runtime status and repository information";
}

int StatusCommand::execute(const std::vector<std::string>& args) const {
    const std::filesystem::path repository_path =
        args.empty() ? std::filesystem::current_path() : std::filesystem::path(args[0]);

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(repository_path);

    std::cout << "Foundation version: " << kFoundationVersion << "\n";
    std::cout << "Runtime state: " << oep::runtime::to_string(runtime.state()) << "\n";

    if (!opened.success) {
        std::cout << "Repository: none (" << opened.error << ")\n";
        runtime.shutdown();
        return 0;
    }

    const oep::runtime::RuntimeMetadataResult metadata = runtime.current_metadata();
    std::cout << "Repository: " << repository_path.string() << "\n";
    std::cout << "Repository ID: " << metadata.metadata.repository_id << "\n";

    const oep::runtime::RuntimePackageSetResult packages = runtime.current_package_set();
    std::size_t loaded_count = 0;
    if (packages.success) {
        for (const oep::packages::DiscoveredPackage& package : packages.packages) {
            if (package.state == oep::packages::PackageState::Loaded) {
                ++loaded_count;
            }
        }
    }
    std::cout << "Loaded packages: " << loaded_count << "\n";

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
