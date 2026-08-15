#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes the Engineering Rules Engine (WP-EKE-004) -- built on
// EngineeringContext (WP-EKE-001), the Knowledge Graph Engine
// (WP-EKE-002), and the Engineering Query Engine (WP-EKE-003) -- as
// `oep rules <subcommand>`. New top-level command group, mirroring
// `oep engine`'s structure (see engine_command.hpp).
//
// Process-local registry, no persistence: exactly like `oep engine`'s
// Runtime Graph/Knowledge Graph, every subcommand below is
// self-contained -- it opens the repository, constructs a fresh
// RulesEngine (an EMPTY Rule Registry), performs its own operation,
// then exits. `register`, `list`, `enable`, `disable`, `evaluate`, and
// `info` therefore do NOT share state across separate `oep rules ...`
// invocations, the same "process-local, not persisted" limitation this
// CLI already documents for `oep runtime events`. Concretely:
//   - `list`/`enable`/`disable`/`evaluate`/`info` operate against a
//     freshly constructed, always-empty registry, so `enable`/
//     `disable`/`evaluate`/`info` on any rule_id fail with a
//     not-registered error in every invocation, and `list` always
//     reports zero rules -- this is not a bug, it is the documented
//     consequence of no rule-loading/persistence mechanism existing
//     yet (a future work package's job).
//   - `register` is the one subcommand that can do something useful
//     standalone: it constructs and registers a SINGLE-CONDITION rule
//     from CLI flags (a deliberate subset of the full data model --
//     EngineeringRule supports multiple conditions per rule, but a
//     general-purpose multi-condition rule-authoring CLI is out of
//     scope for this work package) and, since registration alone is
//     otherwise unobservable in a single process, an optional
//     `--evaluate` flag additionally builds the Knowledge Graph and
///    evaluates the rule immediately, printing its result -- the one
//     demo/test flow this process model can actually support end to
//     end. Programmatic callers wanting a persistent, always-available
//     rule set should register rules via the Public C API
//     (oep_rules_register) once per long-lived process, or await a
//     future rule-loading mechanism.
class RulesCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override {
        return "oep rules <list|register|enable|disable|evaluate|info> [args...] [--repository <path>]";
    }

private:
    int list(const std::vector<std::string>& args) const;
    int register_rule(const std::vector<std::string>& args) const;
    int enable(const std::vector<std::string>& args) const;
    int disable(const std::vector<std::string>& args) const;
    int evaluate(const std::vector<std::string>& args) const;
    int info(const std::vector<std::string>& args) const;
};

} // namespace oep::cli::commands
