#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Inspects the Repository Transaction Engine's journal (WP-REP-003):
// every Repository write executes through a Repository Transaction, and
// every closed transaction leaves one permanent record under the
// repository's `logs/transactions/` directory. This command is read-only
// — transactions themselves are begun/committed by the operations that
// use them (mutations, installs), not from the CLI.
class TransactionCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep transaction <list|show <transaction-id>> [--repository <path>]";
    }

private:
    int list(const std::vector<std::string>& args) const;
    int show(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
