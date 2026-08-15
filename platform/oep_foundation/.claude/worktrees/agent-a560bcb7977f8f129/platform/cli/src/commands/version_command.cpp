#include "version_command.hpp"

#include <iostream>

#include "foundation_version.hpp"

namespace oep::cli::commands {

std::string VersionCommand::name() const {
    return "version";
}

std::string VersionCommand::description() const {
    return "Display the OEP CLI version";
}

int VersionCommand::execute(const std::vector<std::string>& /*args*/) const {
    std::cout << "oep version " << kFoundationVersion << "\n";
    return 0;
}

} // namespace oep::cli::commands
