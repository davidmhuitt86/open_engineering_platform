#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/query_planner.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <string>

// WP-EKE-003 tests: full integration against a real FoundationRuntime +
// RuntimeService + EngineeringContext + KnowledgeGraphEngine, proving
// the Engineering Query Engine's planning/execution/caching/
// determinism contracts.

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

// Object ids are real UUIDs, not the human-readable "A"/"B"/... labels
// used in these tests -- their sorted (index) order need not match
// creation order. Use this for "contains exactly these ids" checks
// where order isn't itself under test.
bool same_set(std::vector<std::string> a, std::vector<std::string> b) {
    std::sort(a.begin(), a.end());
    std::sort(b.begin(), b.end());
    return a == b;
}

using oep::repository::ObjectType;
using oep::repository::RelationshipType;

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "7d4f2b63-bbbb-4066-b033-6eac9f2d8fb4";
    metadata.repository_name = "eqe-tests";
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

    explicit Fixture(const std::filesystem::path& root)
        : runtime("0.1.0"), service(oep::runtime::RuntimeContext(runtime, events)), context(service), kge(context) {
        runtime.initialize();
        runtime.open_repository(root);
    }
};

// A -> B (DependsOn), A -> C (References), B -> D (DependsOn), all tagged/typed variously.
struct Graph {
    oep::runtime::RuntimeService::ObjectMutationResponse a, b, c, d;
    oep::runtime::RuntimeService::RelationshipMutationResponse ab, ac, bd;
};

Graph populate(oep::runtime::RuntimeService& service) {
    auto a = service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {"marine"}));
    auto b = service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "B", "", "au", {"marine"}));
    auto c = service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "C", "", "au", {"electrical"}));
    auto d = service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "D", "", "au", {}));
    auto ab = service.create_relationship(
        oep::runtime::RuntimeService::CreateRelationshipRequest(a.object.object_id, b.object.object_id,
                                                                  RelationshipType::DependsOn, "au", ""));
    auto ac = service.create_relationship(
        oep::runtime::RuntimeService::CreateRelationshipRequest(a.object.object_id, c.object.object_id,
                                                                  RelationshipType::References, "au", ""));
    auto bd = service.create_relationship(
        oep::runtime::RuntimeService::CreateRelationshipRequest(b.object.object_id, d.object.object_id,
                                                                  RelationshipType::DependsOn, "au", ""));
    return Graph{std::move(a), std::move(b), std::move(c), std::move(d), std::move(ab), std::move(ac), std::move(bd)};
}

// ---------------------------------------------------------------------

void test_planning_never_executes(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "plan_no_execute"));
    const Graph graph = populate(fx.service);
    check(fx.kge.build_graph().success, "setup: graph builds");

    oep::engine::EngineeringQueryEngine eqe(fx.kge);
    const oep::engine::QueryRequest request(oep::engine::QueryCategory::Object, graph.a.object.object_id, "", {});
    const oep::engine::QueryPlan plan = eqe.plan_query(request);

    check(plan.category() == oep::engine::QueryCategory::Object, "the plan records the correct category");
    check(!plan.indexes_used().empty(), "the plan records which indexes it will use");
    // Planning itself must not have produced a QueryResult -- verified
    // indirectly: the cache has a plan but no result yet.
    check(eqe.query_cache().plan_count() == 1 && eqe.query_cache().result_count() == 0,
          "planning caches a plan but does not execute (no result is cached yet)");
}

void test_object_query(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "object_query"));
    const Graph graph = populate(fx.service);
    fx.kge.build_graph();

    oep::engine::EngineeringQueryEngine eqe(fx.kge);
    const oep::engine::QueryRequest request(oep::engine::QueryCategory::Object, graph.a.object.object_id, "", {});
    const oep::engine::EngineeringQueryResult result = eqe.execute_query(request);
    check(result.object_ids() == std::vector<std::string>{graph.a.object.object_id}, "Object query finds exactly A");
    check(result.statistics().result_count == 1, "statistics.result_count matches");
}

