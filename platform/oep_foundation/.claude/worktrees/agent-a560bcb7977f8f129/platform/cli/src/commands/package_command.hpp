#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Installs and queries .oep packages through the Foundation Runtime, per
// WP-REP-001 (install/list) and WP-REP-002 (Repository Registry &
// Lifecycle: info/contents/verify/locate/search). Named `package`
// (singular) to stay clearly distinct from the existing, unrelated
// `packages` command (`PackagesCommand`), which lists OEP-SPEC-010 local
// extension packages discovered under a repository's own `packages/`
// directory — a different manifest schema and a different concept; see
// OEP-ARCH-002 §0.
//
// Renamed from PackageInstallCommand in WP-REP-002, since install is now
// one of seven subcommands rather than the command's whole purpose. The
// user-facing command name (`oep package ...`) is unchanged.
class PackageCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep package <install <archive.oep>|uninstall <package-id>|list|info <package-id>|"
               "contents <package-id>|verify <package-id>|locate <entity-id>|search <query>> "
               "[--repository <path>]";
    }

private:
    int install(const std::vector<std::string>& args) const;
    int uninstall(const std::vector<std::string>& args) const;
    int list(const std::vector<std::string>& args) const;
    int info(const std::vector<std::string>& args) const;
    int contents(const std::vector<std::string>& args) const;
    int verify(const std::vector<std::string>& args) const;
    int locate(const std::vector<std::string>& args) const;
    int search(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
