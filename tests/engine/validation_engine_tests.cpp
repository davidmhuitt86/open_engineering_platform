#include "oep/engine/validation_engine.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <string>

// WP-EKE-005 tests: full integration against a real FoundationRuntime +
// RuntimeService + EngineeringContext + KnowledgeGraphEngine +
// EngineeringQueryEngine + RulesEngine, proving the Engineering
// Validation Engine's session/profile/target/determinism contracts.

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

using oep::repository::ObjectType;
using oep::engine::EngineeringRule;
using oep::engine::RuleCategory;
using oep::engine::RuleCondition;
using oep::engine::RuleConditionKind;
using oep::engine::RuleScope;
using oep::engine::RuleScopeKind;
using oep::engine::RuleSeverity;
using oep::engine::ValidationProfile;
using oep::engine::ValidationTargetKind;

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "9f6b4d85-dddd-4288-8255-8ace1b4fabd6";
    metadata.repository_name = "eve-tests";
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

    explicit Fixture(const std::filesystem::path& root)
        : runtime("0.1.0"),
          service(oep::runtime::RuntimeContext(runtime, events)),
          context(service),
          kge(context),
          eqe(kge),
          rules(context, kge, eqe),
          eve(context, kge, eqe, rules) {
        runtime.initialize();
        runtime.open_repository(root);
    }

    void build() {
        context.load_graph();
        kge.build_graph();
    }
};

EngineeringRule doc_rule(const std::string& id) {
    return EngineeringRule(id, "Components must have a description", "", RuleCategory::Documentation,
                            RuleSeverity::Warning, RuleScope{RuleScopeKind::ByObjectType, ObjectType::Component, {}, {}, {}},
                            {RuleCondition{RuleConditionKind::HasDescription, {}, {}, {}, {}}},
                            "component is missing a description", "add a description");
}

EngineeringRule structural_rule(const std::string& id) {
    return EngineeringRule(id, "All objects must have an author", "", RuleCategory::Structural, RuleSeverity::Error,
                            RuleScope{RuleScopeKind::AllObjects, {}, {}, {}, {}},
                            {RuleCondition{RuleConditionKind::HasAuthor, {}, {}, {}, {}}}, "object has no author",
                            "assign an author");
}

// ---------------------------------------------------------------------

void test_session_creation_and_object_validation(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "session_basic"));
    const auto with_desc = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "described", "au", {}));
    const auto without_desc = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(with_desc.success && without_desc.success, "setup: two Component objects");
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));

    const std::string session_id = fx.eve.create_validation_session(ValidationProfile::Documentation);
    check(!session_id.empty(), "create_validation_session returns a non-empty session id");

    const auto report = fx.eve.validate_object(session_id, without_desc.object.object_id);
    check(report.has_value(), "validate_object succeeds");
    check(report->session().target().kind() == ValidationTargetKind::SingleObject, "the session records SingleObject target kind");
    check(report->findings().size() == 1, "exactly one finding: the object lacking a description");
    check(report->findings()[0].affected_objects() == std::vector<std::string>{without_desc.object.object_id},
          "the finding names exactly the targeted object");
    check(report->error_count() == 0 && report->warning_count() == 1, "the finding is counted as a Warning (rule severity)");
}

void test_validate_object_that_satisfies_the_rule_produces_no_finding(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "target_satisfies"));
    const auto with_desc = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "described", "au", {}));
    const auto without_desc = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(with_desc.success && without_desc.success, "setup: two Component objects");
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));

    const std::string session_id = fx.eve.create_validation_session(ValidationProfile::Documentation);
    // Validating the OTHER object (the one that DOES have a
    // description) must report no finding, even though the rule fails
    // overall (because of the other object).
    const auto report = fx.eve.validate_object(session_id, with_desc.object.object_id);
    check(report.has_value() && report->findings().empty(),
          "validating an object that individually satisfies the rule produces no finding, "
          "even though the rule fails for a DIFFERENT object in the graph");
    check(report->pass_count() == 1, "the rule counts as passed for this specific target");
}

void test_profile_selects_only_matching_category(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "profile_selection"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "", {}));
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));         // Documentation category
    fx.rules.register_rule(structural_rule("STRUCT_RULE")); // Structural category

    const std::string session_id = fx.eve.create_validation_session(ValidationProfile::Documentation);
    const auto report = fx.eve.validate_context(session_id);
    check(report.has_value(), "validate_context succeeds");
    check(report->session().active_rule_ids() == std::vector<std::string>{"DOC_RULE"},
          "the Documentation profile activates only the Documentation-category rule, not the Structural one");
}

