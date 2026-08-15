#include "oep/engine/analysis_engine.hpp"

#include "oep/engine/graph_algorithms.hpp"

#include <algorithm>
#include <deque>
#include <map>
#include <set>

namespace oep::engine {

namespace {

// BFS over DependsOn edges only, in the given direction (outgoing ==
// "what this object depends on"; incoming == "what depends on this
// object"). Deterministic: edges are already visited in sorted order
// via KnowledgeGraph::edges_of.
struct ClosureResult {
    std::vector<std::string> object_ids; // excludes the start object, sorted
    std::vector<std::string> relationship_ids; // sorted, deduplicated
    int max_depth = 0;
};

ClosureResult depends_on_closure(const KnowledgeGraph& graph, const std::string& start, bool outgoing) {
    ClosureResult result;
    if (!graph.contains(start)) return result;

    std::set<std::string> visited{start};
    std::deque<std::pair<std::string, int>> queue{{start, 0}};
    std::set<std::string> relationship_ids;

    while (!queue.empty()) {
        const auto [current, depth] = queue.front();
        queue.pop_front();
        result.max_depth = std::max(result.max_depth, depth);
        for (const KnowledgeGraphEdgeView& edge : graph.edges_of(current)) {
            if (edge.relationship_type != oep::repository::RelationshipType::DependsOn) continue;
            if (edge.outgoing != outgoing) continue;
            relationship_ids.insert(edge.relationship_id);
            if (visited.insert(edge.neighbor_object_id).second) {
                result.object_ids.push_back(edge.neighbor_object_id);
                queue.emplace_back(edge.neighbor_object_id, depth + 1);
            }
        }
    }
    std::sort(result.object_ids.begin(), result.object_ids.end());
    result.relationship_ids.assign(relationship_ids.begin(), relationship_ids.end());
    return result;
}

} // namespace

DependencyReport AnalysisEngine::analyze_dependencies(const std::string& object_id) const {
    const ClosureResult closure = depends_on_closure(knowledge_graph_engine_.graph(), object_id, /*outgoing=*/true);
    std::string evidence = "transitive outgoing DependsOn closure from '" + object_id + "' (breadth-first, " +
                            std::to_string(closure.object_ids.size()) + " object(s) at depth <= " +
                            std::to_string(closure.max_depth) + ")";
    return DependencyReport(object_id, closure.object_ids, closure.relationship_ids, closure.max_depth,
                             std::move(evidence));
}

ImpactReport AnalysisEngine::analyze_impact(const std::string& object_id) const {
    const ClosureResult closure = depends_on_closure(knowledge_graph_engine_.graph(), object_id, /*outgoing=*/false);
    std::string evidence = "transitive incoming DependsOn closure from '" + object_id + "' (breadth-first, " +
                            std::to_string(closure.object_ids.size()) + " object(s) would be affected by a change)";
    return ImpactReport(object_id, closure.object_ids, closure.relationship_ids, closure.max_depth, std::move(evidence));
}

ReachabilityReport AnalysisEngine::analyze_reachability(const std::string& source_object_id,
                                                          const std::string& target_object_id) const {
    const GraphPathResult path =
        GraphAlgorithms::shortest_path(knowledge_graph_engine_.graph(), source_object_id, target_object_id);
    std::string evidence = path.success
                                ? (path.path_exists ? "breadth-first shortest path search found a connecting path"
                                                     : "breadth-first shortest path search exhausted the connected "
                                                       "component without finding the target")
                                : path.error;
    return ReachabilityReport(source_object_id, target_object_id, path.success && path.path_exists, path.path,
                               std::move(evidence));
}

RootCauseReport AnalysisEngine::analyze_root_cause(const std::string& symptom_object_id,
                                                     const std::vector<std::string>& finding_object_ids) const {
    const KnowledgeGraph& graph = knowledge_graph_engine_.graph();
    const ClosureResult dependencies = depends_on_closure(graph, symptom_object_id, /*outgoing=*/true);
    const std::set<std::string> findings(finding_object_ids.begin(), finding_object_ids.end());

    // Rank candidates by ascending BFS depth from the symptom (the
    // closest dependency with a finding is the most likely proximate
    // cause) -- recompute per-object depth via a second BFS so ranking
    // is exact, not just "in dependency set."
    std::map<std::string, int> depth_by_object;
    if (graph.contains(symptom_object_id)) {
        std::set<std::string> visited{symptom_object_id};
        std::deque<std::pair<std::string, int>> queue{{symptom_object_id, 0}};
        while (!queue.empty()) {
            const auto [current, depth] = queue.front();
            queue.pop_front();
            for (const KnowledgeGraphEdgeView& edge : graph.edges_of(current)) {
                if (edge.relationship_type != oep::repository::RelationshipType::DependsOn || !edge.outgoing) continue;
                if (visited.insert(edge.neighbor_object_id).second) {
                    depth_by_object[edge.neighbor_object_id] = depth + 1;
                    queue.emplace_back(edge.neighbor_object_id, depth + 1);
                }
            }
        }
    }

    std::vector<std::string> candidates;
    for (const std::string& id : dependencies.object_ids) {
        if (findings.count(id) != 0) candidates.push_back(id);
    }
    std::sort(candidates.begin(), candidates.end(), [&](const std::string& a, const std::string& b) {
        const int depth_a = depth_by_object.count(a) != 0 ? depth_by_object.at(a) : 0;
        const int depth_b = depth_by_object.count(b) != 0 ? depth_by_object.at(b) : 0;
        if (depth_a != depth_b) return depth_a < depth_b;
        return a < b; // deterministic tie-break
    });

    std::vector<std::string> failure_chain;
    if (!candidates.empty()) {
        const GraphPathResult path = GraphAlgorithms::shortest_path(graph, candidates.front(), symptom_object_id);
        if (path.success && path.path_exists) failure_chain = path.path;
    }

    std::string evidence = candidates.empty()
                                ? "no transitive dependency of '" + symptom_object_id + "' has an outstanding validation finding"
                                : std::to_string(candidates.size()) +
                                      " transitive dependency object(s) with validation findings found, ranked by "
                                      "ascending dependency depth from '" + symptom_object_id + "'";
    return RootCauseReport(symptom_object_id, candidates, failure_chain, std::move(evidence));
}

} // namespace oep::engine
