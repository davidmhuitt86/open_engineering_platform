#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exports the currently open repository to a single deterministic
// archive through the Foundation Runtime, per
// OEP-SPEC-017-REPOSITORY_EXPORT.
class ExportCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep export <output-file> [--include-packages] [--repository <path>]";
    }
};

} // namespace oep::cli::commands
