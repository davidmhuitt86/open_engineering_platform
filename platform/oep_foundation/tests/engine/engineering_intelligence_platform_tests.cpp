#include "oep/engine/engineering_intelligence_platform.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <string>

// WP-EKE-007 tests: full integration against a real FoundationRuntime +
// RuntimeService + all six lower engines, proving the Engineering
// Intelligence Platform's session lifecycle, workflow, orchestration,
// caching, and metrics contracts.

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

using oep::repository::ObjectType;
using oep::repository::RelationshipType;
using oep::engine::InspectionTargetKind;
using oep::engine::ValidationProfile;
using oep::engine::WorkflowKind;

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "b18d6fa7-ffff-44aa-a477-acef3d6fcdf8";
    metadata.repository_name = "eip-tests";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);
    return root;
}

struct Fixture {
    oep::runtime::FoundationRuntime runtime;
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service;
    oep::engine::EngineeringContext context;
    oep::engine::KnowledgeGraphEngine kge;
    oep::engine::EngineeringQueryEngine eqe;
    oep::engine::RulesEngine rules;
    oep::engine::ValidationEngine eve;
    oep::engine::AnalysisEngine analysis;
    oep::engine::ReasoningEngine eare;
    oep::engine::EngineeringIntelligencePlatform eip;

    explicit Fixture(const std::filesystem::path& root)
        : runtime("0.1.0"),
          service(oep::runtime::RuntimeContext(runtime, events)),
          context(service),
          kge(context),
          eqe(kge),
          rules(context, kge, eqe),
          eve(context, kge, eqe, rules),
          analysis(kge),
          eare(context, kge, eqe, rules, eve),
          eip(context, kge, eqe, rules, eve, analysis, eare) {
        runtime.initialize();
        runtime.open_repository(root);
    }

    void build() {
        context.load_graph();
        kge.build_graph();
    }
};

// ---------------------------------------------------------------------

void test_session_lifecycle(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "session_lifecycle"));
    fx.build();

    const std::string session_id = fx.eip.create_session();
    check(!session_id.empty(), "create_session returns a non-empty id");
    check(fx.eip.list_sessions().size() == 1, "list_sessions includes the new session");

    const auto session = fx.eip.get_session(session_id);
    check(session.has_value() && !session->closed(), "the session exists and is not closed");

    check(fx.eip.resume_session(session_id), "resume_session succeeds for an existing session");
    check(!fx.eip.resume_session("does-not-exist"), "resume_session fails for an unknown session");

    const auto cloned_id = fx.eip.clone_session(session_id);
    check(cloned_id.has_value() && *cloned_id != session_id, "clone_session returns a distinct new session id");
    check(fx.eip.list_sessions().size() == 2, "the cloned session is now also listed");

    check(fx.eip.close_session(session_id), "close_session succeeds");
    check(!fx.eip.close_session(session_id), "closing an already-closed session fails");
    const auto closed_session = fx.eip.get_session(session_id);
    check(closed_session.has_value() && closed_session->closed(), "the session is now recorded as closed");

    const auto summary = fx.eip.export_session_summary(session_id);
    check(summary.has_value() && !summary->empty(), "export_session_summary returns a non-empty summary");
    check(!fx.eip.export_session_summary("does-not-exist").has_value(), "export_session_summary fails for an unknown session");
}

void test_session_switching(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "session_switching"));
    fx.build();
    const std::string a = fx.eip.create_session();
    const std::string b = fx.eip.create_session();

    check(fx.eip.switch_session(a), "switch_session succeeds for session A");
    check(fx.eip.current_session_id() == a, "current_session_id reflects the switch");
    check(fx.eip.switch_session(b), "switch_session succeeds for session B");
    check(fx.eip.current_session_id() == b, "current_session_id reflects the second switch");
    check(!fx.eip.switch_session("does-not-exist"), "switch_session fails for an unknown session, leaving current unchanged");
    check(fx.eip.current_session_id() == b, "current_session_id is unchanged after a failed switch");
}

