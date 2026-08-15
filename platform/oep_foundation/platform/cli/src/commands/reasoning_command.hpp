#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes oep::engine::ReasoningEngine's session-based surface (WP-EKE-006)
// as `oep reasoning <subcommand>`: execute, report, evidence,
// recommendations. Mirrors `oep evalidate`'s structure (see
// evalidate_command.hpp) -- the stateless four analyses
// (dependencies/impact/root-cause/reachability) live under `oep
// analysis` instead (see analysis_command.hpp), matching this work
// package's own Analysis-Engine/Reasoning-Engine split.
//
// Process-local, no persistence -- exactly like `oep evalidate` (see
// that file's header doc comment): every subcommand opens the
// repository, constructs a fresh ReasoningEngine (over a fresh, EMPTY
// Rule Registry and ValidationEngine) and performs its own operation,
// then exits. `oep reasoning execute` therefore accepts an objective
// plus one or more starting object ids and does everything --
// create-session, execute, print summary/conclusions/recommendations
// -- in ONE invocation, since a session_id can never be resolved by a
// separate CLI invocation (each constructs a fresh, empty
// ReasoningEngine with zero sessions). `report`/`evidence`/
// `recommendations` therefore exist for completeness and single-process
// testing only -- they can never find a session_id created by an
// earlier, separate `oep reasoning` invocation, and will always fail
// with a message explaining this, exactly as `oep evalidate report`
// already documents for ValidationSessions.
//
// `oep recommendations` (the work package's own literal top-level
// spelling) is exposed here as `oep reasoning recommendations` instead
// of a new bare top-level command: every other command group in this
// CLI follows the `oep <noun> <verb>` shape (`oep rules evaluate`,
// `oep evalidate object`, ...), and Recommendations are a direct,
// convenience view of a ReasoningReport that otherwise lives entirely
// under `oep reasoning` -- a standalone top-level `oep recommendations
// <session-id>` would fragment that grouping for no benefit, given
// sessions are process-local and `execute` already prints
// recommendations inline. This is a deliberate scope decision, not an
// oversight.
class ReasoningCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep reasoning <execute|report|evidence|recommendations> [args...] [--objective <text>] "
               "[--repository <path>]";
    }

private:
    int run_execute(const std::vector<std::string>& args) const;
    int report(const std::vector<std::string>& args) const;
    int evidence(const std::vector<std::string>& args) const;
    int recommendations(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
