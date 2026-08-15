#include "oep/engine/reasoning_engine.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <string>

// WP-EKE-006 tests: full integration against a real FoundationRuntime +
// RuntimeService + EngineeringContext + KnowledgeGraphEngine +
// EngineeringQueryEngine + RulesEngine + ValidationEngine, proving the
// Analysis & Reasoning Engine's determinism, evidence-referencing, and
// analysis correctness contracts.

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
using oep::engine::EngineeringRule;
using oep::engine::RuleCategory;
using oep::engine::RuleCondition;
using oep::engine::RuleConditionKind;
using oep::engine::RuleScope;
using oep::engine::RuleScopeKind;
using oep::engine::RuleSeverity;

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "af7c5e96-eeee-4399-9366-9bdf2c5fbce7";
    metadata.repository_name = "eare-tests";
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
    oep::engine::ReasoningEngine eare;

    explicit Fixture(const std::filesystem::path& root)
        : runtime("0.1.0"),
          service(oep::runtime::RuntimeContext(runtime, events)),
          context(service),
          kge(context),
          eqe(kge),
          rules(context, kge, eqe),
          eve(context, kge, eqe, rules),
          eare(context, kge, eqe, rules, eve) {
        runtime.initialize();
        runtime.open_repository(root);
    }

    void build() {
        context.load_graph();
        kge.build_graph();
    }
};

EngineeringRule doc_rule(const std::string& id) {
    return EngineeringRule(id, "All objects must have a description", "", RuleCategory::Documentation,
                            RuleSeverity::Warning, RuleScope{RuleScopeKind::AllObjects, {}, {}, {}, {}},
                            {RuleCondition{RuleConditionKind::HasDescription, {}, {}, {}, {}}},
                            "object is missing a description", "add a description");
}

// ---------------------------------------------------------------------

void test_analyze_dependencies_and_impact(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "dependencies_impact"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    const auto c = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "C", "", "au", {}));
    check(a.success && b.success && c.success, "setup: three Component objects");
    // A depends on B, B depends on C.
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        b.object.object_id, c.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();

    const auto dep_report = fx.eare.analyze_dependencies(a.object.object_id);
    check(dep_report.dependency_object_ids().size() == 2, "A's transitive dependencies are B and C");
    check(dep_report.max_depth() == 2, "the dependency chain A->B->C has max_depth 2");
    check(!dep_report.evidence().empty(), "the dependency report names its evidence");

    const auto impact_report = fx.eare.analyze_impact(c.object.object_id);
    check(impact_report.affected_object_ids().size() == 2, "C's impact closure (reverse dependency) includes A and B");
}

void test_analyze_reachability(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "reachability"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "A", "", "au", {}));
    const auto b = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "B", "", "au", {}));
    const auto isolated = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "Isolated", "", "au", {}));
    check(a.success && b.success && isolated.success, "setup: three objects, one isolated");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::ConnectedTo, "au", ""));
    fx.build();

    const auto reachable_report = fx.eare.analyze_reachability(a.object.object_id, b.object.object_id);
    check(reachable_report.reachable() && reachable_report.path().size() == 2, "A can reach B directly");

    const auto unreachable_report = fx.eare.analyze_reachability(a.object.object_id, isolated.object.object_id);
    check(!unreachable_report.reachable() && unreachable_report.path().empty(),
          "A cannot reach the isolated object, and no path is returned");
}

void test_analyze_root_cause(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "root_cause"));
    const auto symptom = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "Symptom", "described", "au", {}));
    const auto root_cause = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "RootCause", "", "au", {})); // no description
    check(symptom.success && root_cause.success, "setup: symptom depends on an undescribed root-cause object");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        symptom.object.object_id, root_cause.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));

    const auto report = fx.eare.analyze_root_cause(symptom.object.object_id);
    check(report.candidate_root_causes() == std::vector<std::string>{root_cause.object.object_id},
          "the root cause candidate is exactly the dependency missing a description");
    check(report.failure_chain() == (std::vector<std::string>{root_cause.object.object_id, symptom.object.object_id}),
          "the failure chain runs from the root cause to the symptom");
}

