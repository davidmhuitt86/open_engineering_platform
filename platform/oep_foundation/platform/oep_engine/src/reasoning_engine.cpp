#include "oep/engine/reasoning_engine.hpp"

#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

#include <algorithm>
#include <chrono>
#include <set>

namespace oep::engine {

namespace {

// Deterministic confidence formula (WP-EKE-006: "produce deterministic
// results," never a probabilistic/AI-derived estimate): starts at 0.5
// or more evidence saturating toward 1.0, +0.1 per supporting evidence
// item, capped at 1.0. A conclusion always has >=1 evidence item (see
// EngineeringConclusion's own doc comment), so confidence is always
// >= 0.6.
double confidence_for(std::size_t evidence_count) {
    return std::min(1.0, 0.5 + 0.1 * static_cast<double>(evidence_count));
}

} // namespace

RootCauseReport ReasoningEngine::analyze_root_cause(const std::string& symptom_object_id) {
    const DependencyReport dependencies = analysis_engine_.analyze_dependencies(symptom_object_id);

    std::vector<std::string> ids_to_check{symptom_object_id};
    ids_to_check.insert(ids_to_check.end(), dependencies.dependency_object_ids().begin(),
                         dependencies.dependency_object_ids().end());

    const std::string validation_session_id = validation_engine_.create_validation_session(ValidationProfile::Complete);
    const std::optional<ValidationReport> report = validation_engine_.validate_objects(validation_session_id, ids_to_check);

    std::set<std::string> finding_object_ids;
    if (report.has_value()) {
        for (const ValidationFinding& finding : report->findings()) {
            finding_object_ids.insert(finding.affected_objects().begin(), finding.affected_objects().end());
        }
    }

    return analysis_engine_.analyze_root_cause(symptom_object_id,
                                                 std::vector<std::string>(finding_object_ids.begin(), finding_object_ids.end()));
}

std::string ReasoningEngine::create_reasoning_session(std::string objective, std::vector<std::string> starting_objects) {
    const std::string session_id = oep::repository::generate_uuid_v4();
    sessions_.erase(session_id);
    sessions_.emplace(session_id, SessionState{oep::repository::current_timestamp_utc(), std::move(objective),
                                                std::move(starting_objects), std::nullopt});
    return session_id;
}

std::optional<ReasoningReport> ReasoningEngine::execute_reasoning(const std::string& session_id) {
    const auto session_found = sessions_.find(session_id);
    if (session_found == sessions_.end()) return std::nullopt;
    if (!graph_ready()) return std::nullopt;

    const auto start_time = std::chrono::steady_clock::now();
    const std::vector<std::string>& starting_objects = session_found->second.starting_objects;
    const KnowledgeGraph& graph = knowledge_graph_engine_.graph();

    std::vector<std::string> queries_executed;
    std::vector<std::string> validation_results;
    EvidenceGraph evidence;
    std::vector<EngineeringConclusion> conclusions;
    std::vector<EngineeringRecommendation> recommendations;

    std::map<std::string, std::string> object_evidence_ids; // object_id -> evidence_id, deduplicated
    int evidence_counter = 0;
    auto next_evidence_id = [&]() { return "EV-" + std::to_string(++evidence_counter); };

    auto ensure_object_evidence = [&](const std::string& object_id) -> std::string {
        const auto found = object_evidence_ids.find(object_id);
        if (found != object_evidence_ids.end()) return found->second;
        const std::string evidence_id = next_evidence_id();
        const KnowledgeGraphNode* node = graph.find_node(object_id);
        evidence.add_node(EvidenceNode(evidence_id, EvidenceKind::Object, object_id,
                                        node != nullptr ? node->name : object_id));
        object_evidence_ids.emplace(object_id, evidence_id);
        return evidence_id;
    };

    // Collect every starting object plus its transitive outgoing
    // DependsOn closure, then validate that whole set ONCE (Complete
    // profile) -- a single, shared validation pass all conclusions in
    // this session draw evidence from, rather than one pass per object.
    std::set<std::string> relevant_ids(starting_objects.begin(), starting_objects.end());
    std::map<std::string, DependencyReport> dependency_by_object;
    std::map<std::string, ImpactReport> impact_by_object;
    for (const std::string& id : starting_objects) {
        DependencyReport dep = analysis_engine_.analyze_dependencies(id);
        queries_executed.push_back("analyze_dependencies(" + id + ")");
        ImpactReport impact = analysis_engine_.analyze_impact(id);
        queries_executed.push_back("analyze_impact(" + id + ")");
        relevant_ids.insert(dep.dependency_object_ids().begin(), dep.dependency_object_ids().end());
        dependency_by_object.emplace(id, std::move(dep));
        impact_by_object.emplace(id, std::move(impact));
    }

    const std::string validation_session_id = validation_engine_.create_validation_session(ValidationProfile::Complete);
    const std::optional<ValidationReport> validation_report_result = validation_engine_.validate_objects(
        validation_session_id, std::vector<std::string>(relevant_ids.begin(), relevant_ids.end()));

    std::vector<std::string> rules_applied;
    std::map<std::string, std::vector<const ValidationFinding*>> findings_by_object;
    if (validation_report_result.has_value()) {
        rules_applied = validation_report_result->session().active_rule_ids();
        validation_results.push_back("session " + validation_session_id +
                                      ": pass=" + std::to_string(validation_report_result->pass_count()) +
                                      " warning=" + std::to_string(validation_report_result->warning_count()) +
                                      " error=" + std::to_string(validation_report_result->error_count()) +
                                      " critical=" + std::to_string(validation_report_result->critical_count()));
        for (const ValidationFinding& finding : validation_report_result->findings()) {
            for (const std::string& affected : finding.affected_objects()) {
                findings_by_object[affected].push_back(&finding);
            }
        }
    }

    for (const std::string& id : starting_objects) {
        const DependencyReport& dependencies = dependency_by_object.at(id);
        const ImpactReport& impact = impact_by_object.at(id);

        const std::string id_evidence = ensure_object_evidence(id);
        std::vector<std::string> dependency_evidence_ids{id_evidence};
        for (const std::string& dep_id : dependencies.dependency_object_ids()) {
            dependency_evidence_ids.push_back(ensure_object_evidence(dep_id));
        }

        conclusions.emplace_back(
            "CONCL-" + std::to_string(conclusions.size() + 1),
            "Object '" + id + "' has " + std::to_string(dependencies.dependency_object_ids().size()) +
                " transitive dependency object(s)",
            confidence_for(dependency_evidence_ids.size()), dependency_evidence_ids, dependencies.dependency_object_ids(),
            std::vector<std::string>{}, std::vector<std::string>{}, dependencies.evidence());

        if (!impact.affected_object_ids().empty()) {
            std::vector<std::string> impact_evidence_ids{id_evidence};
            for (const std::string& affected_id : impact.affected_object_ids()) {
                impact_evidence_ids.push_back(ensure_object_evidence(affected_id));
            }
            conclusions.emplace_back(
                "CONCL-" + std::to_string(conclusions.size() + 1),
                "A change to object '" + id + "' would affect " + std::to_string(impact.affected_object_ids().size()) +
                    " other object(s)",
                confidence_for(impact_evidence_ids.size()), impact_evidence_ids, impact.affected_object_ids(),
                std::vector<std::string>{}, std::vector<std::string>{}, impact.evidence());
        }

        // Findings touching this object or any of its dependencies.
        std::set<std::string> relevant_for_id{id};
        relevant_for_id.insert(dependencies.dependency_object_ids().begin(), dependencies.dependency_object_ids().end());
        std::vector<const ValidationFinding*> findings_for_id;
        std::set<const ValidationFinding*> seen_findings;
        for (const std::string& relevant_id : relevant_for_id) {
            const auto found = findings_by_object.find(relevant_id);
            if (found == findings_by_object.end()) continue;
            for (const ValidationFinding* finding : found->second) {
                if (seen_findings.insert(finding).second) findings_for_id.push_back(finding);
            }
        }
        std::sort(findings_for_id.begin(), findings_for_id.end(),
                  [](const ValidationFinding* a, const ValidationFinding* b) { return a->finding_id() < b->finding_id(); });

        if (!findings_for_id.empty()) {
            std::vector<std::string> finding_evidence_ids;
            std::vector<std::string> referenced_findings;
            std::vector<std::string> referenced_rules;
            std::set<std::string> finding_object_ids;
            for (const ValidationFinding* finding : findings_for_id) {
                const std::string finding_evidence_id = next_evidence_id();
                evidence.add_node(EvidenceNode(finding_evidence_id, EvidenceKind::ValidationFinding, finding->finding_id(),
                                                finding->message()));
                const std::string rule_evidence_id = next_evidence_id();
                evidence.add_node(EvidenceNode(rule_evidence_id, EvidenceKind::RuleEvaluation, finding->rule_id(),
                                                "rule that produced " + finding->finding_id()));
                evidence.add_relationship({rule_evidence_id, finding_evidence_id, "produced"});
                finding_evidence_ids.push_back(finding_evidence_id);
                referenced_findings.push_back(finding->finding_id());
                referenced_rules.push_back(finding->rule_id());
                finding_object_ids.insert(finding->affected_objects().begin(), finding->affected_objects().end());
            }

            const RootCauseReport root_cause = analysis_engine_.analyze_root_cause(
                id, std::vector<std::string>(finding_object_ids.begin(), finding_object_ids.end()));

            std::string statement = "Object '" + id + "' or its dependencies have " +
                                     std::to_string(findings_for_id.size()) + " outstanding validation finding(s)";
            if (!root_cause.candidate_root_causes().empty()) {
                statement += "; most likely root cause: '" + root_cause.candidate_root_causes().front() + "'";
            }
            conclusions.emplace_back("CONCL-" + std::to_string(conclusions.size() + 1), statement,
                                      confidence_for(finding_evidence_ids.size()), finding_evidence_ids,
                                      std::vector<std::string>(finding_object_ids.begin(), finding_object_ids.end()),
                                      referenced_rules, referenced_findings, root_cause.evidence());

            recommendations.emplace_back("REC-" + std::to_string(recommendations.size() + 1),
                                          RecommendationKind::FollowUpValidation, id,
                                          "Re-run validation for '" + id +
                                              "' after remediating the outstanding finding(s)",
                                          finding_evidence_ids);

            if (!root_cause.candidate_root_causes().empty()) {
                recommendations.emplace_back("REC-" + std::to_string(recommendations.size() + 1),
                                              RecommendationKind::AdditionalInspection, root_cause.candidate_root_causes().front(),
                                              "Inspect '" + root_cause.candidate_root_causes().front() +
                                                  "' as the most likely root cause affecting '" + id + "'",
                                              finding_evidence_ids);
            }
        }

        // SimilarComponent: objects sharing at least one domain/tag.
        const KnowledgeGraphNode* node = graph.find_node(id);
        if (node != nullptr && !node->domains.empty()) {
            std::set<std::string> similar_ids;
            for (const std::string& domain : node->domains) {
                for (const std::string& candidate : graph.ids_by_domain(domain)) {
                    if (candidate != id) similar_ids.insert(candidate);
                }
            }
            for (const std::string& similar_id : similar_ids) {
                const std::string similar_evidence = ensure_object_evidence(similar_id);
                recommendations.emplace_back("REC-" + std::to_string(recommendations.size() + 1),
                                              RecommendationKind::SimilarComponent, similar_id,
                                              "'" + similar_id + "' shares a domain with '" + id + "'",
                                              std::vector<std::string>{id_evidence, similar_evidence});
            }
        }

        // ConnectedSystem: direct neighbors.
        for (const KnowledgeGraphEdgeView& edge_view : graph.edges_of(id)) {
            const std::string neighbor_evidence = ensure_object_evidence(edge_view.neighbor_object_id);
            const std::string relationship_evidence_id = next_evidence_id();
            evidence.add_node(EvidenceNode(relationship_evidence_id, EvidenceKind::Relationship, edge_view.relationship_id,
                                            "connects '" + id + "' to '" + edge_view.neighbor_object_id + "'"));
            recommendations.emplace_back("REC-" + std::to_string(recommendations.size() + 1),
                                          RecommendationKind::ConnectedSystem, edge_view.neighbor_object_id,
                                          "'" + edge_view.neighbor_object_id + "' is directly connected to '" + id + "'",
                                          std::vector<std::string>{id_evidence, neighbor_evidence, relationship_evidence_id});

            const KnowledgeGraphNode* neighbor_node = graph.find_node(edge_view.neighbor_object_id);
            if (neighbor_node != nullptr && neighbor_node->object_type == oep::repository::ObjectType::Procedure) {
                recommendations.emplace_back("REC-" + std::to_string(recommendations.size() + 1),
                                              RecommendationKind::RelatedProcedure, edge_view.neighbor_object_id,
                                              "Procedure '" + edge_view.neighbor_object_id + "' is directly related to '" + id + "'",
                                              std::vector<std::string>{id_evidence, neighbor_evidence, relationship_evidence_id});
            }
        }
    }

    const auto end_time = std::chrono::steady_clock::now();
    const double execution_time_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();

    ReasoningSession session(session_id, session_found->second.start_time_utc, oep::repository::current_timestamp_utc(),
                              session_found->second.objective, starting_objects, queries_executed, rules_applied,
                              validation_results, conclusions, evidence);

    ReasoningReport report(session, recommendations, execution_time_ms);
    session_found->second.last_report = report;
    return report;
}

std::optional<ReasoningReport> ReasoningEngine::reasoning_report(const std::string& session_id) const {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end()) return std::nullopt;
    return found->second.last_report;
}

std::vector<EngineeringRecommendation> ReasoningEngine::engineering_recommendations(const std::string& session_id) const {
    const std::optional<ReasoningReport> report = reasoning_report(session_id);
    if (!report.has_value()) return {};
    return report->recommendations();
}

} // namespace oep::engine
