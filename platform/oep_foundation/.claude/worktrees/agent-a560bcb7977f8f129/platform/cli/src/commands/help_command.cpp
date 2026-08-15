#include "help_command.hpp"

#include <iostream>

namespace oep::cli::commands {

HelpCommand::HelpCommand(const CommandRegistry& registry) : registry_(registry) {}

std::string HelpCommand::name() const {
    return "help";
}

std::string HelpCommand::description() const {
    return "Display available commands";
}

int HelpCommand::execute(const std::vector<std::string>& /*args*/) const {
    std::cout << "OEP CLI\n\n";
    std::cout << "Usage:\n";
    std::cout << "  oep <command>\n\n";
    std::cout << "Commands:\n";
    for (const auto& command : registry_.commands()) {
        std::cout << "  " << command->name() << "\n";
        std::cout << "      Syntax:      " << command->usage() << "\n";
        std::cout << "      Description: " << command->description() << "\n";
    }
    return 0;
}

} // namespace oep::cli::commands
