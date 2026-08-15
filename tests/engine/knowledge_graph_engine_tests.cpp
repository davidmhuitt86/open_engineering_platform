#include "oep/engine/graph_serialization.hpp"
#include "oep/engine/graph_validator.hpp"
#include "oep/engine/knowledge_graph.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"

#include "oep/repository/metadata.hpp"
#include "oep/runtime/foundation_runtime.hpp"
#include "oep/runtime/runtime_context.hpp"

#include <filesystem>
#include <iostream>
#include <string>

// WP-EKE-002 tests: pure KnowledgeGraph/GraphValidator/GraphAlgorithms/
// GraphStatistics/GraphSerialization unit tests (no Foundation), plus
// full KnowledgeGraphEngine integration tests against a real
// FoundationRuntime+RuntimeService+EngineeringContext, proving
// KnowledgeGraphEngine consumes EngineeringContext ONLY.

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

oep::engine::KnowledgeGraphNode make_node(const std::string& id, ObjectType type, std::vector<std::string> domains = {},
                                           std::string package_id = "", std::string publisher_id = "") {
    oep::engine::KnowledgeGraphNode node;
    node.object_id = id;
    node.object_type = type;
    node.name = id;
    node.domains = std::move(domains);
    node.package_id = std::move(package_id);
    node.publisher_id = std::move(publisher_id);
    return node;
}

oep::engine::KnowledgeGraphEdge make_edge(const std::string& id, const std::string& source, const std::string& target,
                                           RelationshipType type) {
    return oep::engine::KnowledgeGraphEdge{id, source, target, type};
}

// ---------------------------------------------------------------------
// KnowledgeGraph: construction, indexes, incremental updates
// ---------------------------------------------------------------------

void test_knowledge_graph_indexes() {
    std::vector<oep::engine::KnowledgeGraphNode> nodes = {
        make_node("A", ObjectType::Component, {"electrical"}, "pkg.a", "pub.1"),
        make_node("B", ObjectType::Document, {"electrical", "marine"}, "pkg.a", "pub.1"),
        make_node("C", ObjectType::Component, {"marine"}, "pkg.b", "pub.2"),
    };
    std::vector<oep::engine::KnowledgeGraphEdge> edges = {make_edge("r1", "A", "B", RelationshipType::References)};

    oep::engine::KnowledgeGraph graph;
    graph.build(nodes, edges);

    check(graph.node_count() == 3 && graph.edge_count() == 1, "graph has correct node/edge counts");
    check(graph.ids_by_object_type(ObjectType::Component) == (std::vector<std::string>{"A", "C"}), "index by object type");
    check(graph.ids_by_domain("marine") == (std::vector<std::string>{"B", "C"}), "index by domain");
    check(graph.ids_by_publisher("pub.1") == (std::vector<std::string>{"A", "B"}), "index by publisher");
    check(graph.ids_by_package("pkg.b") == std::vector<std::string>{"C"}, "index by package");
    check(graph.ids_by_relationship_type(RelationshipType::References) == (std::vector<std::string>{"A", "B"}),
          "index by relationship type");
    check(graph.outgoing_neighbors("A") == std::vector<std::string>{"B"}, "outgoing direction index");
    check(graph.incoming_neighbors("B") == std::vector<std::string>{"A"}, "incoming direction index");
}

void test_knowledge_graph_incremental_updates_stay_synchronized() {
    oep::engine::KnowledgeGraph graph;
    graph.build({make_node("A", ObjectType::Component, {"electrical"})}, {});

    graph.add_object(make_node("B", ObjectType::Document, {"marine"}, "pkg.x"));
    check(graph.node_count() == 2, "add_object grows the graph without a full rebuild");
    check(graph.ids_by_package("pkg.x") == std::vector<std::string>{"B"}, "add_object keeps the package index synchronized");

    graph.add_relationship(make_edge("r1", "A", "B", RelationshipType::DependsOn));
    check(graph.edge_count() == 1 && graph.ids_by_relationship_type(RelationshipType::DependsOn).size() == 2,
          "add_relationship keeps the relationship-type index synchronized");

    check(graph.remove_relationship("r1"), "remove_relationship succeeds for an existing relationship");
    check(graph.edge_count() == 0, "the relationship is actually gone");
    check(!graph.remove_relationship("r1"), "removing an already-removed relationship reports false, not an error");

    check(graph.remove_object("A"), "remove_object succeeds");
    check(graph.node_count() == 1 && !graph.contains("A"), "the object is actually gone");
}

