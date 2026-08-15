#include "init_command.hpp"

#include <filesystem>
#include <iostream>

#include "generator/repository_generator.hpp"

namespace oep::cli::commands {

std::string InitCommand::name() const {
    return "init";
}

std::string InitCommand::description() const {
    return "Create a new OEP repository";
}

int InitCommand::execute(const std::vector<std::string>& args) const {
    if (args.empty()) {
        std::cerr << "oep: 'init' requires a repository name\n";
        std::cerr << "Usage: oep init <repository-name>\n";
        return 1;
    }

    const std::string& repository_name = args[0];
    const std::filesystem::path destination = std::filesystem::current_path() / repository_name;

    const generator::GenerationResult result =
        generator::generate_foundation_repository(destination, repository_name);

    if (!result.success) {
        std::cerr << "oep: init failed: " << result.message << "\n";
        return 1;
    }

    std::cout << result.message << "\n";
    return 0;
}

} // namespace oep::cli::commands
