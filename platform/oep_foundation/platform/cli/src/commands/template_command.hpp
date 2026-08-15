#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Creates, lists, and instantiates Repository Templates through the
// Foundation Runtime, per OEP-SPEC-019-REPOSITORY_TEMPLATES. Every
// subcommand accepts an optional `--templates-dir <path>` flag,
// defaulting to the current working directory when omitted.
class TemplateCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep template <create|list|instantiate> [arguments] [--templates-dir <path>]";
    }

private:
    int create(const std::vector<std::string>& args) const;
    int list(const std::vector<std::string>& args) const;
    int instantiate(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
