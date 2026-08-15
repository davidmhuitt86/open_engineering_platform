#include "oep/engine/engineering_intelligence_platform.hpp"

#include <chrono>
#include <sstream>

namespace oep::engine {

namespace {
double elapsed_ms(const std::chrono::steady_clock::time_point& start) {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
}
} // namespace

bool EngineeringIntelligencePlatform::close_session(const std::string& session_id) {
    const bool closed = sessions_.close_session(session_id);
    if (closed && current_session_id_ == session_id) current_session_id_.clear();
    return closed;
}

bool EngineeringIntelligencePlatform::switch_session(const std::string& session_id) {
    if (!sessions_.resume_session(session_id)) return false;
    current_session_id_ = session_id;
    return true;
}

void EngineeringIntelligencePlatform::cleanup() {
    for (const std::string& session_id : sessions_.list_sessions()) {
        sessions_.close_session(session_id);
    }
    current_session_id_.clear();
    invalidate_caches();
}

void EngineeringIntelligencePlatform::invalidate_caches() {
    query_engine_.clear_query_cache();
}

RuntimeMetrics EngineeringIntelligencePlatform::runtime_metrics() const {
    RuntimeMetrics metrics = metrics_;
    metrics.active_session_count = sessions_.active_session_count();
    metrics.total_session_count = sessions_.total_session_count();
    metrics.cache_hits = query_engine_.query_cache().result_count(); // cached results available to be hit
    return metrics;
}

// ---------------------------------------------------------------------
// Service Orchestrator
// ---------------------------------------------------------------------

InspectionReport EngineeringIntelligencePlatform::inspect_object(const std::string& object_id) {
    ++metrics_.validation_count;
    const std::string session_id = validation_engine_.create_validation_session(ValidationProfile::Complete);
    const std::optional<ValidationReport> report = validation_engine_.validate_object(session_id, object_id);
    const bool exists = knowledge_graph_engine_.graph().contains(object_id);

    std::ostringstream summary;
    summary << "Object '" << object_id << "' " << (exists ? "exists" : "was not found") << " in the Knowledge Graph.";
    std::size_t pass = 0, findings = 0;
    if (report.has_value()) {
        pass = report->statistics().rules_passed;
        findings = report->findings().size();
        summary << " " << findings << " validation finding(s), " << pass << " rule(s) passed.";
    }
    return InspectionReport(InspectionTargetKind::Object, object_id, exists ? std::vector<std::string>{object_id} : std::vector<std::string>{},
                             pass, findings, summary.str());
}

InspectionReport EngineeringIntelligencePlatform::inspect_package(const std::string& package_id) {
    ++metrics_.validation_count;
    const std::vector<std::string> object_ids = knowledge_graph_engine_.graph().ids_by_package(package_id);
    const std::string session_id = validation_engine_.create_validation_session(ValidationProfile::Complete);
    const std::optional<ValidationReport> report = validation_engine_.validate_package(session_id, package_id);

    std::ostringstream summary;
    summary << "Package '" << package_id << "' owns " << object_ids.size() << " object(s).";
    std::size_t pass = 0, findings = 0;
    if (report.has_value()) {
        pass = report->statistics().rules_passed;
        findings = report->findings().size();
        summary << " " << findings << " validation finding(s), " << pass << " rule(s) passed.";
    }
    return InspectionReport(InspectionTargetKind::Package, package_id, object_ids, pass, findings, summary.str());
}

InspectionReport EngineeringIntelligencePlatform::inspect_context() {
    ++metrics_.validation_count;
    std::vector<std::string> object_ids;
    for (const auto* node : knowledge_graph_engine_.graph().all_nodes()) {
        object_ids.push_back(node->object_id);
    }
    const std::string session_id = validation_engine_.create_validation_session(ValidationProfile::Complete);
    const std::optional<ValidationReport> report = validation_engine_.validate_context(session_id);

    std::ostringstream summary;
    summary << "Engineering context has " << object_ids.size() << " object(s).";
    std::size_t pass = 0, findings = 0;
    if (report.has_value()) {
        pass = report->statistics().rules_passed;
        findings = report->findings().size();
        summary << " " << findings << " validation finding(s), " << pass << " rule(s) passed.";
    }
    return InspectionReport(InspectionTargetKind::Context, "", object_ids, pass, findings, summary.str());
}

EngineeringSummaryReport EngineeringIntelligencePlatform::engineering_summary() {
    ++metrics_.validation_count;
    const GraphStatistics stats = knowledge_graph_engine_.graph_statistics();
    const std::string session_id = validation_engine_.create_validation_session(ValidationProfile::Complete);
    const std::optional<ValidationReport> report = validation_engine_.validate_context(session_id);
    const std::size_t pass = report.has_value() ? report->statistics().rules_passed : 0;
    const std::size_t findings = report.has_value() ? report->findings().size() : 0;

    std::ostringstream summary;
    summary << stats.object_count << " object(s), " << stats.relationship_count << " relationship(s), "
            << stats.connected_component_count << " connected component(s), " << findings << " validation finding(s).";
    return EngineeringSummaryReport(stats.object_count, stats.relationship_count, stats.connected_component_count, pass,
                                     findings, summary.str());
}

EngineeringHealthReport EngineeringIntelligencePlatform::engineering_health() {
    ++metrics_.validation_count;
    const std::string session_id = validation_engine_.create_validation_session(ValidationProfile::Complete);
    const std::optional<ValidationReport> report = validation_engine_.validate_context(session_id);

    std::size_t passed = 0, warnings = 0, errors = 0, critical = 0;
    if (report.has_value()) {
        passed = report->statistics().rules_passed;
        warnings = static_cast<std::size_t>(report->warning_count());
        errors = static_cast<std::size_t>(report->error_count());
        critical = static_cast<std::size_t>(report->critical_count());
    }
    const std::size_t failed = warnings + errors + critical;
    const std::size_t total = passed + failed;
    // Deterministic arithmetic: 100 when nothing was evaluated (no
    // findings to report is not unhealthy), never a probabilistic
    // estimate.
    const double score = total == 0 ? 100.0 : (100.0 * static_cast<double>(passed) / static_cast<double>(total));

    std::ostringstream summary;
    summary << "Engineering health score: " << score << "/100 (" << passed << " passed, " << warnings << " warning(s), "
            << errors << " error(s), " << critical << " critical finding(s)).";
    return EngineeringHealthReport(score, passed, failed, warnings, errors, critical, summary.str());
}

DependencyReport EngineeringIntelligencePlatform::engineering_dependencies(const std::string& object_id) {
    ++metrics_.analysis_count;
    return analysis_engine_.analyze_dependencies(object_id);
}

ReachabilityReport EngineeringIntelligencePlatform::engineering_trace(const std::string& source_object_id,
                                                                        const std::string& target_object_id) {
    ++metrics_.analysis_count;
    return analysis_engine_.analyze_reachability(source_object_id, target_object_id);
}

std::vector<EngineeringRecommendation> EngineeringIntelligencePlatform::engineering_recommendations(
    const std::string& object_id) {
    ++metrics_.reasoning_count;
    const std::string reasoning_session_id = reasoning_engine_.create_reasoning_session(
        "engineering_recommendations(" + object_id + ")", {object_id});
    const std::optional<ReasoningReport> report = reasoning_engine_.execute_reasoning(reasoning_session_id);
    return report.has_value() ? report->recommendations() : std::vector<EngineeringRecommendation>{};
}

// ---------------------------------------------------------------------
// Workflow Engine ("Engine Pipeline": Workflow -> Service Orchestrator
// -> lower engine(s) -> KnowledgeSessionManager history + RuntimeMetrics)
// ---------------------------------------------------------------------

WorkflowResult EngineeringIntelligencePlatform::query(const std::string& session_id, QueryCategory category,
                                                        const std::string& primary_object_id) {
    const auto start = std::chrono::steady_clock::now();
    const QueryRequest request(category, primary_object_id, "", QueryFilter{});
    const EngineeringQueryResult result = query_engine_.execute_query(request);
    ++metrics_.query_count;
    const double time_ms = elapsed_ms(start);

    std::string summary = std::to_string(result.object_ids().size()) + " object(s) matched";
    sessions_.append_query(session_id, "query(" + to_string(category) + (primary_object_id.empty() ? "" : ", " + primary_object_id) +
                                            "): " + summary);
    if (!primary_object_id.empty()) sessions_.touch_active_object(session_id, primary_object_id);
    sessions_.add_execution_time(session_id, time_ms);
    metrics_.total_execution_time_ms += time_ms;
    return WorkflowResult{WorkflowKind::Query, true, summary, result.object_ids(), time_ms};
}

WorkflowResult EngineeringIntelligencePlatform::inspect(const std::string& session_id, InspectionTargetKind kind,
                                                          const std::string& target_id) {
    const auto start = std::chrono::steady_clock::now();
    InspectionReport report = kind == InspectionTargetKind::Object    ? inspect_object(target_id)
                               : kind == InspectionTargetKind::Package ? inspect_package(target_id)
                                                                         : inspect_context();
    const double time_ms = elapsed_ms(start);
    sessions_.append_analysis(session_id, "inspect(" + to_string(kind) + (target_id.empty() ? "" : ", " + target_id) + ")");
    if (!target_id.empty()) sessions_.touch_active_object(session_id, target_id);
    sessions_.add_execution_time(session_id, time_ms);
    metrics_.total_execution_time_ms += time_ms;
    return WorkflowResult{WorkflowKind::Inspect, true, report.summary(), report.object_ids(), time_ms};
}

WorkflowResult EngineeringIntelligencePlatform::validate(const std::string& session_id, const std::string& object_id,
                                                           ValidationProfile profile) {
    const auto start = std::chrono::steady_clock::now();
    const std::string validation_session_id = validation_engine_.create_validation_session(profile);
    const std::optional<ValidationReport> report = validation_engine_.validate_object(validation_session_id, object_id);
    ++metrics_.validation_count;
    const double time_ms = elapsed_ms(start);

    std::string summary = report.has_value()
                               ? std::to_string(report->findings().size()) + " finding(s) for '" + object_id + "'"
                               : "validation could not be executed";
    sessions_.append_validation(session_id, "validate(" + object_id + ", " + to_string(profile) + "): " + summary);
    sessions_.touch_active_object(session_id, object_id);
    sessions_.add_execution_time(session_id, time_ms);
    metrics_.total_execution_time_ms += time_ms;
    return WorkflowResult{WorkflowKind::Validate, report.has_value(), summary, {object_id}, time_ms};
}

WorkflowResult EngineeringIntelligencePlatform::analyze(const std::string& session_id, const std::string& object_id) {
    const auto start = std::chrono::steady_clock::now();
    const DependencyReport dependencies = engineering_dependencies(object_id);
    const double time_ms = elapsed_ms(start);

    std::string summary = std::to_string(dependencies.dependency_object_ids().size()) + " transitive dependency object(s) for '" +
                           object_id + "'";
    sessions_.append_analysis(session_id, "analyze(" + object_id + "): " + summary);
    sessions_.touch_active_object(session_id, object_id);
    sessions_.add_execution_time(session_id, time_ms);
    metrics_.total_execution_time_ms += time_ms;
    return WorkflowResult{WorkflowKind::Analyze, true, summary, dependencies.dependency_object_ids(), time_ms};
}

WorkflowResult EngineeringIntelligencePlatform::reason(const std::string& session_id, const std::string& objective,
                                                         const std::vector<std::string>& starting_objects) {
    const auto start = std::chrono::steady_clock::now();
    const std::string reasoning_session_id = reasoning_engine_.create_reasoning_session(objective, starting_objects);
    const std::optional<ReasoningReport> report = reasoning_engine_.execute_reasoning(reasoning_session_id);
    ++metrics_.reasoning_count;
    const double time_ms = elapsed_ms(start);

    std::string summary = report.has_value()
                               ? std::to_string(report->session().conclusions().size()) + " conclusion(s) for objective '" +
                                     objective + "'"
                               : "reasoning could not be executed";
    sessions_.append_reasoning(session_id, "reason(" + objective + "): " + summary);
    for (const std::string& id : starting_objects) sessions_.touch_active_object(session_id, id);
    sessions_.add_execution_time(session_id, time_ms);
    metrics_.total_execution_time_ms += time_ms;
    return WorkflowResult{WorkflowKind::Reason, report.has_value(), summary, starting_objects, time_ms};
}

WorkflowResult EngineeringIntelligencePlatform::recommend(const std::string& session_id, const std::string& object_id) {
    const auto start = std::chrono::steady_clock::now();
    const std::vector<EngineeringRecommendation> recommendations = engineering_recommendations(object_id);
    const double time_ms = elapsed_ms(start);

    std::string summary = std::to_string(recommendations.size()) + " recommendation(s) for '" + object_id + "'";
    for (const EngineeringRecommendation& recommendation : recommendations) {
        sessions_.append_recommendation(session_id, recommendation.message());
    }
    sessions_.touch_active_object(session_id, object_id);
    sessions_.add_execution_time(session_id, time_ms);
    metrics_.total_execution_time_ms += time_ms;

    std::vector<std::string> recommendation_object_ids;
    for (const EngineeringRecommendation& recommendation : recommendations) {
        recommendation_object_ids.push_back(recommendation.object_id());
    }
    return WorkflowResult{WorkflowKind::Recommend, true, summary, recommendation_object_ids, time_ms};
}

} // namespace oep::engine
