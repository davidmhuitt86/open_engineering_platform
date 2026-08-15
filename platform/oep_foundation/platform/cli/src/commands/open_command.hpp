#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Opens a repository through the Foundation Runtime, per
// OEP-SPEC-012-CLI_COMMAND_FRAMEWORK, and reports the result.
class OpenCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep open <repository>"; }
};

} // namespace oep::cli::commands
