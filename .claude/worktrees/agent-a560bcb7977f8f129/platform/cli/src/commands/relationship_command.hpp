#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Creates, lists, inspects, and deletes Relationships through the
// Foundation Runtime, per OEP-SPEC-014-RELATIONSHIP_COMMANDS. Every
// subcommand accepts an optional `--repository <path>` flag,
// defaulting to the current working directory when omitted.
class RelationshipCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep relationship <create|list|show|delete> [arguments] [--repository <path>]";
    }

private:
    int create(const std::vector<std::string>& args) const;
    int list(const std::vector<std::string>& args) const;
    int show(const std::vector<std::string>& args) const;
    int remove(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