// ---------------------------------------------------------------------
// GraphValidator: deterministic conflict/issue detection
// ---------------------------------------------------------------------

void test_validator_detects_every_issue_kind_deterministically() {
    std::vector<oep::engine::KnowledgeGraphNode> nodes = {
        make_node("A", ObjectType::Document), make_node("B", ObjectType::Document),
    };
    std::vector<oep::engine::KnowledgeGraphEdge> edges = {
        make_edge("r1", "A", "does-not-exist", RelationshipType::References), // MissingEndpoint
        make_edge("r2", "A", "A", RelationshipType::ConnectedTo),             // SelfReference
        make_edge("r3", "A", "B", RelationshipType::References),
        make_edge("r3", "A", "B", RelationshipType::References),              // DuplicateRelationship (same id as r3)
    };
    const oep::engine::GraphValidationReport report1 = oep::engine::validate_graph(nodes, edges);
    const oep::engine::GraphValidationReport report2 = oep::engine::validate_graph(nodes, edges);

    check(!report1.valid(), "a report with issues is not valid");
    check(report1.issues().size() == report2.issues().size(), "validating the same input twice reports the same issue count");
    for (std::size_t i = 0; i < report1.issues().size(); ++i) {
        check(report1.issues()[i].kind == report2.issues()[i].kind &&
                  report1.issues()[i].relationship_id == report2.issues()[i].relationship_id,
              "validation is deterministic: issue " + std::to_string(i) + " matches across repeated runs");
    }

    bool found_missing = false, found_self = false, found_duplicate = false;
    for (const oep::engine::GraphIssue& issue : report1.issues()) {
        if (issue.kind == oep::engine::GraphIssueKind::MissingEndpoint) found_missing = true;
        if (issue.kind == oep::engine::GraphIssueKind::SelfReference) found_self = true;
        if (issue.kind == oep::engine::GraphIssueKind::DuplicateRelationship) found_duplicate = true;
    }
    check(found_missing, "MissingEndpoint is detected");
    check(found_self, "SelfReference is detected");
    check(found_duplicate, "DuplicateRelationship is detected");
}

void test_validator_detects_cycles() {
    std::vector<oep::engine::KnowledgeGraphNode> nodes = {
        make_node("A", ObjectType::Document), make_node("B", ObjectType::Document), make_node("C", ObjectType::Document),
    };
    std::vector<oep::engine::KnowledgeGraphEdge> edges = {
        make_edge("r1", "A", "B", RelationshipType::DependsOn),
        make_edge("r2", "B", "C", RelationshipType::DependsOn),
        make_edge("r3", "C", "A", RelationshipType::DependsOn), // closes the cycle
    };
    const oep::engine::GraphValidationReport report = oep::engine::validate_graph(nodes, edges);
    bool found_cycle = false;
    for (const oep::engine::GraphIssue& issue : report.issues()) {
        if (issue.kind == oep::engine::GraphIssueKind::Cycle) found_cycle = true;
    }
    check(found_cycle, "a directed cycle A->B->C->A is detected");
}

void test_validator_accepts_a_clean_graph() {
    std::vector<oep::engine::KnowledgeGraphNode> nodes = {make_node("A", ObjectType::Document), make_node("B", ObjectType::Document)};
    std::vector<oep::engine::KnowledgeGraphEdge> edges = {make_edge("r1", "A", "B", RelationshipType::References)};
    const oep::engine::GraphValidationReport report = oep::engine::validate_graph(nodes, edges);
    check(report.valid() && report.issues().empty(), "a clean graph reports valid with zero issues");
}

// ---------------------------------------------------------------------
// Serialization: deterministic, well-formed output
// ---------------------------------------------------------------------

void test_serialization_is_deterministic() {
    std::vector<oep::engine::KnowledgeGraphNode> nodes = {make_node("B", ObjectType::Document), make_node("A", ObjectType::Component)};
    std::vector<oep::engine::KnowledgeGraphEdge> edges = {make_edge("r1", "A", "B", RelationshipType::References)};
    oep::engine::KnowledgeGraph graph;
    graph.build(nodes, edges);

    const std::string json1 = oep::engine::to_json(graph);
    const std::string json2 = oep::engine::to_json(graph);
    check(json1 == json2, "JSON export is deterministic across repeated calls");
    check(json1.find("\"objectId\": \"A\"") != std::string::npos, "JSON export includes object A");
    check(json1.find("relationships") != std::string::npos, "JSON export includes a relationships section");

    const std::string graphml = oep::engine::to_graphml_placeholder(graph);
    check(graphml.find("<graphml") != std::string::npos && graphml.find("</graphml>") != std::string::npos,
          "GraphML placeholder export is well-formed at a basic structural level");
    check(graphml.find("node id=\"A\"") != std::string::npos, "GraphML placeholder includes object A as a node");
}

