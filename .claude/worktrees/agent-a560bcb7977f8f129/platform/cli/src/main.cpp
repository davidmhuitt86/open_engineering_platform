#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "oep/cli/command_registry.hpp"
#include "commands/batch_command.hpp"
#include "commands/export_command.hpp"
#include "commands/graph_command.hpp"
#include "commands/help_command.hpp"
#include "commands/import_command.hpp"
#include "commands/init_command.hpp"
#include "commands/object_command.hpp"
#include "commands/open_command.hpp"
#include "commands/package_command.hpp"
#include "commands/packages_command.hpp"
#include "commands/relationship_command.hpp"
#include "commands/search_command.hpp"
#include "commands/status_command.hpp"
#include "commands/template_command.hpp"
#include "commands/transaction_command.hpp"
#include "commands/trust_command.hpp"
#include "commands/validate_command.hpp"
#include "commands/version_command.hpp"

int main(int argc, char** argv) {
    oep::cli::CommandRegistry registry;
    registry.register_command(std::make_unique<oep::cli::commands::VersionCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::InitCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::OpenCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::ValidateCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::PackagesCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::PackageCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::StatusCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::ObjectCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::RelationshipCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::SearchCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::GraphCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::ExportCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::ImportCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::TemplateCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::BatchCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::TransactionCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::TrustCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::HelpCommand>(registry));

    std::vector<std::string> args(argv + 1, argv + argc);

    if (args.empty() || args[0] == "--help" || args[0] == "-h") {
        return registry.find("help")->execute({});
    }

    const std::string& command_name = args[0];
    const oep::cli::Command* command = registry.find(command_name);

    if (command == nullptr) {
        std::cerr << "oep: unknown command '" << command_name << "'\n";
        std::cerr << "Run 'oep --help' for a list of available commands.\n";
        return 1;
    }

    return command->execute(std::vector<std::string>(args.begin() + 1, args.end()));
}
