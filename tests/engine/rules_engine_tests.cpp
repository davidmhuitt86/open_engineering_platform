#include "oep/engine/rules_engine.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <string>

// WP-EKE-004 tests: full integration against a real FoundationRuntime +
// RuntimeService + EngineeringContext + KnowledgeGraphEngine +
// EngineeringQueryEngine, proving the Engineering Rules Engine's
// registration/evaluation/determinism contracts. Rules are constructed
// entirely as DATA (EngineeringRule values) -- no rule-specific C++
// code exists anywhere in this test file's production counterpart.

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
using oep::engine::RuleEvaluationStatus;
using oep::engine::RuleScope;
using oep::engine::RuleScopeKind;
using oep::engine::RuleSeverity;

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "8e5a3c74-cccc-4177-8144-7fbd0a3e9ac5";
    metadata.repository_name = "ere-tests";
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

    explicit Fixture(const std::filesystem::path& root)
        : runtime("0.1.0"),
          service(oep::runtime::RuntimeContext(runtime, events)),
          context(service),
          kge(context),
          eqe(kge) {
        runtime.initialize();
        runtime.open_repository(root);
    }

    void build() {
        context.load_graph();
        kge.build_graph();
    }
};

EngineeringRule rule_requires_description(const std::string& id) {
    return EngineeringRule(id, "Components must have a description", "", RuleCategory::Documentation,
                            RuleSeverity::Warning, RuleScope{RuleScopeKind::ByObjectType, ObjectType::Component, {}, {}, {}},
                            {RuleCondition{RuleConditionKind::HasDescription, {}, {}, {}, {}}},
                            "component is missing a description", "add a description");
}

EngineeringRule rule_requires_dependency(const std::string& id) {
    RuleCondition condition;
    condition.kind = RuleConditionKind::RequiresRelationship;
    condition.relationship_type = RelationshipType::DependsOn;
    condition.direction = true; // outgoing
    return EngineeringRule(id, "Components must declare a dependency", "", RuleCategory::Dependency, RuleSeverity::Error,
                            RuleScope{RuleScopeKind::ByObjectType, ObjectType::Component, {}, {}, {}}, {condition},
                            "component has no outgoing DependsOn relationship", "add a dependency relationship");
}

EngineeringRule rule_no_cycles(const std::string& id) {
    RuleCondition condition;
    condition.kind = RuleConditionKind::NoCycles;
    condition.relationship_type = RelationshipType::DependsOn;
    return EngineeringRule(id, "No dependency cycles", "", RuleCategory::Dependency, RuleSeverity::Critical,
                            RuleScope{RuleScopeKind::AllObjects, {}, {}, {}, {}}, {condition},
                            "a dependency cycle was detected", "break the cycle");
}

// ---------------------------------------------------------------------

void test_registry_register_enable_disable_remove(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "registry_basic"));
    fx.build();
    oep::engine::RulesEngine engine(fx.context, fx.kge, fx.eqe);

    check(engine.register_rule(rule_requires_description("R1")), "registering a new rule succeeds");
    check(!engine.register_rule(rule_requires_description("R1")), "registering a duplicate rule_id fails");
    check(engine.enabled_rules().size() == 1, "the rule starts enabled");

    check(engine.disable_rule("R1"), "disable_rule succeeds for a registered rule");
    check(engine.enabled_rules().empty() && engine.disabled_rules().size() == 1, "the rule moved to disabled");
    check(!engine.disable_rule("does-not-exist"), "disable_rule fails for an unregistered id");

    check(engine.enable_rule("R1"), "enable_rule succeeds");
    check(engine.enabled_rules().size() == 1, "the rule is enabled again");

    check(engine.remove_rule("R1"), "remove_rule succeeds");
    check(engine.all_rules().empty(), "the rule is gone");
    check(!engine.remove_rule("R1"), "removing an already-removed rule fails");
}

void test_evaluation_passed_and_failed(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "eval_pass_fail"));
    const auto with_description = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "WithDesc", "has a description", "au", {}));
    const auto without_description = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "NoDesc", "", "au", {}));
    check(with_description.success && without_description.success, "setup: two Component objects are created");
    fx.build();

    oep::engine::RulesEngine engine(fx.context, fx.kge, fx.eqe);
    engine.register_rule(rule_requires_description("DESC_RULE"));

    const auto result = engine.evaluate_rule("DESC_RULE");
    check(result.has_value(), "evaluate_rule finds the registered rule");
    check(result->status() == RuleEvaluationStatus::Failed, "the rule fails because one Component lacks a description");
    check(result->affected_objects() == std::vector<std::string>{without_description.object.object_id},
          "affected_objects names exactly the object missing a description");
    check(!result->diagnostics().empty(), "diagnostics are populated for the failure");
}

