#include "oep/cli/command_registry.hpp"

namespace oep::cli {

void CommandRegistry::register_command(std::unique_ptr<Command> command) {
    commands_.push_back(std::move(command));
}

const Command* CommandRegistry::find(const std::string& name) const {
    for (const auto& command : commands_) {
        if (command->name() == name) {
            return command.get();
        }
    }
    return nullptr;
}

const std::vector<std::unique_ptr<Command>>& CommandRegistry::commands() const {
    return commands_;
}

} // namespace oep::cli
