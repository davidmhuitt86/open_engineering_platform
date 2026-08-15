#include "metrics_command.hpp"

#include <filesystem>
#include <iostream>
#include <memory>

#include "intelligence_common.hpp"
#include "repository_path_option.hpp"

namespace oep::cli::commands {

std::string MetricsCommand::name() const {
    return "metrics";
}

std::string MetricsCommand::description() const {
    return "Print the Engineering Intelligence Platform's Runtime Metrics (WP-EKE-007)";
}

int MetricsCommand::execute(const std::vector<std::string>& args) const {
    std::vector<std::string> remaining = args;
    const std::filesystem::path repository_path = extract_repository_path(remaining);
    if (!remaining.empty()) {
        std::cerr << "oep: unrecognized argument '" << remaining.front() << "'\n";
        return 1;
    }

    const std::unique_ptr<OpenedIntelligencePlatform> platform = open_intelligence_platform(repository_path);
    if (platform == nullptr) return 1;

    const oep::engine::RuntimeMetrics metrics = platform->eip.runtime_metrics();
    std::cout << "Query count: " << metrics.query_count << "\n";
    std::cout << "Validation count: " << metrics.validation_count << "\n";
    std::cout << "Analysis count: " << metrics.analysis_count << "\n";
    std::cout << "Reasoning count: " << metrics.reasoning_count << "\n";
    std::cout << "Cache hits: " << metrics.cache_hits << "\n";
    std::cout << "Cache misses: " << metrics.cache_misses << "\n";
    std::cout << "Active sessions: " << metrics.active_session_count << "\n";
    std::cout << "Total sessions: " << metrics.total_session_count << "\n";
    std::cout << "Total execution time: " << metrics.total_execution_time_ms << " ms\n";
    std::cout << "Note: this is a fresh, process-local invocation -- see metrics_command.hpp -- so all counters "
                 "above reflect only THIS invocation's own (zero) prior activity.\n";

    platform->runtime.shutdown();
    return 0;
}

} // namespace oep::cli::commands
