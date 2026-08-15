#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Reconstructs a repository from a previously exported archive
// through the Foundation Runtime, per
// OEP-SPEC-018-REPOSITORY_IMPORT.
class ImportCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep import <archive-file> [--destination <path>] [--overwrite]"; }
};

} // namespace oep::cli::commands
