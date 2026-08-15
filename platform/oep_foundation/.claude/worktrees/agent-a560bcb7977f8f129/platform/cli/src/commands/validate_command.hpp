#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Executes Repository Validation through the Foundation Runtime and
// reports repository health, per OEP-SPEC-012-CLI_COMMAND_FRAMEWORK.
class ValidateCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep validate [repository]"; }
};

} // namespace oep::cli::commands
