#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Creates a new OEP repository via the Foundation Generator.
class InitCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep init <repository-name>"; }
};

} // namespace oep::cli::commands
