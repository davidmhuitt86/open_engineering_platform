#include "oep/engine/query_engine.hpp"
#include "oep/engine/relationship_engine.hpp"
#include "oep/engine/runtime_graph.hpp"
#include "oep/engine/traversal_engine.hpp"

#include <iostream>
#include <string>

// Unit tests for the Engine's pure, in-memory graph components
// (RuntimeGraph, TraversalEngine, QueryEngine, RelationshipEngine),
// exercised directly against hand-built EngineeringObject/Relationship
// vectors -- no FoundationRuntime, no RuntimeService, no repository.
// See engineering_context_integration_tests.cpp for the full,
// RuntimeService-backed end-to-end path.

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

oep::repository::EngineeringObject make_object(const std::string& id, oep::repository::ObjectType type,
                                                 const std::string& name, std::vector<std::string> tags = {}) {
    oep::repository::EngineeringObject object;
    object.object_id = id;
    object.object_type = type;
    object.name = name;
    object.description = "d";
    object.created_utc = "2026-01-01T00:00:00Z";
    object.last_modified_utc = "2026-01-01T00:00:00Z";
    object.version = "1.0.0";
    object.author = "a";
    object.tags = std::move(tags);
    return object;
}

oep::repository::Relationship make_relationship(const std::string& id, const std::string& source, const std::string& target,
                                                  oep::repository::RelationshipType type) {
    oep::repository::Relationship relationship;
    relationship.relationship_id = id;
    relationship.source_object_id = source;
    relationship.target_object_id = target;
    relationship.relationship_type = type;
    relationship.created_utc = "2026-01-01T00:00:00Z";
    relationship.author = "a";
    relationship.description = "d";
    return relationship;
}

using oep::repository::ObjectType;
using oep::repository::RelationshipType;

// A: Contains -> B (B is A's child, A is B's parent)
// A: References -> C
// A: DependsOn -> D
// D: DependsOn -> E   (transitive dependency of A)
void test_graph_construction_and_indexes() {
    std::vector<oep::repository::EngineeringObject> objects = {
        make_object("A", ObjectType::Component, "Alpha", {"electrical"}),
        make_object("B", ObjectType::Document, "Bravo", {"electrical"}),
        make_object("C", ObjectType::Document, "Charlie", {"mechanical"}),
        make_object("D", ObjectType::Component, "Delta"),
        make_object("E", ObjectType::Component, "Echo"),
    };
    std::vector<oep::repository::Relationship> relationships = {
        make_relationship("r1", "A", "B", RelationshipType::Contains),
        make_relationship("r2", "A", "C", RelationshipType::References),
        make_relationship("r3", "A", "D", RelationshipType::DependsOn),
        make_relationship("r4", "D", "E", RelationshipType::DependsOn),
    };

    oep::engine::RuntimeGraph graph;
    graph.build(objects, relationships);

    check(graph.object_count() == 5, "the graph has all 5 objects");
    check(graph.relationship_count() == 4, "the graph has all 4 relationships");
    check(graph.contains("A") && !graph.contains("Z"), "contains() reflects graph membership");
    check(graph.find_object("A") != nullptr && graph.find_object("A")->name == "Alpha",
          "find_object returns the correct object");

    const std::vector<std::string> components = graph.object_ids_by_type(ObjectType::Component);
    check(components == (std::vector<std::string>{"A", "D", "E"}), "object_ids_by_type indexes correctly and sorts");

    const std::vector<std::string> electrical = graph.object_ids_by_tag("electrical");
    check(electrical == (std::vector<std::string>{"A", "B"}), "object_ids_by_tag indexes correctly");
}

void test_dangling_relationship_is_excluded() {
    std::vector<oep::repository::EngineeringObject> objects = {make_object("A", ObjectType::Document, "Alpha")};
    std::vector<oep::repository::Relationship> relationships = {
        make_relationship("r1", "A", "does-not-exist", RelationshipType::References)};

    oep::engine::RuntimeGraph graph;
    graph.build(objects, relationships);
    check(graph.relationship_count() == 0, "a relationship referencing a missing object is excluded from the graph");
}

