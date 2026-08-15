#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes EngineeringIntelligencePlatform's Workflow Engine
// (WP-EKE-007) as `oep workflow <inspect|query|validate|analyze|reason|
// recommend> --target <id> [args...] [--repository <path>]`.
//
// This is the PRIMARY single-invocation entry point for this work
// package's session-scoped surface: since KnowledgeSessions are
// process-local (see intelligence_common.hpp), a bare `oep session
// create` followed by a separate `oep workflow ...` invocation could
// never share a session_id. `oep workflow` therefore creates its own
// session internally, runs exactly one workflow against it, prints the
// WorkflowResult, and exits -- mirroring `oep rules register
// --evaluate`'s single-invocation convenience precedent and `oep
// reasoning execute`'s own "create-session + execute in one call"
// design. `oep session create/list/close` (session_command.hpp) exist
// for completeness/scripting and for a longer-lived process (e.g. the
// Public C API embedded in Studio) that wants create/resume/clone/
// close/switch across multiple calls.
//
// Subcommand argument shapes:
//   inspect   --target <id> [--type object|package|context]
//   query     --target <id> [--category <category>] (default category: Object)
//   validate  --target <id> [--profile <profile>] (default profile: Structural)
//   analyze   --target <id>
//   reason    --objective <text> <object-id> [<object-id> ...]
//   recommend --target <id>
class WorkflowCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep workflow <inspect|query|validate|analyze|reason|recommend> [--target <id>] "
               "[--type <kind>] [--category <category>] [--profile <profile>] [--objective <text>] "
               "[<object-id> ...] [--repository <path>]";
    }

private:
    int run(const std::string& subcommand, const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