void test_evaluation_passed_when_all_objects_satisfy(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "eval_all_pass"));
    fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "described", "au", {}));
    fx.build();

    oep::engine::RulesEngine engine(fx.context, fx.kge, fx.eqe);
    engine.register_rule(rule_requires_description("DESC_RULE"));
    const auto result = engine.evaluate_rule("DESC_RULE");
    check(result.has_value() && result->status() == RuleEvaluationStatus::Passed,
          "the rule passes when every scoped object satisfies it");
    check(result->affected_objects().empty(), "no affected objects on a passing rule");
}

void test_evaluation_not_applicable_when_scope_is_empty(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "eval_not_applicable"));
    // No Component objects at all -- only a Document.
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "D", "", "au", {}));
    fx.build();

    oep::engine::RulesEngine engine(fx.context, fx.kge, fx.eqe);
    engine.register_rule(rule_requires_description("DESC_RULE"));
    const auto result = engine.evaluate_rule("DESC_RULE");
    check(result.has_value() && result->status() == RuleEvaluationStatus::NotApplicable,
          "a rule scoped to a type with zero matching objects reports NotApplicable");
}

void test_relationship_condition_and_direction(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "relationship_condition"));
    const auto a = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    check(a.success && b.success, "setup: two Component objects");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();

    oep::engine::RulesEngine engine(fx.context, fx.kge, fx.eqe);
    engine.register_rule(rule_requires_dependency("DEP_RULE"));
    const auto result = engine.evaluate_rule("DEP_RULE");
    check(result.has_value() && result->status() == RuleEvaluationStatus::Failed,
          "the rule fails because B has no OUTGOING DependsOn (only A does)");
    check(result->affected_objects() == std::vector<std::string>{b.object.object_id},
          "only B (the object with no outgoing dependency) is affected, not A");
}

void test_no_cycles_graph_level_condition(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "no_cycles"));
    const auto a = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    const auto c = fx.service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "C", "", "au", {}));
    check(a.success && b.success && c.success, "setup: three Component objects");
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        b.object.object_id, c.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        c.object.object_id, a.object.object_id, RelationshipType::DependsOn, "au", ""));
    fx.build();

    oep::engine::RulesEngine engine(fx.context, fx.kge, fx.eqe);
    engine.register_rule(rule_no_cycles("CYCLE_RULE"));
    const auto result = engine.evaluate_rule("CYCLE_RULE");
    check(result.has_value() && result->status() == RuleEvaluationStatus::Failed,
          "the NoCycles rule fails on a A->B->C->A dependency cycle");
    bool found_cycle_diagnostic = false;
    for (const auto& diagnostic : result->diagnostics()) {
        if (diagnostic.detail.find("cycle") != std::string::npos) found_cycle_diagnostic = true;
    }
    check(found_cycle_diagnostic, "a cycle diagnostic is reported");
}

void test_evaluate_all_only_covers_enabled_rules(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "evaluate_all"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    fx.build();

    oep::engine::RulesEngine engine(fx.context, fx.kge, fx.eqe);
    engine.register_rule(rule_requires_description("R1"));
    engine.register_rule(rule_requires_dependency("R2"));
    engine.disable_rule("R2");

    const auto results = engine.evaluate_all();
    check(results.size() == 1, "evaluate_all only evaluates the enabled rule, not the disabled one");
    check(results[0].rule().rule_id() == "R1", "the evaluated rule is R1");

    // An explicit evaluate_rule() call, however, ignores the disabled flag.
    const auto explicit_result = engine.evaluate_rule("R2");
    check(explicit_result.has_value(), "evaluate_rule() still works on a disabled rule when called explicitly");
}

void test_determinism_across_independent_engines(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "determinism"));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    fx.service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "B", "", "au", {}));
    fx.build();

    oep::engine::RulesEngine engine1(fx.context, fx.kge, fx.eqe);
    oep::engine::RulesEngine engine2(fx.context, fx.kge, fx.eqe);
    engine1.register_rule(rule_requires_description("R1"));
    engine2.register_rule(rule_requires_description("R1"));

    const auto result1 = engine1.evaluate_rule("R1");
    const auto result2 = engine2.evaluate_rule("R1");
    check(result1.has_value() && result2.has_value(), "both evaluations succeed");
    check(result1->status() == result2->status() && result1->affected_objects() == result2->affected_objects(),
          "two independent RulesEngine instances against the same graph produce identical evaluation results");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_rules_engine_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_registry_register_enable_disable_remove(scratch_dir);
    test_evaluation_passed_and_failed(scratch_dir);
    test_evaluation_passed_when_all_objects_satisfy(scratch_dir);
    test_evaluation_not_applicable_when_scope_is_empty(scratch_dir);
    test_relationship_condition_and_direction(scratch_dir);
    test_no_cycles_graph_level_condition(scratch_dir);
    test_evaluate_all_only_covers_enabled_rules(scratch_dir);
    test_determinism_across_independent_engines(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All rules_engine tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " rules_engine test(s) failed.\n";
    return 1;
}
