#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes the Engineering Validation Engine (EVE, WP-EKE-005) -- built
// on EngineeringContext (WP-EKE-001), the Knowledge Graph Engine
// (WP-EKE-002), the Engineering Query Engine (WP-EKE-003), and the
// Engineering Rules Engine (WP-EKE-004) -- as `oep evalidate
// <subcommand>`. New top-level command group, mirroring `oep rules`'s
// structure (see rules_command.hpp).
//
// Naming note: the work package's own examples spell this `oep
// validate <subcommand>`, but `oep validate [repository]` already
// exists in this CLI (validate_command.hpp) as a wholly unrelated,
// long-standing command -- Repository Validation via
// FoundationRuntime::validator(), a positional-repository-path
// command with no subcommands of its own. Reusing that name here would
// either silently shadow existing behavior or require breaking it;
// per this project's constitution ("Never break a working build to
// begin another feature"), this group is named `evalidate` (Engineering
// VALIDATE) instead. Every subcommand name below (`object`, `package`,
// `context`, `report`, `profiles`) otherwise matches the work
// package's naming exactly.
//
// Process-local, no persistence -- exactly like `oep rules` (see that
// file's header doc comment): every subcommand below opens the
// repository, constructs a fresh RulesEngine (an EMPTY Rule Registry)
// and a fresh ValidationEngine over it, performs its own operation,
// then exits. Because no rule survives past the invocation that
// registered it, `object`/`package`/`context` always validate against
// zero rules (every profile reports rules_evaluated == 0, pass_count ==
// 0, and thus a trivial "pass"), and `report` can never find a
// session_id created by an earlier `oep evalidate` invocation --
// sessions are held in ValidationEngine's in-memory registry
// (WP-EKE-005), which is exactly as process-local as WP-EKE-004's rule
// registry. A caller wanting meaningful CLI validation against a real
// rule set must register those rules first via the Public C API
// (oep_rules_register) in a long-lived process that also drives
// oep_validation_*, or await a future rule-loading/persistence
// mechanism -- the same honest limitation `oep rules` already
// documents, not a new one invented here.
class EValidateCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep evalidate <profiles|object|package|context|report> [args...] [--profile <name>] "
               "[--repository <path>]";
    }

private:
    int profiles(const std::vector<std::string>& args) const;
    int object(const std::vector<std::string>& args) const;
    int package(const std::vector<std::string>& args) const;
    int context(const std::vector<std::string>& args) const;
    int report(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
