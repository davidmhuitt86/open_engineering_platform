#pragma once

#include <string>
#include <vector>

#include "oep/engine/rule_types.hpp"

namespace oep::engine {

// WP-EKE-005: which named rule subset a validation run executes.
// "Profiles select which rules are executed" -- concretely, each named
// profile except Complete maps onto exactly one RuleCategory (WP-EKE-004);
// Complete runs every enabled rule regardless of category. This mapping
// is the only "policy" ValidationEngine itself contains; it never
// embeds an engineering RULE (a scope/condition/message), only this
// category selection -- see validation_engine.hpp's own doc comment.
enum class ValidationProfile {
    Structural,
    Connectivity,
    Documentation,
    Metadata,
    Complete,
};

std::string to_string(ValidationProfile profile);

// WP-EKE-005's five Validation Scopes, expressed as one discriminated
// target type: Single Engineering Object, Multiple Engineering Objects,
// Complete Engineering Context, Installed Package, Arbitrary Query
// Result. All five ultimately resolve to a set of object ids
// ValidationEngine narrows findings down to (empty `object_ids` with
// `kind == EngineeringContext` means "the whole graph, unfiltered").
enum class ValidationTargetKind {
    SingleObject,
    MultipleObjects,
    EngineeringContext,
    Package,
    QueryResult,
};

class ValidationTarget {
public:
    static ValidationTarget for_object(std::string object_id);
    static ValidationTarget for_objects(std::vector<std::string> object_ids);
    static ValidationTarget for_context();
    static ValidationTarget for_package(std::string package_id);
    static ValidationTarget for_query_result(std::vector<std::string> object_ids);

    ValidationTargetKind kind() const { return kind_; }
    const std::vector<std::string>& object_ids() const { return object_ids_; }
    const std::string& package_id() const { return package_id_; }

private:
    ValidationTarget(ValidationTargetKind kind, std::vector<std::string> object_ids, std::string package_id)
        : kind_(kind), object_ids_(std::move(object_ids)), package_id_(std::move(package_id)) {}

    ValidationTargetKind kind_;
    std::vector<std::string> object_ids_;
    std::string package_id_;
};

std::string to_string(ValidationTargetKind kind);

// WP-EKE-005's Validation Statistics.
struct ValidationStatistics {
    std::size_t rules_evaluated = 0;
    std::size_t rules_passed = 0;
    std::size_t rules_failed = 0;
    std::size_t rules_not_applicable = 0;
    std::size_t rules_errored = 0;
    double execution_time_ms = 0.0;
};

// WP-EKE-005's immutable ValidationFinding: Finding ID, Rule ID,
// Severity, Category, Message, Recommendation, Affected Objects,
// Diagnostics -- exactly the fields the work package names. One
// Finding is produced per rule whose evaluation (after narrowing to
// the validation target) is Failed or Error; a Passed or
// NotApplicable rule produces no finding (it is still counted in
// ValidationStatistics).
class ValidationFinding {
public:
    ValidationFinding(std::string finding_id, std::string rule_id, RuleSeverity severity, RuleCategory category,
                       std::string message, std::string recommendation, std::vector<std::string> affected_objects,
                       std::vector<RuleDiagnostic> diagnostics)
        : finding_id_(std::move(finding_id)),
          rule_id_(std::move(rule_id)),
          severity_(severity),
          category_(category),
          message_(std::move(message)),
          recommendation_(std::move(recommendation)),
          affected_objects_(std::move(affected_objects)),
          diagnostics_(std::move(diagnostics)) {}

    const std::string& finding_id() const { return finding_id_; }
    const std::string& rule_id() const { return rule_id_; }
    RuleSeverity severity() const { return severity_; }
    RuleCategory category() const { return category_; }
    const std::string& message() const { return message_; }
    const std::string& recommendation() const { return recommendation_; }
    const std::vector<std::string>& affected_objects() const { return affected_objects_; }
    const std::vector<RuleDiagnostic>& diagnostics() const { return diagnostics_; }

private:
    std::string finding_id_;
    std::string rule_id_;
    RuleSeverity severity_;
    RuleCategory category_;
    std::string message_;
    std::string recommendation_;
    std::vector<std::string> affected_objects_;
    std::vector<RuleDiagnostic> diagnostics_;
};

// WP-EKE-005's immutable ValidationSession: Session ID, Start Time, End
// Time, Validation Target, Active Rule Set, Validation Profile,
// Statistics -- exactly the fields the work package names.
class ValidationSession {
public:
    ValidationSession(std::string session_id, std::string start_time_utc, std::string end_time_utc,
                       ValidationTarget target, std::vector<std::string> active_rule_ids, ValidationProfile profile,
                       ValidationStatistics statistics)
        : session_id_(std::move(session_id)),
          start_time_utc_(std::move(start_time_utc)),
          end_time_utc_(std::move(end_time_utc)),
          target_(std::move(target)),
          active_rule_ids_(std::move(active_rule_ids)),
          profile_(profile),
          statistics_(std::move(statistics)) {}

    const std::string& session_id() const { return session_id_; }
    const std::string& start_time_utc() const { return start_time_utc_; }
    const std::string& end_time_utc() const { return end_time_utc_; }
    const ValidationTarget& target() const { return target_; }
    const std::vector<std::string>& active_rule_ids() const { return active_rule_ids_; }
    ValidationProfile profile() const { return profile_; }
    const ValidationStatistics& statistics() const { return statistics_; }

private:
    std::string session_id_;
    std::string start_time_utc_;
    std::string end_time_utc_;
    ValidationTarget target_;
    std::vector<std::string> active_rule_ids_;
    ValidationProfile profile_;
    ValidationStatistics statistics_;
};

// WP-EKE-005's immutable ValidationReport: Session, Findings,
// Statistics, Pass Count, Warning Count, Error Count, Critical Count,
// Execution Time -- exactly the fields the work package names.
// pass_count mirrors statistics().rules_passed; warning/error/
// critical_count are findings grouped by RuleSeverity. Never modifies
// engineering knowledge -- pure aggregation of what RulesEngine
// already computed.
class ValidationReport {
public:
    ValidationReport(ValidationSession session, std::vector<ValidationFinding> findings, ValidationStatistics statistics,
                      int pass_count, int warning_count, int error_count, int critical_count, double execution_time_ms)
        : session_(std::move(session)),
          findings_(std::move(findings)),
          statistics_(std::move(statistics)),
          pass_count_(pass_count),
          warning_count_(warning_count),
          error_count_(error_count),
          critical_count_(critical_count),
          execution_time_ms_(execution_time_ms) {}

    const ValidationSession& session() const { return session_; }
    const std::vector<ValidationFinding>& findings() const { return findings_; }
    const ValidationStatistics& statistics() const { return statistics_; }
    int pass_count() const { return pass_count_; }
    int warning_count() const { return warning_count_; }
    int error_count() const { return error_count_; }
    int critical_count() const { return critical_count_; }
    double execution_time_ms() const { return execution_time_ms_; }

private:
    ValidationSession session_;
    std::vector<ValidationFinding> findings_;
    ValidationStatistics statistics_;
    int pass_count_;
    int warning_count_;
    int error_count_;
    int critical_count_;
    double execution_time_ms_;
};

} // namespace oep::engine
