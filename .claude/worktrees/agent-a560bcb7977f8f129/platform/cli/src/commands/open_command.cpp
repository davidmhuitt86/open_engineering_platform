#include "open_command.hpp"

#include <iostream>

#include "oep/runtime/foundation_runtime.hpp"
#include "foundation_version.hpp"

namespace oep::cli::commands {

std::string OpenCommand::name() const {
    return "open";
}

std::string OpenCommand::description() const {
    return "Open a repository through the Foundation Runtime";
}

int OpenCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'open' requires a repository path\n";
        std::cerr << "Usage: " << usage() << "\n";
        return 1;
    }

    oep::runtime::FoundationRuntime runtime(kFoundationVersion);
    runtime.initialize();

    const oep::runtime::RuntimeResult opened = runtime.open_repository(args[0]);
    if (!opened.success) {
        std::cerr << "oep: could not open repository: " << opened.error << "\n";
        runtime.shutdown();
        return 1;
    }

    const oep::runtime::RuntimeMetadataResult metadata = runtime.current_metadata();
    std::cout << "Opened repository '" << metadata.metadata.repository_name << "' at " << args[0] << "\n";

    runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
