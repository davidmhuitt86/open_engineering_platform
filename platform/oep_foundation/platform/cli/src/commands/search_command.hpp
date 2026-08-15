#pragma once

#include "oep/cli/command.hpp"
#include "oep/runtime/foundation_runtime.hpp"

namespace oep::cli::commands {

// Exposes the Repository Search Engine through the Foundation Runtime,
// per OEP-SPEC-015_SEARCH_COMMANDS. `oep search <query>` searches both
// objects and relationships; `oep search objects <query>` / `oep
// search relationships <query>` search just one. Supports `--type`,
// `--author`, `--tag`, and `--repository` filters, applied after
// SearchEngine returns results without reordering them — the CLI
// implements no independent ranking.
class SearchCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep search [objects|relationships] <query> [--type <type>] [--author <author>] "
               "[--tag <tag>] [--repository <path>]";
    }

private:
    int print_object_results(oep::runtime::FoundationRuntime& runtime, const std::string& query,
                              const std::string& type_filter, const std::string& author_filter,
                              const std::string& tag_filter) const;
    int print_relationship_results(oep::runtime::FoundationRuntime& runtime, const std::string& query,
                                    const std::string& type_filter, const std::string& author_filter) const;
};

} // namespace oep::cli::commands