void test_relationship_engine_classifications() {
    std::vector<oep::repository::EngineeringObject> objects = {
        make_object("A", ObjectType::Component, "Alpha"),
        make_object("B", ObjectType::Document, "Bravo"),
        make_object("C", ObjectType::Document, "Charlie"),
        make_object("D", ObjectType::Component, "Delta"),
    };
    std::vector<oep::repository::Relationship> relationships = {
        make_relationship("r1", "A", "B", RelationshipType::Contains),   // B is A's child
        make_relationship("r2", "A", "C", RelationshipType::References), // A references C
        make_relationship("r3", "A", "D", RelationshipType::DependsOn),  // A depends on D
    };
    oep::engine::RuntimeGraph graph;
    graph.build(objects, relationships);

    check(oep::engine::RelationshipEngine::children(graph, "A").object_ids == std::vector<std::string>{"B"},
          "children(A) == {B}");
    check(oep::engine::RelationshipEngine::parents(graph, "B").object_ids == std::vector<std::string>{"A"},
          "parents(B) == {A}");
    check(oep::engine::RelationshipEngine::references(graph, "A").object_ids == std::vector<std::string>{"C"},
          "references(A) == {C}");
    check(oep::engine::RelationshipEngine::dependencies(graph, "A").object_ids == std::vector<std::string>{"D"},
          "dependencies(A) == {D}");
    const auto neighbors = oep::engine::RelationshipEngine::neighbors(graph, "A").object_ids;
    check(neighbors == (std::vector<std::string>{"B", "C", "D"}), "neighbors(A) == {B, C, D}");
}

// A -> B -> C -> A (a cycle) plus a pendant D off of B.
void test_traversal_handles_cycles_without_infinite_loop() {
    std::vector<oep::repository::EngineeringObject> objects = {
        make_object("A", ObjectType::Document, "A"), make_object("B", ObjectType::Document, "B"),
        make_object("C", ObjectType::Document, "C"), make_object("D", ObjectType::Document, "D"),
    };
    std::vector<oep::repository::Relationship> relationships = {
        make_relationship("r1", "A", "B", RelationshipType::ConnectedTo),
        make_relationship("r2", "B", "C", RelationshipType::ConnectedTo),
        make_relationship("r3", "C", "A", RelationshipType::ConnectedTo), // closes the cycle
        make_relationship("r4", "B", "D", RelationshipType::ConnectedTo),
    };
    oep::engine::RuntimeGraph graph;
    graph.build(objects, relationships);

    const oep::engine::TraversalResult bfs = oep::engine::traverse(graph, "A");
    check(bfs.success, "BFS traversal succeeds even though the graph contains a cycle");
    check(bfs.object_ids.size() == 4, "every node is visited exactly once despite the cycle");

    const oep::engine::TraversalResult dfs =
        oep::engine::traverse(graph, "A", oep::engine::TraversalOptions{oep::engine::TraversalOrder::DepthFirst, {}, {}});
    check(dfs.success && dfs.object_ids.size() == 4, "DFS traversal also terminates and visits every node exactly once");
}

void test_traversal_respects_relationship_type_filter_and_max_depth() {
    std::vector<oep::repository::EngineeringObject> objects = {
        make_object("A", ObjectType::Document, "A"), make_object("B", ObjectType::Document, "B"),
        make_object("C", ObjectType::Document, "C"), make_object("D", ObjectType::Document, "D"),
    };
    std::vector<oep::repository::Relationship> relationships = {
        make_relationship("r1", "A", "B", RelationshipType::DependsOn),
        make_relationship("r2", "A", "C", RelationshipType::References),
        make_relationship("r3", "B", "D", RelationshipType::DependsOn),
    };
    oep::engine::RuntimeGraph graph;
    graph.build(objects, relationships);

    oep::engine::TraversalOptions dependsOnly;
    dependsOnly.relationship_type_filter = RelationshipType::DependsOn;
    const oep::engine::TraversalResult filtered = oep::engine::traverse(graph, "A", dependsOnly);
    check(filtered.success && filtered.object_ids.size() == 3,
          "filtering by relationship type only follows DependsOn edges (A, B, D -- not C)");

    oep::engine::TraversalOptions depthLimited;
    depthLimited.max_depth = 1;
    const oep::engine::TraversalResult limited = oep::engine::traverse(graph, "A", depthLimited);
    check(limited.success && limited.object_ids.size() == 3,
          "max_depth=1 visits only the start node plus its direct neighbors (A, B, C -- not D)");
}

