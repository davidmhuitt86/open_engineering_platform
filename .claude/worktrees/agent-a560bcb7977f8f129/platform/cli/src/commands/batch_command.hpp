#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Creates, deletes, and validates batches of Engineering Objects and
// Relationships from a single JSON input file, through the Foundation
// Runtime, per OEP-SPEC-020-BATCH_OPERATIONS.
class BatchCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep batch <create|delete|validate> <input-file> [--repository <path>]";
    }

private:
    int create(const std::vector<std::string>& args) const;
    int remove(const std::vector<std::string>& args) const;
    int validate(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