void test_inspect_workflow_records_history(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "inspect_workflow"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    check(a.success, "setup: one Component object");
    fx.build();

    const std::string session_id = fx.eip.create_session();
    const auto result = fx.eip.inspect(session_id, InspectionTargetKind::Object, a.object.object_id);
    check(result.kind == WorkflowKind::Inspect && result.success, "the inspect workflow succeeds");
    check(!result.summary.empty(), "the workflow result carries a summary");

    const auto session = fx.eip.get_session(session_id);
    check(session.has_value() && session->analysis_history().size() == 1, "the workflow appended one analysis-history entry");
    check(std::find(session->active_objects().begin(), session->active_objects().end(), a.object.object_id) !=
              session->active_objects().end(),
          "the inspected object is now recorded as an active object");
    check(session->statistics().total_execution_time_ms >= 0.0, "session statistics record execution time");
}

void test_validate_workflow(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "validate_workflow"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    check(a.success, "setup: one Component object");
    fx.build();

    const std::string session_id = fx.eip.create_session();
    const auto result = fx.eip.validate(session_id, a.object.object_id, ValidationProfile::Documentation);
    check(result.kind == WorkflowKind::Validate, "the validate workflow reports the correct kind");

    const auto session = fx.eip.get_session(session_id);
    check(session.has_value() && session->validation_history().size() == 1, "one validation-history entry recorded");
}

void test_analyze_and_reason_and_recommend_workflows(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "analyze_reason_recommend"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(a.success && b.success, "setup: two connected objects");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();

    const std::string session_id = fx.eip.create_session();

    const auto analyze_result = fx.eip.analyze(session_id, a.object.object_id);
    check(analyze_result.kind == WorkflowKind::Analyze && analyze_result.object_ids == std::vector<std::string>{b.object.object_id},
          "the analyze workflow reports A's one transitive dependency (B)");

    const auto reason_result = fx.eip.reason(session_id, "investigate A", {a.object.object_id});
    check(reason_result.kind == WorkflowKind::Reason && reason_result.success, "the reason workflow succeeds");

    const auto recommend_result = fx.eip.recommend(session_id, a.object.object_id);
    check(recommend_result.kind == WorkflowKind::Recommend, "the recommend workflow reports the correct kind");

    const auto session = fx.eip.get_session(session_id);
    check(session.has_value() && session->analysis_history().size() == 1 && session->reasoning_history().size() == 1,
          "each workflow appended to its own dedicated history");
}

void test_service_orchestrator_composes_multiple_engines(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "orchestrator"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "d", "au", {}));
    check(a.success, "setup: one Component object");
    fx.build();

    const auto inspection = fx.eip.inspect_object(a.object.object_id);
    check(inspection.kind() == InspectionTargetKind::Object && inspection.object_ids() == std::vector<std::string>{a.object.object_id},
          "inspect_object composes graph membership + validation into one report");

    const auto summary = fx.eip.engineering_summary();
    check(summary.object_count() == 1, "engineering_summary reports the correct object count via GraphStatistics");

    const auto health = fx.eip.engineering_health();
    check(health.health_score() >= 0.0 && health.health_score() <= 100.0, "engineering_health reports a score in [0, 100]");

    const auto dependencies = fx.eip.engineering_dependencies(a.object.object_id);
    check(dependencies.object_id() == a.object.object_id, "engineering_dependencies delegates to AnalysisEngine correctly");

    const bool recommendations_call_completed = ([&]() {
        fx.eip.engineering_recommendations(a.object.object_id);
        return true;
    })();
    check(recommendations_call_completed, "engineering_recommendations returns without throwing");
}

void test_cache_invalidation(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "cache_invalidation"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    fx.build();

    const std::string session_id = fx.eip.create_session();
    fx.eip.query(session_id, oep::engine::QueryCategory::Type, "");
    check(fx.eqe.query_cache().plan_count() > 0, "executing a query populates the shared Query Engine's cache");

    fx.eip.invalidate_caches();
    check(fx.eqe.query_cache().plan_count() == 0 && fx.eqe.query_cache().result_count() == 0,
          "invalidate_caches clears the Query Engine's cache");
}

