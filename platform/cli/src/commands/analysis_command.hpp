#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes oep::engine::AnalysisEngine (part of WP-EKE-006's Engineering
// Analysis & Reasoning Engine) as `oep analysis <subcommand>`. Mirrors
// `oep evalidate`'s structure (see evalidate_command.hpp), but every
// subcommand here is self-sufficient and needs no session: each opens
// the repository, builds the Knowledge Graph, runs exactly one
// deterministic graph algorithm (dependencies/impact/reachability/
// root-cause), prints the result, and exits -- matching this work
// package's own split between the (stateless) Analysis Engine and the
// (session-based) Reasoning Engine, the latter exposed separately as
// `oep reasoning` (see reasoning_command.hpp).
//
// `oep analysis root-cause` routes through
// ReasoningEngine::analyze_root_cause(symptom_object_id) (the overload
// that runs its own Complete-profile validation internally against a
// FRESH, EMPTY Rule Registry constructed for this invocation) --
// exactly the same "empty registry" honesty limitation `oep evalidate`
// already documents: with zero rules registered, no object ever has an
// outstanding finding, so `candidate_root_causes` is always empty
// unless rules were registered via the Public C API in a longer-lived
// process.
class AnalysisCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep analysis <dependencies|impact|root-cause|reachability> <object-id> [<target-id>] "
               "[--repository <path>]";
    }

private:
    int dependencies(const std::vector<std::string>& args) const;
    int impact(const std::vector<std::string>& args) const;
    int root_cause(const std::vector<std::string>& args) const;
    int reachability(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
