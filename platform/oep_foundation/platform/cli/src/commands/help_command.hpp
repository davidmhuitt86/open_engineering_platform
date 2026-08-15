#pragma once

#include "oep/cli/command.hpp"
#include "oep/cli/command_registry.hpp"

namespace oep::cli::commands {

// Prints usage information, including every command registered
// in the CommandRegistry it was constructed with.
class HelpCommand final : public Command {
public:
    explicit HelpCommand(const CommandRegistry& registry);

    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;

private:
    const CommandRegistry& registry_;
};

} // namespace oep::cli::commands
