#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Displays Runtime state, current repository, repository ID, loaded
// package count, and Foundation version, per
// OEP-SPEC-012-CLI_COMMAND_FRAMEWORK.
class StatusCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep status [repository]"; }
};

} // namespace oep::cli::commands
