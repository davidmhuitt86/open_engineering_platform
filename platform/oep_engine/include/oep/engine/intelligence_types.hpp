#pragma once

#include <cstddef>
#include <string>
#include <vector>

namespace oep::engine {

// WP-EKE-007's Runtime Metrics: runtime-only counters, never persisted
// (a fresh EngineeringIntelligencePlatform always starts at zero).
// Incremented by the platform itself as it dispatches calls into the
// lower engines -- this is the ONLY place in platform/oep_engine that
// counts engine invocations across the whole stack.
struct RuntimeMetrics {
    std::size_t query_count = 0;
    std::size_t validation_count = 0;
    std::size_t analysis_count = 0;
    std::size_t reasoning_count = 0;
    std::size_t cache_hits = 0;   // WP-EKE-003 QueryCache hits observed via query_statistics/cache introspection
    std::size_t cache_misses = 0;
    std::size_t active_session_count = 0;
    std::size_t total_session_count = 0; // ever created, including closed ones
    double total_execution_time_ms = 0.0;
};

// WP-EKE-007's per-session Statistics (distinct from RuntimeMetrics,
// which is platform-wide): what THIS session alone has done.
struct SessionStatistics {
    std::size_t query_count = 0;
    std::size_t validation_count = 0;
    std::size_t analysis_count = 0;
    std::size_t reasoning_count = 0;
    double total_execution_time_ms = 0.0;
};

// WP-EKE-007's immutable KnowledgeSession: Session ID, EngineeringContext
// (see the note below), Query History, Validation History, Analysis
// History, Reasoning History, Recommendations, Active Objects, Active
// Packages, Runtime Statistics -- exactly the fields the work package
// names. Histories are short, human-readable descriptions of what ran
// (mirroring WP-EKE-006's ReasoningSession convention for
// queries_executed/rules_applied/validation_results), not full nested
// reports -- those remain in whichever lower engine actually computed
// them (Query/Validation/Analysis/Reasoning Engine), reachable via the
// ids those descriptions name.
//
// NOTE on "EngineeringContext": this platform (like every engine below
// it) operates against exactly ONE EngineeringContext per runtime
// handle -- there is no multi-repository/multi-context architecture in
// this or any prior work package. A KnowledgeSession therefore does
// NOT own a separate EngineeringContext instance; it is a logical
// grouping of history/active-object/active-package state layered over
// the single shared EngineeringContext every session in this process
// ultimately reads through. This is documented explicitly rather than
// silently implied, since the work package's field list names
// "EngineeringContext" as if each session had its own.
class KnowledgeSession {
public:
    KnowledgeSession(std::string session_id, std::string created_utc, std::string last_active_utc, bool closed,
                      std::vector<std::string> query_history, std::vector<std::string> validation_history,
                      std::vector<std::string> analysis_history, std::vector<std::string> reasoning_history,
                      std::vector<std::string> recommendations, std::vector<std::string> active_objects,
                      std::vector<std::string> active_packages, SessionStatistics statistics)
        : session_id_(std::move(session_id)),
          created_utc_(std::move(created_utc)),
          last_active_utc_(std::move(last_active_utc)),
          closed_(closed),
          query_history_(std::move(query_history)),
          validation_history_(std::move(validation_history)),
          analysis_history_(std::move(analysis_history)),
          reasoning_history_(std::move(reasoning_history)),
          recommendations_(std::move(recommendations)),
          active_objects_(std::move(active_objects)),
          active_packages_(std::move(active_packages)),
          statistics_(std::move(statistics)) {}

