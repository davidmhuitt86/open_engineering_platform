#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::engine {

// WP-EKE-004: the seven minimum rule categories this work package requires.
enum class RuleCategory {
    Structural,
    Connectivity,
    Dependency,
    Reference,
    Documentation,
    Metadata,
    Package,
};

std::string to_string(RuleCategory category);

enum class RuleSeverity {
    Info,
    Warning,
    Error,
    Critical,
};

std::string to_string(RuleSeverity severity);

// Which Engineering Objects a rule applies to. `SingleObject` scopes to
// exactly `object_id`; the others scope to every object matching the
// given field, exactly mirroring the index KnowledgeGraph already
// maintains for that field (WP-EKE-002).
enum class RuleScopeKind {
    AllObjects,
    ByObjectType,
    ByDomain,
    ByPackage,
    SingleObject,
};

struct RuleScope {
    RuleScopeKind kind = RuleScopeKind::AllObjects;
    std::optional<oep::repository::ObjectType> object_type; // ByObjectType
    std::optional<std::string> domain;                       // ByDomain
    std::optional<std::string> package_id;                   // ByPackage
    std::optional<std::string> object_id;                    // SingleObject
};

// The small, fixed set of condition PRIMITIVES the Rule Evaluator knows
// how to interpret. A RuleCondition is pure data -- constructing one
// with a given `kind` and parameters describes what to check; it never
// contains code. This is what keeps rules data-driven (WP-EKE-004:
// "No engineering rules shall be hardcoded into the engine"): the
// ENGINE only implements these ~10 generic primitives, never any
// specific engineering policy (e.g. "every Component must reference a
// Specification") -- that policy is expressed by constructing an
// EngineeringRule value with the right scope/conditions, entirely at
// the call site (CLI/API/a future rule-loading mechanism), never by
// adding a case to the evaluator's own source code.
enum class RuleConditionKind {
    RequiresRelationship,   // the object must have >=1 relationship of `relationship_type` (direction per `direction`)
    ForbidsRelationship,    // the object must have 0 relationships of `relationship_type` (direction per `direction`)
    MinRelationshipCount,   // the object must have >= `count` relationships of `relationship_type` (direction per `direction`)
    MaxRelationshipCount,   // the object must have <= `count` relationships of `relationship_type` (direction per `direction`)
    RequiresTag,            // the object must have the tag/domain `tag`
    ForbidsTag,              // the object must NOT have the tag/domain `tag`
    HasDescription,          // the object's description must be non-empty
    HasAuthor,                // the object's author must be non-empty
    NoCycles,                  // graph-level: no directed cycle exists among edges of `relationship_type` (checked once, ignores scope)
    NoIsolatedObjects,        // graph-level within scope: every scoped object must have >=1 relationship (any type)
};

std::string to_string(RuleConditionKind kind);

// Direction for relationship-counting conditions: nullopt == either
// direction; true == outgoing only; false == incoming only. Matches
// the same nullable-bool direction convention WP-EKE-003's QueryFilter
// already established.
struct RuleCondition {
    RuleConditionKind kind = RuleConditionKind::HasDescription;
    std::optional<oep::repository::RelationshipType> relationship_type;
    std::optional<bool> direction;
    std::optional<std::string> tag;
    std::optional<int> count;
};

// WP-EKE-004's immutable EngineeringRule: Rule ID, Name, Description,
// Category, Severity, Scope, Conditions, Message, Recommendation --
// exactly the fields the work package names. Every EngineeringRule is
// pure data; constructing one never requires touching the evaluator's
// source code.
class EngineeringRule {
public:
    EngineeringRule(std::string rule_id, std::string name, std::string description, RuleCategory category,
                     RuleSeverity severity, RuleScope scope, std::vector<RuleCondition> conditions, std::string message,
                     std::string recommendation)
        : rule_id_(std::move(rule_id)),
          name_(std::move(name)),
          description_(std::move(description)),
          category_(category),
          severity_(severity),
          scope_(std::move(scope)),
          conditions_(std::move(conditions)),
          message_(std::move(message)),
          recommendation_(std::move(recommendation)) {}

    const std::string& rule_id() const { return rule_id_; }
    const std::string& name() const { return name_; }
    const std::string& description() const { return description_; }
    RuleCategory category() const { return category_; }
    RuleSeverity severity() const { return severity_; }
    const RuleScope& scope() const { return scope_; }
    const std::vector<RuleCondition>& conditions() const { return conditions_; }
    const std::string& message() const { return message_; }
    const std::string& recommendation() const { return recommendation_; }

private:
    std::string rule_id_;
    std::string name_;
    std::string description_;
    RuleCategory category_;
    RuleSeverity severity_;
    RuleScope scope_;
    std::vector<RuleCondition> conditions_;
    std::string message_;
    std::string recommendation_;
};

enum class RuleEvaluationStatus {
    Passed,
    Failed,
    NotApplicable, // the rule's scope matched zero objects and it has no graph-level condition
    Error,          // a condition referenced a parameter it requires but was not given (e.g. RequiresTag with no tag set)
};

std::string to_string(RuleEvaluationStatus status);

// One diagnostic entry (WP-EKE-004's Rule Diagnostics): `object_id` is
// empty for a graph-level diagnostic (e.g. a NoCycles violation, which
// isn't about one object).
struct RuleDiagnostic {
    std::string object_id;
    std::string detail;
};

// WP-EKE-004's immutable RuleEvaluationResult: Rule, Status, Message,
// Affected Objects, Diagnostics -- exactly the fields the work package
// names. `affected_objects` is sorted and deduplicated -- determinism.
class RuleEvaluationResult {
public:
    RuleEvaluationResult(EngineeringRule rule, RuleEvaluationStatus status, std::string message,
                          std::vector<std::string> affected_objects, std::vector<RuleDiagnostic> diagnostics)
        : rule_(std::move(rule)),
          status_(status),
          message_(std::move(message)),
          affected_objects_(std::move(affected_objects)),
          diagnostics_(std::move(diagnostics)) {}

    const EngineeringRule& rule() const { return rule_; }
    RuleEvaluationStatus status() const { return status_; }
    const std::string& message() const { return message_; }
    const std::vector<std::string>& affected_objects() const { return affected_objects_; }
    const std::vector<RuleDiagnostic>& diagnostics() const { return diagnostics_; }

private:
    EngineeringRule rule_;
    RuleEvaluationStatus status_;
    std::string message_;
    std::vector<std::string> affected_objects_;
    std::vector<RuleDiagnostic> diagnostics_;
};

// WP-EKE-004's rule evaluation Configuration: small, free-form,
// data-driven knobs a caller may supply (e.g. thresholds a future rule
// set wants tunable without recompiling). Deliberately just a string
// map rather than a typed settings object -- this module has no fixed
// opinion on what configuration a data-driven rule set might need.
struct RuleConfiguration {
    std::map<std::string, std::string> settings;
};

} // namespace oep::engine
