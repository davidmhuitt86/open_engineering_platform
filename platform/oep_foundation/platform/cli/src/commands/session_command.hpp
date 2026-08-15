#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes EngineeringIntelligencePlatform's Knowledge Session Manager
// (WP-EKE-007) as `oep session <subcommand>`: create, list, close.
//
// Process-local, no persistence -- exactly like every prior EKE
// session registry exposed at the CLI (`oep evalidate`, `oep
// reasoning`; see intelligence_common.hpp). A session created by ONE
// `oep session create` invocation can therefore NEVER be found by a
// later, separate `oep session list`/`close` invocation -- each
// constructs a fresh, empty EngineeringIntelligencePlatform. `oep
// session` subcommands exist for completeness/scripting and for
// combining with `oep workflow` in the SAME invocation (not supported
// today -- `oep workflow` creates and manages its own session
// internally, see workflow_command.hpp) -- the primary way to actually
// exercise a session-scoped workflow in one invocation is `oep
// workflow`. A longer-lived process (e.g. the Public C API embedded in
// Studio) is where `oep session`'s create/resume/clone/close/switch
// surface earns its keep across multiple calls.
class SessionCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep session <create|list|close> [args...] [--repository <path>]"; }

private:
    int create(const std::vector<std::string>& args) const;
    int list(const std::vector<std::string>& args) const;
    int close(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