    const std::string& session_id() const { return session_id_; }
    const std::string& created_utc() const { return created_utc_; }
    const std::string& last_active_utc() const { return last_active_utc_; }
    bool closed() const { return closed_; }
    const std::vector<std::string>& query_history() const { return query_history_; }
    const std::vector<std::string>& validation_history() const { return validation_history_; }
    const std::vector<std::string>& analysis_history() const { return analysis_history_; }
    const std::vector<std::string>& reasoning_history() const { return reasoning_history_; }
    const std::vector<std::string>& recommendations() const { return recommendations_; }
    const std::vector<std::string>& active_objects() const { return active_objects_; }
    const std::vector<std::string>& active_packages() const { return active_packages_; }
    const SessionStatistics& statistics() const { return statistics_; }

private:
    std::string session_id_;
    std::string created_utc_;
    std::string last_active_utc_;
    bool closed_;
    std::vector<std::string> query_history_;
    std::vector<std::string> validation_history_;
    std::vector<std::string> analysis_history_;
    std::vector<std::string> reasoning_history_;
    std::vector<std::string> recommendations_;
    std::vector<std::string> active_objects_;
    std::vector<std::string> active_packages_;
    SessionStatistics statistics_;
};

// WP-EKE-007's six Workflows (Inspect/Query/Validate/Analyze/Reason/
// Recommend) -- "Each workflow executes through the platform without
// exposing internal engines": WorkflowResult is the one shape every
// workflow returns, regardless of which lower engine(s) it composed
// internally.
enum class WorkflowKind {
    Inspect,
    Query,
    Validate,
    Analyze,
    Reason,
    Recommend,
};

std::string to_string(WorkflowKind kind);

struct WorkflowResult {
    WorkflowKind kind = WorkflowKind::Inspect;
    bool success = false;
    std::string summary;
    std::vector<std::string> object_ids;
    double execution_time_ms = 0.0;
};

// The three things the Service Orchestrator's inspect_* operations can
// target, per its own "inspect_object/inspect_package/inspect_context"
// trio -- one common report shape rather than three separate types.
enum class InspectionTargetKind {
    Object,
    Package,
    Context,
};

std::string to_string(InspectionTargetKind kind);

class InspectionReport {
public:
    InspectionReport(InspectionTargetKind kind, std::string target_id, std::vector<std::string> object_ids,
                      std::size_t validation_pass_count, std::size_t validation_finding_count, std::string summary)
        : kind_(kind),
          target_id_(std::move(target_id)),
          object_ids_(std::move(object_ids)),
          validation_pass_count_(validation_pass_count),
          validation_finding_count_(validation_finding_count),
          summary_(std::move(summary)) {}

    InspectionTargetKind kind() const { return kind_; }
    const std::string& target_id() const { return target_id_; }
    const std::vector<std::string>& object_ids() const { return object_ids_; }
    std::size_t validation_pass_count() const { return validation_pass_count_; }
    std::size_t validation_finding_count() const { return validation_finding_count_; }
    const std::string& summary() const { return summary_; }

private:
    InspectionTargetKind kind_;
    std::string target_id_;
    std::vector<std::string> object_ids_;
    std::size_t validation_pass_count_;
    std::size_t validation_finding_count_;
    std::string summary_;
};

// engineering_health(): a deterministic 0-100 score computed as
// 100 * passed / (passed + failed + errored), 100 when nothing was
// evaluated (no findings to report is not unhealthy) -- never a
// probabilistic estimate.
class EngineeringHealthReport {
public:
    EngineeringHealthReport(double health_score, std::size_t passed, std::size_t failed, std::size_t warnings,
                             std::size_t errors, std::size_t critical, std::string summary)
        : health_score_(health_score),
          passed_(passed),
          failed_(failed),
          warnings_(warnings),
          errors_(errors),
          critical_(critical),
          summary_(std::move(summary)) {}

    double health_score() const { return health_score_; }
    std::size_t passed() const { return passed_; }
    std::size_t failed() const { return failed_; }
    std::size_t warnings() const { return warnings_; }
    std::size_t errors() const { return errors_; }
    std::size_t critical() const { return critical_; }
    const std::string& summary() const { return summary_; }

private:
    double health_score_;
    std::size_t passed_;
    std::size_t failed_;
    std::size_t warnings_;
    std::size_t errors_;
    std::size_t critical_;
    std::string summary_;
};

class EngineeringSummaryReport {
public:
    EngineeringSummaryReport(std::size_t object_count, std::size_t relationship_count,
                              std::size_t connected_component_count, std::size_t validation_pass_count,
                              std::size_t validation_finding_count, std::string summary)
        : object_count_(object_count),
          relationship_count_(relationship_count),
          connected_component_count_(connected_component_count),
          validation_pass_count_(validation_pass_count),
          validation_finding_count_(validation_finding_count),
          summary_(std::move(summary)) {}

    std::size_t object_count() const { return object_count_; }
    std::size_t relationship_count() const { return relationship_count_; }
    std::size_t connected_component_count() const { return connected_component_count_; }
    std::size_t validation_pass_count() const { return validation_pass_count_; }
    std::size_t validation_finding_count() const { return validation_finding_count_; }
    const std::string& summary() const { return summary_; }

private:
    std::size_t object_count_;
    std::size_t relationship_count_;
    std::size_t connected_component_count_;
    std::size_t validation_pass_count_;
    std::size_t validation_finding_count_;
    std::string summary_;
};

} // namespace oep::engine
