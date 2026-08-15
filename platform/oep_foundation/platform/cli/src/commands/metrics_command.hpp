#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes EngineeringIntelligencePlatform::runtime_metrics
// (WP-EKE-007) as `oep metrics`. Since metrics are process-local and
// runtime-only (see intelligence_types.hpp's RuntimeMetrics doc
// comment -- "never persisted, a fresh EngineeringIntelligencePlatform
// always starts at zero"), a bare `oep metrics` invocation always
// prints all-zero counters -- nothing was dispatched through this
// SAME process's platform before this call ran. This is documented
// rather than hidden: the command still exercises the real
// runtime_metrics() call and its live cache_hits introspection against
// the Query Engine, useful for scripting/smoke-testing the Public C
// API surface (oep_eip_runtime_metrics), even though a single CLI
// invocation can never show nonzero counts on its own.
class MetricsCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep metrics [--repository <path>]"; }
};

} // namespace oep::cli::commands
