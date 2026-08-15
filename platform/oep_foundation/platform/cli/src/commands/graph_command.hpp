#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes the Repository Graph Engine through the Foundation Runtime,
// per OEP-SPEC-016-GRAPH_COMMANDS. The CLI never implements traversal
// logic itself; every subcommand is a thin layer over `GraphEngine`.
class GraphCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep graph <neighbors|traverse|path> <object-id> [<target-object-id>] "
               "[--algorithm bfs|dfs] [--repository <path>]";
    }

private:
    int neighbors(const std::vector<std::string>& args) const;
    int traverse(const std::vector<std::string>& args) const;
    int path(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
