#include "oep/engine/rule_types.hpp"

namespace oep::engine {

std::string to_string(RuleCategory category) {
    switch (category) {
        case RuleCategory::Structural: return "Structural";
        case RuleCategory::Connectivity: return "Connectivity";
        case RuleCategory::Dependency: return "Dependency";
        case RuleCategory::Reference: return "Reference";
        case RuleCategory::Documentation: return "Documentation";
        case RuleCategory::Metadata: return "Metadata";
        case RuleCategory::Package: return "Package";
    }
    return "Unknown";
}

std::string to_string(RuleSeverity severity) {
    switch (severity) {
        case RuleSeverity::Info: return "Info";
        case RuleSeverity::Warning: return "Warning";
        case RuleSeverity::Error: return "Error";
        case RuleSeverity::Critical: return "Critical";
    }
    return "Unknown";
}

std::string to_string(RuleConditionKind kind) {
    switch (kind) {
        case RuleConditionKind::RequiresRelationship: return "RequiresRelationship";
        case RuleConditionKind::ForbidsRelationship: return "ForbidsRelationship";
        case RuleConditionKind::MinRelationshipCount: return "MinRelationshipCount";
        case RuleConditionKind::MaxRelationshipCount: return "MaxRelationshipCount";
        case RuleConditionKind::RequiresTag: return "RequiresTag";
        case RuleConditionKind::ForbidsTag: return "ForbidsTag";
        case RuleConditionKind::HasDescription: return "HasDescription";
        case RuleConditionKind::HasAuthor: return "HasAuthor";
        case RuleConditionKind::NoCycles: return "NoCycles";
        case RuleConditionKind::NoIsolatedObjects: return "NoIsolatedObjects";
    }
    return "Unknown";
}

std::string to_string(RuleEvaluationStatus status) {
    switch (status) {
        case RuleEvaluationStatus::Passed: return "Passed";
        case RuleEvaluationStatus::Failed: return "Failed";
        case RuleEvaluationStatus::NotApplicable: return "NotApplicable";
        case RuleEvaluationStatus::Error: return "Error";
    }
    return "Unknown";
}

} // namespace oep::engine
