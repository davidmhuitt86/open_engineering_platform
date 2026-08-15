#include "oep/engine/validation_engine.hpp"

#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

#include <algorithm>
#include <chrono>
#include <set>

namespace oep::engine {

namespace {

bool profile_includes(ValidationProfile profile, RuleCategory category) {
    switch (profile) {
        case ValidationProfile::Structural: return category == RuleCategory::Structural;
        case ValidationProfile::Connectivity: return category == RuleCategory::Connectivity;
        case ValidationProfile::Documentation: return category == RuleCategory::Documentation;
        case ValidationProfile::Metadata: return category == RuleCategory::Metadata;
        case ValidationProfile::Complete: return true;
    }
    return false;
}

} // namespace

std::string ValidationEngine::create_validation_session(ValidationProfile profile) {
    const std::string session_id = oep::repository::generate_uuid_v4();
    sessions_.erase(session_id);
    sessions_.emplace(session_id, SessionState{oep::repository::current_timestamp_utc(), profile, std::nullopt});
    return session_id;
}

std::optional<ValidationReport> ValidationEngine::validate_object(const std::string& session_id,
                                                                    const std::string& object_id) {
    return run(session_id, ValidationTarget::for_object(object_id), std::vector<std::string>{object_id});
}

std::optional<ValidationReport> ValidationEngine::validate_objects(const std::string& session_id,
                                                                     const std::vector<std::string>& object_ids) {
    return run(session_id, ValidationTarget::for_objects(object_ids), object_ids);
}

std::optional<ValidationReport> ValidationEngine::validate_context(const std::string& session_id) {
    return run(session_id, ValidationTarget::for_context(), std::nullopt);
}

std::optional<ValidationReport> ValidationEngine::validate_package(const std::string& session_id,
                                                                     const std::string& package_id) {
    const std::vector<std::string> object_ids = knowledge_graph_engine_.graph().ids_by_package(package_id);
    return run(session_id, ValidationTarget::for_package(package_id), object_ids);
}

std::optional<ValidationReport> ValidationEngine::validate_query_result(const std::string& session_id,
                                                                          const EngineeringQueryResult& query_result) {
    return run(session_id, ValidationTarget::for_query_result(query_result.object_ids()), query_result.object_ids());
}

std::optional<ValidationReport> ValidationEngine::run(const std::string& session_id, ValidationTarget target,
                                                        const std::optional<std::vector<std::string>>& narrow_to_object_ids) {
    const auto session_found = sessions_.find(session_id);
    if (session_found == sessions_.end()) return std::nullopt;
    if (!graph_ready()) return std::nullopt;

    const auto start_time = std::chrono::steady_clock::now();
    const ValidationProfile profile = session_found->second.profile;

    std::set<std::string> narrow_set;
    if (narrow_to_object_ids.has_value()) {
        narrow_set.insert(narrow_to_object_ids->begin(), narrow_to_object_ids->end());
    }

    std::vector<std::string> active_rule_ids;
    std::vector<ValidationFinding> findings;
    ValidationStatistics statistics;
    int warning_count = 0, error_count = 0, critical_count = 0;

    for (const EngineeringRule& rule : rules_engine_.enabled_rules()) {
        if (!profile_includes(profile, rule.category())) continue;
        active_rule_ids.push_back(rule.rule_id());

        const std::optional<RuleEvaluationResult> result = rules_engine_.evaluate_rule(rule.rule_id());
        if (!result.has_value()) continue; // rule vanished between enabled_rules() and evaluate_rule() -- skip defensively

        std::vector<std::string> affected = result->affected_objects();
        std::vector<RuleDiagnostic> diagnostics = result->diagnostics();

        if (!narrow_set.empty()) {
            std::vector<std::string> narrowed_affected;
            for (const std::string& id : affected) {
                if (narrow_set.count(id) != 0) narrowed_affected.push_back(id);
            }
            std::vector<RuleDiagnostic> narrowed_diagnostics;
            for (const RuleDiagnostic& diagnostic : diagnostics) {
                // A graph-level diagnostic (empty object_id, e.g. a
                // cycle) is only meaningful for whole-context
                // validation; it never narrows to a specific target.
                if (!diagnostic.object_id.empty() && narrow_set.count(diagnostic.object_id) != 0) {
                    narrowed_diagnostics.push_back(diagnostic);
                }
            }
            affected = std::move(narrowed_affected);
            diagnostics = std::move(narrowed_diagnostics);
        }

        RuleEvaluationStatus effective_status = result->status();
        if (effective_status == RuleEvaluationStatus::Failed && affected.empty() && diagnostics.empty()) {
            // The rule failed overall, but not because of anything in
            // THIS target -- for this target's purposes, it passed.
            effective_status = RuleEvaluationStatus::Passed;
        }

        switch (effective_status) {
            case RuleEvaluationStatus::Passed: ++statistics.rules_passed; break;
            case RuleEvaluationStatus::NotApplicable: ++statistics.rules_not_applicable; break;
            case RuleEvaluationStatus::Error: ++statistics.rules_errored; break;
            case RuleEvaluationStatus::Failed: ++statistics.rules_failed; break;
        }
        ++statistics.rules_evaluated;

        if (effective_status == RuleEvaluationStatus::Failed || effective_status == RuleEvaluationStatus::Error) {
            findings.emplace_back("FIND-" + rule.rule_id(), rule.rule_id(), rule.severity(), rule.category(),
                                   result->message(), rule.recommendation(), affected, diagnostics);
            switch (rule.severity()) {
                case RuleSeverity::Warning: ++warning_count; break;
                case RuleSeverity::Error: ++error_count; break;
                case RuleSeverity::Critical: ++critical_count; break;
                case RuleSeverity::Info: break;
            }
        }
    }

    const auto end_time = std::chrono::steady_clock::now();
    statistics.execution_time_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();

    const ValidationSession session(session_id, session_found->second.start_time_utc,
                                     oep::repository::current_timestamp_utc(), std::move(target), active_rule_ids,
                                     profile, statistics);

    ValidationReport report(session, std::move(findings), statistics, static_cast<int>(statistics.rules_passed),
                             warning_count, error_count, critical_count, statistics.execution_time_ms);

    session_found->second.last_report = report;
    return report;
}

std::optional<ValidationReport> ValidationEngine::validation_report(const std::string& session_id) const {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end()) return std::nullopt;
    return found->second.last_report;
}

std::optional<ValidationStatistics> ValidationEngine::validation_statistics(const std::string& session_id) const {
    const std::optional<ValidationReport> report = validation_report(session_id);
    if (!report.has_value()) return std::nullopt;
    return report->statistics();
}

} // namespace oep::engine
