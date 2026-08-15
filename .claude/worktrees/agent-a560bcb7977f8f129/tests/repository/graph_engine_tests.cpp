#include "oep/repository/graph_engine.hpp"

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/repository/relationship_store.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

oep::repository::EngineeringObject make_object(const std::string& name) {
    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = name;
    object.version = "1.0.0";
    return object;
}

oep::repository::Relationship make_relationship(const std::string& source, const std::string& target,
                                                  oep::repository::RelationshipType type) {
    oep::repository::Relationship relationship;
    relationship.source_object_id = source;
    relationship.target_object_id = target;
    relationship.relationship_type = type;
    return relationship;
}

bool contains(const std::vector<std::string>& ids, const std::string& id) {
    return std::find(ids.begin(), ids.end(), id) != ids.end();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_graph_engine_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    const oep::repository::ObjectStore objects(scratch_dir / "objects",
                                                oep::repository::AuditStore(scratch_dir / "audit"));
    const oep::repository::RelationshipStore relationships(
        scratch_dir / "relationships", objects, oep::repository::AuditStore(scratch_dir / "audit"));

    // A -- B -- C form a connected chain (a cycle is added below via A -- C).
    // D is isolated (no relationships).
    const oep::repository::LoadObjectResult a = objects.create(make_object("A"));
    const oep::repository::LoadObjectResult b = objects.create(make_object("B"));
    const oep::repository::LoadObjectResult c = objects.create(make_object("C"));
    const oep::repository::LoadObjectResult d = objects.create(make_object("D"));
    check(a.success && b.success && c.success && d.success, "creating the sample objects succeeds");

    check(relationships
              .create(make_relationship(a.object.object_id, b.object.object_id,
                                         oep::repository::RelationshipType::ConnectedTo))
              .success,
          "creating relationship A-B succeeds");
    check(relationships
              .create(make_relationship(b.object.object_id, c.object.object_id,
                                         oep::repository::RelationshipType::ConnectedTo))
              .success,
          "creating relationship B-C succeeds");
    check(relationships
              .create(make_relationship(c.object.object_id, a.object.object_id, oep::repository::RelationshipType::References))
              .success,
          "creating relationship C-A (closing the cycle) succeeds");

    oep::repository::GraphEngine graph;
    graph.build_graph(objects, relationships);

    // Neighbor discovery.
    {
        const oep::repository::NeighborsResult result = graph.get_neighbors(a.object.object_id);
        check(result.success, "get_neighbors succeeds for a known object");
        check(result.neighbors.size() == 2, "A has exactly two neighbors (B and C)");

        bool found_connected_to = false;
        for (const oep::repository::GraphNeighbor& neighbor : result.neighbors) {
            if (neighbor.relationship_type == oep::repository::RelationshipType::ConnectedTo) {
                found_connected_to = true;
            }
        }
        check(found_connected_to, "get_neighbors preserves relationship type");
    }

    // Isolated node has no neighbors but is still part of the graph.
    {
        const oep::repository::NeighborsResult result = graph.get_neighbors(d.object.object_id);
        check(result.success, "get_neighbors succeeds for an isolated object");
        check(result.neighbors.empty(), "an isolated object has no neighbors");
    }

    // BFS from A visits all three connected nodes (cycle does not cause infinite loop).
    {
        const oep::repository::TraversalResult result = graph.traverse_breadth_first(a.object.object_id);
        check(result.success, "traverse_breadth_first succeeds for a known object");
        check(result.object_ids.size() == 3, "BFS from A visits exactly A, B, and C");
        check(result.object_ids.front() == a.object.object_id, "BFS visits the starting object first");
        check(!contains(result.object_ids, d.object.object_id), "BFS from A does not reach the isolated object D");
    }

    // DFS from A also visits all three connected nodes.
    {
        const oep::repository::TraversalResult result = graph.traverse_depth_first(a.object.object_id);
        check(result.success, "traverse_depth_first succeeds for a known object");
        check(result.object_ids.size() == 3, "DFS from A visits exactly A, B, and C");
        check(result.object_ids.front() == a.object.object_id, "DFS visits the starting object first");
    }

    // Determinism: repeated traversals over unchanged state return identical order.
    {
        const oep::repository::TraversalResult first = graph.traverse_breadth_first(a.object.object_id);
        const oep::repository::TraversalResult second = graph.traverse_breadth_first(a.object.object_id);
        check(first.object_ids == second.object_ids, "BFS traversal order is deterministic across repeated calls");
    }

    // Path detection: connected pair.
    {
        const oep::repository::PathExistsResult result = graph.path_exists(a.object.object_id, c.object.object_id);
        check(result.success, "path_exists succeeds for known objects");
        check(result.path_exists, "a path exists between A and C");
    }

    // Path detection: disconnected pair (isolated D).
    {
        const oep::repository::PathExistsResult result = graph.path_exists(a.object.object_id, d.object.object_id);
        check(result.success, "path_exists succeeds even when there is no path");
        check(!result.path_exists, "no path exists between A and the isolated object D");
    }

    // Path detection: same object.
    {
        const oep::repository::PathExistsResult result = graph.path_exists(a.object.object_id, a.object.object_id);
        check(result.success && result.path_exists, "a trivial path exists from an object to itself");
    }

    // Invalid/nonexistent objects are handled gracefully.
    {
        const std::string missing_id = "00000000-0000-4000-8000-000000000000";
        check(!graph.get_neighbors(missing_id).success, "get_neighbors fails for a nonexistent object");
        check(!graph.traverse_breadth_first(missing_id).success, "BFS fails for a nonexistent starting object");
        check(!graph.traverse_depth_first(missing_id).success, "DFS fails for a nonexistent starting object");
        check(!graph.path_exists(missing_id, a.object.object_id).success,
              "path_exists fails when the source object does not exist");
    }

    // Removing an object and rebuilding excludes relationships referencing it.
    {
        check(objects.remove(d.object.object_id).success, "removing the isolated object succeeds");
        graph.build_graph(objects, relationships);
        check(!graph.get_neighbors(d.object.object_id).success,
              "rebuilding the graph after removal drops the removed object");
    }

    // clear_graph empties the graph without touching repository contents.
    {
        graph.clear_graph();
        check(!graph.get_neighbors(a.object.object_id).success, "clear_graph empties the in-memory graph");

        const oep::repository::LoadObjectResult reloaded = objects.load(a.object.object_id);
        check(reloaded.success, "clear_graph does not modify repository contents");
    }

    // Empty repository builds an empty, valid graph.
    {
        const std::filesystem::path empty_dir = scratch_dir / "empty";
        const oep::repository::ObjectStore empty_objects(empty_dir / "objects",
                                                          oep::repository::AuditStore(empty_dir / "audit"));
        const oep::repository::RelationshipStore empty_relationships(
            empty_dir / "relationships", empty_objects, oep::repository::AuditStore(empty_dir / "audit"));

        oep::repository::GraphEngine empty_graph;
        empty_graph.build_graph(empty_objects, empty_relationships);
        check(!empty_graph.get_neighbors("anything").success,
              "build_graph handles an empty repository gracefully");
    }

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All graph engine tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " graph engine test(s) failed.\n";
    return 1;
}
