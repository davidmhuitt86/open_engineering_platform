#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

class VersionCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
};

} // namespace oep::cli::commands