void test_query_engine_find_operations() {
    std::vector<oep::repository::EngineeringObject> objects = {
        make_object("A", ObjectType::Component, "A", {"marine"}),
        make_object("B", ObjectType::Diagram, "B", {"marine"}),
        make_object("C", ObjectType::Component, "C"),
    };
    std::vector<oep::repository::Relationship> relationships = {
        make_relationship("r1", "A", "B", RelationshipType::Documents),
    };
    oep::engine::RuntimeGraph graph;
    graph.build(objects, relationships);

    check(oep::engine::QueryEngine::find_by_id(graph, "A").object_ids == std::vector<std::string>{"A"}, "find_by_id hit");
    check(oep::engine::QueryEngine::find_by_id(graph, "Z").object_ids.empty(), "find_by_id miss returns empty, not an error");
    check(oep::engine::QueryEngine::find_by_type(graph, ObjectType::Component).object_ids ==
              (std::vector<std::string>{"A", "C"}),
          "find_by_type");
    check(oep::engine::QueryEngine::find_by_domain(graph, "marine").object_ids == (std::vector<std::string>{"A", "B"}),
          "find_by_domain maps onto tags");
    check(oep::engine::QueryEngine::find_by_relationship(graph, RelationshipType::Documents).object_ids ==
              (std::vector<std::string>{"A", "B"}),
          "find_by_relationship returns both endpoints");
}

void test_shortest_path_and_connected_component_and_subgraph() {
    std::vector<oep::repository::EngineeringObject> objects = {
        make_object("A", ObjectType::Document, "A"), make_object("B", ObjectType::Document, "B"),
        make_object("C", ObjectType::Document, "C"), make_object("D", ObjectType::Document, "D"),
        make_object("Isolated", ObjectType::Document, "Isolated"),
    };
    std::vector<oep::repository::Relationship> relationships = {
        make_relationship("r1", "A", "B", RelationshipType::ConnectedTo),
        make_relationship("r2", "B", "C", RelationshipType::ConnectedTo),
        make_relationship("r3", "A", "D", RelationshipType::ConnectedTo),
        make_relationship("r4", "D", "C", RelationshipType::ConnectedTo),
    };
    oep::engine::RuntimeGraph graph;
    graph.build(objects, relationships);

    const oep::engine::PathResult path = oep::engine::QueryEngine::shortest_path(graph, "A", "C");
    check(path.success && path.path_exists, "a path from A to C exists");
    check(path.path.size() == 3, "the SHORTEST path (A->B->C or A->D->C, both length 3) is returned, not a longer one");
    check(path.path.front() == "A" && path.path.back() == "C", "the path starts at A and ends at C");

    const oep::engine::PathResult none = oep::engine::QueryEngine::shortest_path(graph, "A", "Isolated");
    check(none.success && !none.path_exists, "no path exists to an isolated node, reported without error");

    const oep::engine::QueryResult component = oep::engine::QueryEngine::connected_component(graph, "A");
    check(component.object_ids == (std::vector<std::string>{"A", "B", "C", "D"}),
          "the connected component from A excludes the isolated node");

    const oep::engine::SubgraphResult sub = oep::engine::QueryEngine::subgraph(graph, {"A", "B", "Isolated", "nonexistent"});
    check(sub.object_ids == (std::vector<std::string>{"A", "B", "Isolated"}),
          "subgraph keeps only requested ids that exist in the graph (including edgeless ones), dropping the rest");
    check(sub.relationship_ids == std::vector<std::string>{"r1"},
          "subgraph includes only relationships whose BOTH endpoints are in the requested set");
}

} // namespace

int main() {
    test_graph_construction_and_indexes();
    test_dangling_relationship_is_excluded();
    test_relationship_engine_classifications();
    test_traversal_handles_cycles_without_infinite_loop();
    test_traversal_respects_relationship_type_filter_and_max_depth();
    test_query_engine_find_operations();
    test_shortest_path_and_connected_component_and_subgraph();

    if (g_failures == 0) {
        std::cout << "All runtime_graph tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " runtime_graph test(s) failed.\n";
    return 1;
}