void test_type_and_domain_and_relationship_queries(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "type_domain_rel"));
    const Graph graph = populate(fx.service);
    fx.kge.build_graph();
    oep::engine::EngineeringQueryEngine eqe(fx.kge);

    oep::engine::QueryFilter type_filter;
    type_filter.object_type = ObjectType::Component;
    const auto type_result =
        eqe.execute_query(oep::engine::QueryRequest(oep::engine::QueryCategory::Type, "", "", type_filter));
    check(same_set(type_result.object_ids(), {graph.a.object.object_id, graph.c.object.object_id}),
          "Type query finds A and C (both Component)");

    oep::engine::QueryFilter domain_filter;
    domain_filter.domain = "marine";
    const auto domain_result =
        eqe.execute_query(oep::engine::QueryRequest(oep::engine::QueryCategory::Domain, "", "", domain_filter));
    check(same_set(domain_result.object_ids(), {graph.a.object.object_id, graph.b.object.object_id}),
          "Domain query finds A and B (tagged 'marine')");

    oep::engine::QueryFilter rel_filter;
    rel_filter.relationship_type = RelationshipType::DependsOn;
    const auto rel_result =
        eqe.execute_query(oep::engine::QueryRequest(oep::engine::QueryCategory::Relationship, "", "", rel_filter));
    check(rel_result.object_ids().size() == 3, "Relationship query finds every object touching a DependsOn edge (A, B, D)");
}

void test_dependency_query_transitive_closure(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "dependency_query"));
    const Graph graph = populate(fx.service);
    fx.kge.build_graph();
    oep::engine::EngineeringQueryEngine eqe(fx.kge);

    const auto result = eqe.execute_query(
        oep::engine::QueryRequest(oep::engine::QueryCategory::Dependency, graph.a.object.object_id, "", {}));
    // A -> B -> D, transitively: {A, B, D}.
    check(result.object_ids().size() == 3, "Dependency query follows the transitive DependsOn closure (A, B, D)");
    check(result.statistics().traversal_depth == 2, "traversal_depth reflects the 2-hop chain A->B->D");
}

void test_neighborhood_and_path_and_reference_queries(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "neighborhood_path_reference"));
    const Graph graph = populate(fx.service);
    fx.kge.build_graph();
    oep::engine::EngineeringQueryEngine eqe(fx.kge);

    oep::engine::QueryFilter radius_one;
    radius_one.max_depth = 1;
    const auto neighborhood = eqe.execute_query(
        oep::engine::QueryRequest(oep::engine::QueryCategory::Neighborhood, graph.a.object.object_id, "", radius_one));
    check(same_set(neighborhood.object_ids(), {graph.b.object.object_id, graph.c.object.object_id}),
          "Neighborhood query (radius 1) around A finds B and C, not D");

    const auto path = eqe.execute_query(
        oep::engine::QueryRequest(oep::engine::QueryCategory::Path, graph.a.object.object_id, graph.d.object.object_id, {}));
    check(path.object_ids().size() == 3, "Path query finds the A->B->D shortest path");

    const auto reference = eqe.execute_query(
        oep::engine::QueryRequest(oep::engine::QueryCategory::Reference, graph.a.object.object_id, "", {}));
    check(reference.object_ids() == std::vector<std::string>{graph.c.object.object_id},
          "Reference query finds exactly C (A's only References edge)");
}

