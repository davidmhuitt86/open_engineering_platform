#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Manages this repository's Trust Store (WP-REP-004, PKG-005): locally
// trusted publisher certificates and the repository's signature policy.
// Entirely offline/local — there is no certificate authority or online
// revocation service anywhere in this command.
class TrustCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep trust <trust <publisher-id> --name <name> --key <hex> [--expires <utc>]|"
               "list|revoke <publisher-id>|policy [show|require|allow-unsigned]> [--repository <path>]";
    }

private:
    int trust(const std::vector<std::string>& args) const;
    int list(const std::vector<std::string>& args) const;
    int revoke(const std::vector<std::string>& args) const;
    int policy(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
