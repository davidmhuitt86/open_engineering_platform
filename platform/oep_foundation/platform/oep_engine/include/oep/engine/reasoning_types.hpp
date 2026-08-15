#pragma once

#include <string>
#include <vector>

namespace oep::engine {

// WP-EKE-006's Evidence Graph: a TEMPORARY, per-reasoning-session graph
// of evidence -- never the Engineering Knowledge Graph itself, never
// mutates it, and is discarded when its owning ReasoningSession ends.
// Every EvidenceNode names WHERE its content came from (an Engineering
// Object, a query execution, a rule evaluation, or a validation
// finding) so a conclusion referencing it is traceable back to a
// concrete, already-computed fact -- never a freeform assertion.
enum class EvidenceKind {
    Object,             // a specific Engineering Object (reference_id == object_id)
    Relationship,        // a specific Relationship (reference_id == relationship_id)
    QueryExecution,       // a Query Engine result (reference_id == a description of the query run)
    RuleEvaluation,        // a Rules Engine result (reference_id == rule_id)
    ValidationFinding,      // a Validation Engine finding (reference_id == finding_id)
};

std::string to_string(EvidenceKind kind);

class EvidenceNode {
public:
    EvidenceNode(std::string evidence_id, EvidenceKind kind, std::string reference_id, std::string detail)
        : evidence_id_(std::move(evidence_id)), kind_(kind), reference_id_(std::move(reference_id)), detail_(std::move(detail)) {}

    const std::string& evidence_id() const { return evidence_id_; }
    EvidenceKind kind() const { return kind_; }
    const std::string& reference_id() const { return reference_id_; }
    const std::string& detail() const { return detail_; }

private:
    std::string evidence_id_;
    EvidenceKind kind_;
    std::string reference_id_;
    std::string detail_;
};

// One directed relationship between two evidence nodes within the same
// Evidence Graph (e.g. "this ValidationFinding evidence SUPPORTS this
// Object evidence's inclusion as a root-cause candidate"). `relation`
// is a short, free-text label -- WP-EKE-006 does not define a fixed
// taxonomy of evidence-relationship kinds, only that they must exist
// and be inspectable.
struct EvidenceRelationship {
    std::string source_evidence_id;
    std::string target_evidence_id;
    std::string relation;
};

class EvidenceGraph {
public:
    EvidenceGraph() = default;

    void add_node(EvidenceNode node) { nodes_.push_back(std::move(node)); }
    void add_relationship(EvidenceRelationship relationship) { relationships_.push_back(std::move(relationship)); }

    const std::vector<EvidenceNode>& nodes() const { return nodes_; }
    const std::vector<EvidenceRelationship>& relationships() const { return relationships_; }

private:
    std::vector<EvidenceNode> nodes_;
    std::vector<EvidenceRelationship> relationships_;
};

// WP-EKE-006's immutable EngineeringConclusion: Conclusion ID,
// Statement, Confidence, Supporting Evidence, Referenced Objects,
// Referenced Rules, Referenced Validation Findings, Explanation --
// exactly the fields the work package names. `confidence` is computed
// deterministically from the SIZE of the supporting evidence set (see
// reasoning_engine.cpp's own doc comment for the exact, documented
// formula) -- never a probabilistic or AI-derived estimate.
// "Every conclusion must reference its supporting evidence":
// `supporting_evidence_ids` must never be empty for a conclusion this
// module produces.
class EngineeringConclusion {
public:
    EngineeringConclusion(std::string conclusion_id, std::string statement, double confidence,
                           std::vector<std::string> supporting_evidence_ids, std::vector<std::string> referenced_objects,
                           std::vector<std::string> referenced_rules, std::vector<std::string> referenced_findings,
                           std::string explanation)
        : conclusion_id_(std::move(conclusion_id)),
          statement_(std::move(statement)),
          confidence_(confidence),
          supporting_evidence_ids_(std::move(supporting_evidence_ids)),
          referenced_objects_(std::move(referenced_objects)),
          referenced_rules_(std::move(referenced_rules)),
          referenced_findings_(std::move(referenced_findings)),
          explanation_(std::move(explanation)) {}