void test_runtime_metrics_accumulate(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "runtime_metrics"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    check(a.success, "setup: one Component object");
    fx.build();

    const auto metrics_before = fx.eip.runtime_metrics();
    check(metrics_before.query_count == 0 && metrics_before.validation_count == 0, "metrics start at zero");

    const std::string session_id = fx.eip.create_session();
    fx.eip.query(session_id, oep::engine::QueryCategory::Type, "");
    fx.eip.validate(session_id, a.object.object_id, ValidationProfile::Complete);
    fx.eip.analyze(session_id, a.object.object_id);
    fx.eip.reason(session_id, "obj", {a.object.object_id});

    const auto metrics_after = fx.eip.runtime_metrics();
    check(metrics_after.query_count == 1, "runtime_metrics counts the one query executed");
    check(metrics_after.validation_count >= 1, "runtime_metrics counts at least the one validation executed");
    check(metrics_after.analysis_count >= 1, "runtime_metrics counts at least the one analysis executed");
    check(metrics_after.reasoning_count >= 1, "runtime_metrics counts at least the one reasoning run executed");
    check(metrics_after.active_session_count == 1, "runtime_metrics reports exactly 1 active session");
    check(metrics_after.total_session_count == 1, "runtime_metrics reports exactly 1 total session ever created");
}

void test_cleanup_closes_all_sessions(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "cleanup"));
    fx.build();
    fx.eip.create_session();
    fx.eip.create_session();
    check(fx.eip.runtime_metrics().active_session_count == 2, "two sessions are active before cleanup");

    fx.eip.cleanup();
    check(fx.eip.runtime_metrics().active_session_count == 0, "cleanup closes every session");
    check(fx.eip.runtime_metrics().total_session_count == 2, "cleanup does not erase session history, only closes them");
}

void test_determinism_across_independent_platforms(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "determinism"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(a.success && b.success, "setup: two connected objects");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();

    oep::engine::EngineeringIntelligencePlatform eip1(fx.context, fx.kge, fx.eqe, fx.rules, fx.eve, fx.analysis, fx.eare);
    oep::engine::EngineeringIntelligencePlatform eip2(fx.context, fx.kge, fx.eqe, fx.rules, fx.eve, fx.analysis, fx.eare);

    const auto summary1 = eip1.engineering_summary();
    const auto summary2 = eip2.engineering_summary();
    check(summary1.object_count() == summary2.object_count() && summary1.relationship_count() == summary2.relationship_count(),
          "two independent EngineeringIntelligencePlatform instances report identical engineering_summary counts");

    const auto health1 = eip1.engineering_health();
    const auto health2 = eip2.engineering_health();
    check(health1.health_score() == health2.health_score(), "engineering_health scores are identical across independent instances");

    const auto deps1 = eip1.engineering_dependencies(a.object.object_id);
    const auto deps2 = eip2.engineering_dependencies(a.object.object_id);
    check(deps1.dependency_object_ids() == deps2.dependency_object_ids(),
          "engineering_dependencies results are identical across independent instances");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_engineering_intelligence_platform_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_session_lifecycle(scratch_dir);
    test_session_switching(scratch_dir);
    test_inspect_workflow_records_history(scratch_dir);
    test_validate_workflow(scratch_dir);
    test_analyze_and_reason_and_recommend_workflows(scratch_dir);
    test_service_orchestrator_composes_multiple_engines(scratch_dir);
    test_cache_invalidation(scratch_dir);
    test_runtime_metrics_accumulate(scratch_dir);
    test_cleanup_closes_all_sessions(scratch_dir);
    test_determinism_across_independent_platforms(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All engineering_intelligence_platform tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " engineering_intelligence_platform test(s) failed.\n";
    return 1;
}
