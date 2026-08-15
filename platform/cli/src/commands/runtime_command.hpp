#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Reads back the Repository Events log (WP-REP-006) that RuntimeService
// and the CLI's mutating commands (object, relationship, package)
// publish to as they run. See runtime_event_log.hpp for the process-wide
// EventBus this command reads from.
class RuntimeCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep runtime <events> [--limit N] [--repository <path>]";
    }

private:
    int events(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