void test_metadata_and_composite_queries(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "metadata_composite"));
    const Graph graph = populate(fx.service);
    fx.kge.build_graph();
    oep::engine::EngineeringQueryEngine eqe(fx.kge);

    oep::engine::QueryFilter tag_filter;
    tag_filter.tags = {"marine"};
    const auto metadata_result =
        eqe.execute_query(oep::engine::QueryRequest(oep::engine::QueryCategory::Metadata, "", "", tag_filter));
    check(same_set(metadata_result.object_ids(), {graph.a.object.object_id, graph.b.object.object_id}),
          "Metadata query (tag filter) finds A and B");

    oep::engine::QueryFilter composite_filter;
    composite_filter.object_type = ObjectType::Component;
    composite_filter.domain = "marine";
    const auto composite_result =
        eqe.execute_query(oep::engine::QueryRequest(oep::engine::QueryCategory::Composite, "", "", composite_filter));
    check(composite_result.object_ids() == std::vector<std::string>{graph.a.object.object_id},
          "Composite query (Component AND 'marine') finds only A, not B (wrong type) or C (wrong domain)");
}

void test_result_caching_and_clear(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "caching"));
    const Graph graph = populate(fx.service);
    fx.kge.build_graph();
    oep::engine::EngineeringQueryEngine eqe(fx.kge);

    const oep::engine::QueryRequest request(oep::engine::QueryCategory::Object, graph.a.object.object_id, "", {});
    const auto first = eqe.execute_query(request);
    check(eqe.query_cache().result_count() == 1, "the first execution caches its result");

    const auto second = eqe.execute_query(request);
    check(first.object_ids() == second.object_ids(), "a cached result matches the original");

    eqe.clear_query_cache();
    check(eqe.query_cache().plan_count() == 0 && eqe.query_cache().result_count() == 0,
          "clear_query_cache empties both the plan and result caches");
}

void test_query_statistics_reflects_last_execution(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "statistics"));
    const Graph graph = populate(fx.service);
    fx.kge.build_graph();
    oep::engine::EngineeringQueryEngine eqe(fx.kge);

    check(eqe.query_statistics().result_count == 0, "query_statistics is zero-valued before any query executes");
    eqe.execute_query(oep::engine::QueryRequest(oep::engine::QueryCategory::Object, graph.a.object.object_id, "", {}));
    check(eqe.query_statistics().result_count == 1, "query_statistics reflects the most recently executed query");
}

void test_determinism_across_repeated_executions(const std::filesystem::path& scratch_dir) {
    Fixture fx(build_repository(scratch_dir / "determinism"));
    populate(fx.service);
    fx.kge.build_graph();

    // Two SEPARATE EngineeringQueryEngine instances (no shared cache)
    // against the same graph must produce identical plans and results.
    oep::engine::EngineeringQueryEngine eqe1(fx.kge);
    oep::engine::EngineeringQueryEngine eqe2(fx.kge);

    oep::engine::QueryFilter filter;
    filter.object_type = ObjectType::Component;
    const oep::engine::QueryRequest request(oep::engine::QueryCategory::Type, "", "", filter);

    const oep::engine::QueryPlan plan1 = eqe1.plan_query(request);
    const oep::engine::QueryPlan plan2 = eqe2.plan_query(request);
    check(plan1.execution_order() == plan2.execution_order() && plan1.estimated_cost() == plan2.estimated_cost(),
          "two independent planners produce an identical plan for the identical request");

    const auto result1 = eqe1.execute_query(plan1);
    const auto result2 = eqe2.execute_query(plan2);
    check(result1.object_ids() == result2.object_ids(), "two independent executions produce identical, ordered results");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_engineering_query_engine_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_planning_never_executes(scratch_dir);
    test_object_query(scratch_dir);
    test_type_and_domain_and_relationship_queries(scratch_dir);
    test_dependency_query_transitive_closure(scratch_dir);
    test_neighborhood_and_path_and_reference_queries(scratch_dir);
    test_metadata_and_composite_queries(scratch_dir);
    test_result_caching_and_clear(scratch_dir);
    test_query_statistics_reflects_last_execution(scratch_dir);
    test_determinism_across_repeated_executions(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All engineering_query_engine tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " engineering_query_engine test(s) failed.\n";
    return 1;
}
