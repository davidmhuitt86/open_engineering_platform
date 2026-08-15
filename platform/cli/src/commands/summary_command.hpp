#pragma once

#include "oep/cli/command.hpp"

namespace oep::cli::commands {

// Exposes EngineeringIntelligencePlatform::engineering_summary and
// engineering_health (WP-EKE-007) as `oep summary`. Both are stateless
// Service Orchestrator calls -- no session required -- so, like `oep
// inspect`, this is a single-invocation command: build the graph,
// print both reports, exit. `--health-only` prints only the health
// report (skips the summary report); default prints both, since they
// are cheap and closely related (both run their own Complete-profile
// validation pass internally).
class SummaryCommand final : public Command {
public:
    std::string name() const override;
    std::string description() const override;
    int execute(const std::vector<std::string>& args) const override;
    std::string usage() const override { return "oep summary [--health-only] [--repository <path>]"; }
};

} // namespace oep::cli::commands
