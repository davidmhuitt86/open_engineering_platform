#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Lists every discovered package and its current state, through the
// Foundation Runtime, per OEP-SPEC-012-CLI_COMMAND_FRAMEWORK.
class PackagesCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep packages [repository]"; }
};

} // namespace oep::cli::commands