// ---------------------------------------------------------------------
// KnowledgeGraphEngine: full integration, EngineeringContext-only
// ---------------------------------------------------------------------

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "6c3e1a52-aaaa-4f55-af22-5d9b8f1c7ea3";
    metadata.repository_name = "kge-tests";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);
    return root;
}

void test_knowledge_graph_engine_builds_and_validates_via_engineering_context(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "kge_basic");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto a = service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {"marine"}));
    const auto b = service.create_object(
        oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "B", "", "au", {}));
    check(a.success && b.success, "setup: two objects are created");
    check(service
              .create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
                  a.object.object_id, b.object.object_id, RelationshipType::DependsOn, "au", ""))
              .success,
          "setup: a DependsOn relationship is created");

    oep::engine::EngineeringContext context(service);
    oep::engine::KnowledgeGraphEngine engine(context);
    check(!engine.graph_built(), "the engine's graph is not built before build_graph() is called");

    const oep::engine::KnowledgeGraphEngine::BuildResult built = engine.build_graph();
    check(built.success && built.objects == 2 && built.relationships == 1, "build_graph succeeds: " + built.error);
    check(engine.graph_built(), "graph_built() is true after a successful build");

    const oep::engine::GraphValidationReport validation = engine.validate_graph();
    check(validation.valid(), "the freshly built graph passes validation");

    const oep::engine::GraphStatistics stats = engine.graph_statistics();
    check(stats.object_count == 2 && stats.relationship_count == 1, "graph_statistics reports correct counts");
    check(stats.connected_component_count == 1, "the two connected objects form exactly 1 connected component");

    const oep::engine::ComponentsResult components = engine.connected_components();
    check(components.success && components.components.size() == 1 && components.components[0].size() == 2,
          "connected_components reports one component containing both objects");

    const oep::engine::GraphPathResult path = engine.shortest_path(a.object.object_id, b.object.object_id);
    check(path.success && path.path_exists && path.path.size() == 2, "shortest_path finds the direct A->B path");

    const std::string json = engine.export_json();
    check(json.find(a.object.object_id) != std::string::npos, "export_json includes the created object's id");

    runtime.shutdown();
}

void test_knowledge_graph_engine_incremental_object_and_relationship_updates(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "kge_incremental");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto a =
        service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Component, "A", "", "au", {}));
    check(a.success, "setup: object A is created");

    oep::engine::EngineeringContext context(service);
    oep::engine::KnowledgeGraphEngine engine(context);
    check(engine.build_graph().success, "setup: initial build succeeds with just A");
    check(engine.graph().node_count() == 1, "the graph initially has 1 node");

    // Create B AFTER the graph was built, then incrementally add it --
    // proving this does NOT require a full rebuild.
    const auto b =
        service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(ObjectType::Document, "B", "", "au", {}));
    check(b.success, "setup: object B is created after the graph was built");
    check(engine.object_added(b.object.object_id), "object_added incrementally adds B");
    check(engine.graph().node_count() == 2, "the graph now has 2 nodes without a full rebuild");

    const auto rel = service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        a.object.object_id, b.object.object_id, RelationshipType::References, "au", ""));
    check(rel.success, "setup: a relationship is created");
    check(engine.relationship_added(rel.relationship), "relationship_added incrementally adds the edge");
    check(engine.graph().edge_count() == 1, "the graph now has the relationship without a full rebuild");

    check(engine.object_removed(a.object.object_id), "object_removed incrementally removes A");
    check(engine.graph().node_count() == 1 && engine.graph().edge_count() == 0,
          "removing A also removes the relationship that touched it");

    runtime.shutdown();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_knowledge_graph_engine_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_knowledge_graph_indexes();
    test_knowledge_graph_incremental_updates_stay_synchronized();
    test_validator_detects_every_issue_kind_deterministically();
    test_validator_detects_cycles();
    test_validator_accepts_a_clean_graph();
    test_serialization_is_deterministic();
    test_knowledge_graph_engine_builds_and_validates_via_engineering_context(scratch_dir);
    test_knowledge_graph_engine_incremental_object_and_relationship_updates(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All knowledge_graph_engine tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " knowledge_graph_engine test(s) failed.\n";
    return 1;
}
