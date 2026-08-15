#pragma once

#include <memory>
#include <string>
#include <vector>

#include "oep/cli/command.hpp"

namespace oep::cli {

// Holds the set of commands supported by the CLI and routes
// invocations by name.
class CommandRegistry {
public:
    void register_command(std::unique_ptr<Command> command);

    const Command* find(const std::string& name) const;
    const std::vector<std::unique_ptr<Command>>& commands() const;

private:
    std::vector<std::unique_ptr<Command>> commands_;
};

} // namespace oep::cli