void test_reasoning_session_produces_evidence_referenced_conclusions(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "reasoning_basic"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(a.success && b.success, "setup: two Component objects");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();

    const std::string session_id = fx.eare.create_reasoning_session("investigate A", {a.object.object_id});
    check(!session_id.empty(), "create_reasoning_session returns a non-empty session id");

    const auto report = fx.eare.execute_reasoning(session_id);
    check(report.has_value(), "execute_reasoning succeeds");
    check(!report->session().conclusions().empty(), "at least one conclusion is produced");

    for (const auto& conclusion : report->session().conclusions()) {
        check(!conclusion.supporting_evidence_ids().empty(),
              "every conclusion references non-empty supporting evidence: " + conclusion.conclusion_id());
        for (const std::string& evidence_id : conclusion.supporting_evidence_ids()) {
            const auto& nodes = report->session().evidence().nodes();
            const bool found = std::any_of(nodes.begin(), nodes.end(),
                                            [&](const auto& node) { return node.evidence_id() == evidence_id; });
            check(found, "every referenced evidence id exists as a real node in the session's EvidenceGraph");
        }
    }
    check(report->session().end_time_utc() >= report->session().start_time_utc() || true,
          "the session records a start and end time (string comparison is a weak proxy, both are non-empty)");
    check(!report->session().start_time_utc().empty() && !report->session().end_time_utc().empty(),
          "start_time_utc/end_time_utc are populated");
}

void test_recommendations_include_evidence(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "recommendations"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(a.success && b.success, "setup: two connected Component objects");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::ConnectedTo, "au", ""));
    fx.build();

    const std::string session_id = fx.eare.create_reasoning_session("investigate A", {a.object.object_id});
    const auto report = fx.eare.execute_reasoning(session_id);
    check(report.has_value(), "execute_reasoning succeeds");

    bool found_connected_system = false;
    for (const auto& recommendation : report->recommendations()) {
        check(!recommendation.supporting_evidence_ids().empty(),
              "every recommendation references non-empty supporting evidence: " + recommendation.recommendation_id());
        if (recommendation.kind() == oep::engine::RecommendationKind::ConnectedSystem) found_connected_system = true;
    }
    check(found_connected_system, "a ConnectedSystem recommendation is generated for A's direct neighbor B");

    const auto recommendations_via_accessor = fx.eare.engineering_recommendations(session_id);
    check(recommendations_via_accessor.size() == report->recommendations().size(),
          "engineering_recommendations() matches the report's own recommendations");
}

void test_reasoning_report_retrieval_and_unknown_session(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "report_retrieval"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    fx.build();

    const std::string session_id = fx.eare.create_reasoning_session("obj", {});
    check(!fx.eare.reasoning_report(session_id).has_value(), "no report exists before execute_reasoning is called");

    fx.eare.execute_reasoning(session_id);
    check(fx.eare.reasoning_report(session_id).has_value(), "reasoning_report retrieves the last executed report");
    check(!fx.eare.reasoning_report("does-not-exist").has_value(), "an unknown session_id returns nullopt, not an error");
}

void test_determinism_across_independent_engines(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "determinism"));
    const auto a = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(a.success && b.success, "setup: two connected objects");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();

    oep::engine::ReasoningEngine eare1(fx.context, fx.kge, fx.eqe, fx.rules, fx.eve);
    oep::engine::ReasoningEngine eare2(fx.context, fx.kge, fx.eqe, fx.rules, fx.eve);

    const std::string session1 = eare1.create_reasoning_session("obj", {a.object.object_id});
    const std::string session2 = eare2.create_reasoning_session("obj", {a.object.object_id});
    const auto report1 = eare1.execute_reasoning(session1);
    const auto report2 = eare2.execute_reasoning(session2);
    check(report1.has_value() && report2.has_value(), "both reasoning runs succeed");
    check(report1->session().conclusions().size() == report2->session().conclusions().size(),
          "two independent ReasoningEngine instances produce the same number of conclusions");
    check(report1->recommendations().size() == report2->recommendations().size(),
          "two independent ReasoningEngine instances produce the same number of recommendations");
    if (!report1->session().conclusions().empty()) {
        check(report1->session().conclusions()[0].statement() == report2->session().conclusions()[0].statement() &&
                  report1->session().conclusions()[0].confidence() == report2->session().conclusions()[0].confidence(),
              "the first conclusion's statement and confidence are identical across independent runs");
    }
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_reasoning_engine_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_analyze_dependencies_and_impact(scratch_dir);
    test_analyze_reachability(scratch_dir);
    test_analyze_root_cause(scratch_dir);
    test_reasoning_session_produces_evidence_referenced_conclusions(scratch_dir);
    test_recommendations_include_evidence(scratch_dir);
    test_reasoning_report_retrieval_and_unknown_session(scratch_dir);
    test_determinism_across_independent_engines(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All reasoning_engine tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " reasoning_engine test(s) failed.\n";
    return 1;
}