void test_complete_profile_runs_every_category(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "complete_profile"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "", {}));
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));
    fx.rules.register_rule(structural_rule("STRUCT_RULE"));

    const std::string session_id = fx.eve.create_validation_session(ValidationProfile::Complete);
    const auto report = fx.eve.validate_context(session_id);
    check(report.has_value() && report->session().active_rule_ids().size() == 2,
          "the Complete profile activates every enabled rule regardless of category");
}

void test_validate_package(const std::filesystem::path& scratch_dir) {
    // No installed package in this fixture (no .oep archive machinery
    // here) -- validate_package against a package with zero owned
    // objects should still succeed with an empty target, not error.
    Fixture fx(build_repository(scratch_dir / "validate_package"));
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));
    const std::string session_id = fx.eve.create_validation_session(ValidationProfile::Documentation);
    const auto report = fx.eve.validate_package(session_id, "com.example.nonexistent");
    check(report.has_value(), "validate_package succeeds even for a package owning no objects");
    check(report->session().target().kind() == ValidationTargetKind::Package, "the session records Package target kind");
    check(report->findings().empty(), "no findings when the target's object set is empty");
}

void test_validate_query_result(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "validate_query_result"));
    const auto without_desc =
        fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(without_desc.success, "setup: one Component object with no description");
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));

    oep::engine::QueryFilter type_filter;
    type_filter.object_type = ObjectType::Component;
    const auto query_result =
        fx.eqe.execute_query(oep::engine::QueryRequest(oep::engine::QueryCategory::Type, "", "", type_filter));

    const std::string session_id = fx.eve.create_validation_session(ValidationProfile::Documentation);
    const auto report = fx.eve.validate_query_result(session_id, query_result);
    check(report.has_value() && report->session().target().kind() == ValidationTargetKind::QueryResult,
          "validate_query_result records QueryResult target kind");
    check(report->findings().size() == 1, "the query-result-scoped validation finds the one object missing a description");
}

void test_report_and_statistics_retrieval(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "report_retrieval"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "d", "au", {}));
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));

    const std::string session_id = fx.eve.create_validation_session(ValidationProfile::Documentation);
    check(!fx.eve.validation_report(session_id).has_value(), "no report exists before any validate_* call");

    fx.eve.validate_context(session_id);
    const auto report = fx.eve.validation_report(session_id);
    const auto stats = fx.eve.validation_statistics(session_id);
    check(report.has_value() && stats.has_value(), "validation_report/validation_statistics retrieve the last run");
    check(stats->rules_evaluated == 1, "statistics reflect the one evaluated rule");

    check(!fx.eve.validation_report("does-not-exist").has_value(), "an unknown session_id returns nullopt, not an error");
}

void test_determinism_across_independent_engines(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "determinism"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    fx.build();
    fx.rules.register_rule(doc_rule("DOC_RULE"));

    oep::engine::ValidationEngine eve1(fx.context, fx.kge, fx.eqe, fx.rules);
    oep::engine::ValidationEngine eve2(fx.context, fx.kge, fx.eqe, fx.rules);
    const std::string session1 = eve1.create_validation_session(ValidationProfile::Documentation);
    const std::string session2 = eve2.create_validation_session(ValidationProfile::Documentation);

    const auto report1 = eve1.validate_context(session1);
    const auto report2 = eve2.validate_context(session2);
    check(report1.has_value() && report2.has_value(), "both validations succeed");
    check(report1->findings().size() == report2->findings().size() &&
              report1->pass_count() == report2->pass_count() && report1->warning_count() == report2->warning_count(),
          "two independent ValidationEngine instances against the same graph/rules produce identical report shapes");
    if (!report1->findings().empty()) {
        check(report1->findings()[0].affected_objects() == report2->findings()[0].affected_objects(),
              "finding contents are identical across independent runs");
    }
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_validation_engine_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_session_creation_and_object_validation(scratch_dir);
    test_validate_object_that_satisfies_the_rule_produces_no_finding(scratch_dir);
    test_profile_selects_only_matching_category(scratch_dir);
    test_complete_profile_runs_every_category(scratch_dir);
    test_validate_package(scratch_dir);
    test_validate_query_result(scratch_dir);
    test_report_and_statistics_retrieval(scratch_dir);
    test_determinism_across_independent_engines(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All validation_engine tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " validation_engine test(s) failed.\n";
    return 1;
}
