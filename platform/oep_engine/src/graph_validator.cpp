#include "oep/engine/graph_validator.hpp"

#include <algorithm>
#include <functional>
#include <map>
#include <set>

namespace oep::engine {

std::string to_string(GraphIssueKind kind) {
    switch (kind) {
        case GraphIssueKind::MissingEndpoint: return "MissingEndpoint";
        case GraphIssueKind::DuplicateRelationship: return "DuplicateRelationship";
        case GraphIssueKind::SelfReference: return "SelfReference";
        case GraphIssueKind::BrokenReference: return "BrokenReference";
        case GraphIssueKind::Cycle: return "Cycle";
        case GraphIssueKind::InvalidRelationshipType: return "InvalidRelationshipType";
    }
    return "Unknown";
}

namespace {

bool is_valid_relationship_type(oep::repository::RelationshipType type) {
    // Defensive: every RelationshipType this codebase constructs is
    // already one of the 6 declared enum values (see relationship.hpp);
    // this exists so a future extension to that enum -- or a value
    // arriving from an untrusted boundary in a future work package --
    // is still caught explicitly here rather than silently accepted.
    switch (type) {
        case oep::repository::RelationshipType::References:
        case oep::repository::RelationshipType::Contains:
        case oep::repository::RelationshipType::DependsOn:
        case oep::repository::RelationshipType::ConnectedTo:
        case oep::repository::RelationshipType::Documents:
        case oep::repository::RelationshipType::Implements:
            return true;
    }
    return false;
}

// Directed-cycle detection via DFS with a recursion stack, visiting
// nodes and, at each node, outgoing edges in ascending id order --
// deterministic regardless of container iteration order.
bool find_cycle(const std::vector<KnowledgeGraphNode>& nodes, const std::map<std::string, std::vector<std::string>>& outgoing,
                 std::string& out_description) {
    std::set<std::string> visited;
    std::set<std::string> on_stack;
    std::vector<std::string> path;

    std::vector<std::string> ordered_ids;
    for (const KnowledgeGraphNode& node : nodes) {
        ordered_ids.push_back(node.object_id);
    }
    std::sort(ordered_ids.begin(), ordered_ids.end());

    std::function<bool(const std::string&)> visit = [&](const std::string& id) -> bool {
        visited.insert(id);
        on_stack.insert(id);
        path.push_back(id);

        const auto found = outgoing.find(id);
        if (found != outgoing.end()) {
            for (const std::string& next : found->second) {
                if (on_stack.count(next) != 0) {
                    path.push_back(next);
                    std::string description;
                    const auto start_it = std::find(path.begin(), path.end(), next);
                    for (auto it = start_it; it != path.end(); ++it) {
                        description += *it;
                        if (std::next(it) != path.end()) description += " -> ";
                    }
                    out_description = description;
                    return true;
                }
                if (visited.count(next) == 0 && visit(next)) {
                    return true;
                }
            }
        }
        path.pop_back();
        on_stack.erase(id);
        return false;
    };

    for (const std::string& id : ordered_ids) {
        if (visited.count(id) == 0 && visit(id)) {
            return true;
        }
    }
    return false;
}

} // namespace

GraphValidationReport validate_graph(const std::vector<KnowledgeGraphNode>& nodes,
                                      const std::vector<KnowledgeGraphEdge>& edges) {
    std::set<std::string> node_ids;
    for (const KnowledgeGraphNode& node : nodes) {
        node_ids.insert(node.object_id);
    }

    std::vector<GraphIssue> issues;
    std::set<std::string> seen_relationship_ids;
    std::map<std::string, std::vector<std::string>> outgoing;

    for (const KnowledgeGraphEdge& edge : edges) {
        if (edge.source_object_id.empty() || edge.target_object_id.empty()) {
            issues.push_back({GraphIssueKind::BrokenReference, edge.relationship_id,
                               "relationship has an empty source or target object id"});
            continue; // no further checks make sense on a structurally broken edge
        }
        if (!seen_relationship_ids.insert(edge.relationship_id).second) {
            issues.push_back(
                {GraphIssueKind::DuplicateRelationship, edge.relationship_id, "relationship_id appears more than once"});
        }
        if (edge.source_object_id == edge.target_object_id) {
            issues.push_back({GraphIssueKind::SelfReference, edge.relationship_id,
                               "source and target object id are the same ('" + edge.source_object_id + "')"});
        }
        const bool source_missing = node_ids.count(edge.source_object_id) == 0;
        const bool target_missing = node_ids.count(edge.target_object_id) == 0;
        if (source_missing || target_missing) {
            issues.push_back({GraphIssueKind::MissingEndpoint, edge.relationship_id,
                               source_missing && target_missing  ? "both source and target objects are missing"
                               : source_missing                   ? "source object '" + edge.source_object_id + "' is missing"
                                                                    : "target object '" + edge.target_object_id + "' is missing"});
        }
        if (!is_valid_relationship_type(edge.relationship_type)) {
            issues.push_back({GraphIssueKind::InvalidRelationshipType, edge.relationship_id,
                               "relationship_type is not one of the declared RelationshipType values"});
        }
        if (!source_missing && !target_missing && edge.source_object_id != edge.target_object_id) {
            outgoing[edge.source_object_id].push_back(edge.target_object_id);
        }
    }
    for (auto& [id, neighbors] : outgoing) {
        std::sort(neighbors.begin(), neighbors.end());
    }

    std::string cycle_description;
    if (find_cycle(nodes, outgoing, cycle_description)) {
        issues.push_back({GraphIssueKind::Cycle, "", "a directed cycle exists: " + cycle_description});
    }

    const bool is_valid = issues.empty();
    return GraphValidationReport(is_valid, std::move(issues));
}

} // namespace oep::engine
