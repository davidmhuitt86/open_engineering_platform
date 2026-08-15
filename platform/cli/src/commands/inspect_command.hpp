#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes EngineeringIntelligencePlatform's stateless Service
// Orchestrator inspect_object/inspect_package/inspect_context
// (WP-EKE-007) as `oep inspect <target-id> [--type object|package|context]`.
// No `--type` defaults to `object`; `context` ignores <target-id>
// (pass any placeholder, e.g. "-", or omit and rely on the default
// empty string). Unlike `oep session`/`oep reasoning`, this is a
// SELF-SUFFICIENT single-invocation command: inspect_object/
// inspect_package/inspect_context need no session at all (see
// engineering_intelligence_platform.hpp's Service Orchestrator
// section), so `oep inspect` builds the graph and returns a result in
// one call, exactly like `oep analysis dependencies` etc. Checks the
// name "inspect" for collisions with existing top-level commands
// before registering: no such collision exists (see main.cpp's
// registered command list).
class InspectCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep inspect [<target-id>] [--type object|package|context] [--repository <path>]";
    }
};

} // namespace oep::cli::commands
