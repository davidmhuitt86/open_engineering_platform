#include "oep/engine/engineering_context.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <filesystem>
#include <iostream>
#include <string>

// Full end-to-end integration tests: a real FoundationRuntime + a real
// RuntimeService, feeding a real EngineeringContext -- proving the
// Engineering Knowledge Runtime genuinely consumes Foundation
// EXCLUSIVELY through RuntimeService (EngineeringContext never holds a
// FoundationRuntime reference at all, only a RuntimeService&).

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "5b2d0f31-9999-4e44-9f11-4c8a7e0b6d92";
    metadata.repository_name = "engine-tests";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);
    return root;
}

using oep::repository::ObjectType;
using oep::repository::RelationshipType;

void test_load_object_is_lazy_and_reads_only_through_runtime_service(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "lazy_load");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto created = service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "Widget", "d", "a", {}));
    check(created.success, "setup: create_object succeeds");

    oep::engine::EngineeringContext context(service);
    const oep::engine::ObjectLoader::LoadObjectResult loaded = context.load_object(created.object.object_id);
    check(loaded.success && loaded.found && loaded.object.name == "Widget",
          "load_object lazily fetches a single object through RuntimeService");

    const oep::engine::ObjectLoader::LoadObjectResult missing = context.load_object("does-not-exist");
    check(missing.success && !missing.found, "load_object reports found == false for a nonexistent id, not an error");

    runtime.shutdown();
}

void test_load_graph_hydrates_and_subsequent_queries_work(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "hydration");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto a =
        service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    const auto b =
        service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "B", "", "au", {}));
    check(a.success && b.success, "setup: two objects are created");
    const auto rel = service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""));
    check(rel.success, "setup: a DependsOn relationship is created");

    oep::engine::EngineeringContext context(service);
    check(!context.graph_loaded(), "the graph is not loaded before load_graph() is called");

    const oep::engine::EngineeringContext::LoadGraphResult hydrated = context.load_graph();
    check(hydrated.success && hydrated.objects_loaded == 2 && hydrated.relationships_loaded == 1,
          "load_graph hydrates the full graph via RuntimeService: " + hydrated.error);
    check(context.graph_loaded(), "graph_loaded() is true after a successful load_graph()");

    oep::engine::EngineeringContext::QueryRequest by_type;
    by_type.kind = oep::engine::EngineeringContext::QueryKind::ByType;
    by_type.object_type = ObjectType::Component;
    check(context.query(by_type).object_ids == std::vector<std::string>{a.object.object_id},
          "query(ByType) finds the Component object after hydration");

    const oep::engine::RelatedObjectsResult related = context.related_objects(a.object.object_id);
    check(related.success && related.object_ids == std::vector<std::string>{b.object.object_id},
          "related_objects(A) reports B");

    const oep::engine::EngineeringContext::DependencyGraphResult deps = context.dependency_graph(a.object.object_id);
    check(deps.success && deps.object_ids.size() == 2, "dependency_graph(A) includes A and its dependency B");

    const oep::engine::TraversalResult traversal = context.traverse(a.object.object_id);
    check(traversal.success && traversal.object_ids.size() == 2, "traverse(A) visits both A and B");

    runtime.shutdown();
}

void test_queries_before_load_graph_report_a_clear_error(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "not_loaded_yet");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    oep::engine::EngineeringContext context(service);
    oep::engine::EngineeringContext::QueryRequest request;
    request.kind = oep::engine::EngineeringContext::QueryKind::ById;
    request.object_id = "anything";
    const oep::engine::QueryResult result = context.query(request);
    check(!result.success && result.error.find("load_graph") != std::string::npos,
          "querying before load_graph() reports a clear, actionable error rather than silently returning empty results");

    runtime.shutdown();
}

void test_engine_never_touches_repository_storage_directly(const std::filesystem::path& scratch_dir) {
    // Not a runtime-checkable assertion (that's an architectural
    // property, verified at compile/review time by
    // EngineeringContext/ObjectLoader only ever holding a
    // RuntimeService&) -- this test instead proves the OBSERVABLE
    // consequence: everything the Engine sees is reachable purely by
    // constructing an EngineeringContext from a RuntimeService, with no
    // other Foundation type in scope.
    const std::filesystem::path root = build_repository(scratch_dir / "no_direct_storage_access");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto created =
        service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "Only", "", "a", {}));

    oep::engine::EngineeringContext context(service);
    const oep::engine::EngineeringContext::LoadGraphResult loaded = context.load_graph();
    check(loaded.success && loaded.objects_loaded == 1,
          "the Engine sees repository content purely through the RuntimeService it was constructed with");

    runtime.shutdown();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_engineering_context_integration_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_load_object_is_lazy_and_reads_only_through_runtime_service(scratch_dir);
    test_load_graph_hydrates_and_subsequent_queries_work(scratch_dir);
    test_queries_before_load_graph_report_a_clear_error(scratch_dir);
    test_engine_never_touches_repository_storage_directly(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All engineering_context integration tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " engineering_context integration test(s) failed.\n";
    return 1;
}