    const std::string& conclusion_id() const { return conclusion_id_; }
    const std::string& statement() const { return statement_; }
    double confidence() const { return confidence_; }
    const std::vector<std::string>& supporting_evidence_ids() const { return supporting_evidence_ids_; }
    const std::vector<std::string>& referenced_objects() const { return referenced_objects_; }
    const std::vector<std::string>& referenced_rules() const { return referenced_rules_; }
    const std::vector<std::string>& referenced_findings() const { return referenced_findings_; }
    const std::string& explanation() const { return explanation_; }

private:
    std::string conclusion_id_;
    std::string statement_;
    double confidence_;
    std::vector<std::string> supporting_evidence_ids_;
    std::vector<std::string> referenced_objects_;
    std::vector<std::string> referenced_rules_;
    std::vector<std::string> referenced_findings_;
    std::string explanation_;
};

// WP-EKE-006's Recommendation Engine categories (the work package's own
// "Examples" list): Related Procedures, Similar Components, Additional
// Inspections, Connected Systems, Follow-up Validations.
enum class RecommendationKind {
    RelatedProcedure,
    SimilarComponent,
    AdditionalInspection,
    ConnectedSystem,
    FollowUpValidation,
};

std::string to_string(RecommendationKind kind);

// Immutable. "Recommendations must always include the evidence used to
// generate them": `supporting_evidence_ids` must never be empty.
class EngineeringRecommendation {
public:
    EngineeringRecommendation(std::string recommendation_id, RecommendationKind kind, std::string object_id,
                               std::string message, std::vector<std::string> supporting_evidence_ids)
        : recommendation_id_(std::move(recommendation_id)),
          kind_(kind),
          object_id_(std::move(object_id)),
          message_(std::move(message)),
          supporting_evidence_ids_(std::move(supporting_evidence_ids)) {}

    const std::string& recommendation_id() const { return recommendation_id_; }
    RecommendationKind kind() const { return kind_; }
    const std::string& object_id() const { return object_id_; }
    const std::string& message() const { return message_; }
    const std::vector<std::string>& supporting_evidence_ids() const { return supporting_evidence_ids_; }

private:
    std::string recommendation_id_;
    RecommendationKind kind_;
    std::string object_id_;
    std::string message_;
    std::vector<std::string> supporting_evidence_ids_;
};

// WP-EKE-006's immutable ReasoningSession: Session ID, Start Time, End
// Time, Objective, Starting Objects, Queries Executed, Rules Applied,
// Validation Results, Conclusions, Evidence -- exactly the fields the
// work package names. `queries_executed`/`rules_applied`/
// `validation_results` are short, human-readable descriptions of what
// ran (not full nested reports -- those live in the Query/Rules/
// Validation Engines' own already-cached results, reachable by the ids
// this session's Evidence Graph references).
class ReasoningSession {
public:
    ReasoningSession(std::string session_id, std::string start_time_utc, std::string end_time_utc, std::string objective,
                      std::vector<std::string> starting_objects, std::vector<std::string> queries_executed,
                      std::vector<std::string> rules_applied, std::vector<std::string> validation_results,
                      std::vector<EngineeringConclusion> conclusions, EvidenceGraph evidence)
        : session_id_(std::move(session_id)),
          start_time_utc_(std::move(start_time_utc)),
          end_time_utc_(std::move(end_time_utc)),
          objective_(std::move(objective)),
          starting_objects_(std::move(starting_objects)),
          queries_executed_(std::move(queries_executed)),
          rules_applied_(std::move(rules_applied)),
          validation_results_(std::move(validation_results)),
          conclusions_(std::move(conclusions)),
          evidence_(std::move(evidence)) {}

    const std::string& session_id() const { return session_id_; }
    const std::string& start_time_utc() const { return start_time_utc_; }
    const std::string& end_time_utc() const { return end_time_utc_; }
    const std::string& objective() const { return objective_; }
    const std::vector<std::string>& starting_objects() const { return starting_objects_; }
    const std::vector<std::string>& queries_executed() const { return queries_executed_; }
    const std::vector<std::string>& rules_applied() const { return rules_applied_; }
    const std::vector<std::string>& validation_results() const { return validation_results_; }
    const std::vector<EngineeringConclusion>& conclusions() const { return conclusions_; }
    const EvidenceGraph& evidence() const { return evidence_; }

private:
    std::string session_id_;
    std::string start_time_utc_;
    std::string end_time_utc_;
    std::string objective_;
    std::vector<std::string> starting_objects_;
    std::vector<std::string> queries_executed_;
    std::vector<std::string> rules_applied_;
    std::vector<std::string> validation_results_;
    std::vector<EngineeringConclusion> conclusions_;
    EvidenceGraph evidence_;
};

// WP-EKE-006's immutable Reasoning Report: the session plus the
// recommendations derived from it, plus execution timing.
class ReasoningReport {
public:
    ReasoningReport(ReasoningSession session, std::vector<EngineeringRecommendation> recommendations,
                     double execution_time_ms)
        : session_(std::move(session)), recommendations_(std::move(recommendations)), execution_time_ms_(execution_time_ms) {}

    const ReasoningSession& session() const { return session_; }
    const std::vector<EngineeringRecommendation>& recommendations() const { return recommendations_; }
    double execution_time_ms() const { return execution_time_ms_; }

private:
    ReasoningSession session_;
    std::vector<EngineeringRecommendation> recommendations_;
    double execution_time_ms_;
};

} // namespace oep::engine
