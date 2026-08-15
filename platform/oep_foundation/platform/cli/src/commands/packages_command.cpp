#include "packages_command.hpp"

#include <filesystem>
#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"

namespace oep::cli::commands {

std::string PackagesCommand::name() const {
    return "packages";
}

std::string PackagesCommand::description() const {
    return "List discovered packages and their state";
}

int PackagesCommand::execute(const std::vector<std::string>& args) const {
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

    const oep::runtime::RuntimePackageSetResult packages = runtime.current_package_set();
    if (!packages.success) {
        std::cerr << "oep: could not list packages: " << packages.error << "\n";
        runtime.shutdown();
        return 1;
    }

    if (packages.packages.empty()) {
        std::cout << "No packages discovered.\n";
    } else {
        for (const oep::packages::DiscoveredPackage& package : packages.packages) {
            std::cout << package.directory_name << "\t" << oep::packages::to_string(package.state);
            if (package.state == oep::packages::PackageState::Loaded) {
                std::cout << "\t" << package.manifest.package_name;
            } else if (!package.message.empty()) {
                std::cout << "\t" << package.message;
            }
            std::cout << "\n";
        }
    }

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
