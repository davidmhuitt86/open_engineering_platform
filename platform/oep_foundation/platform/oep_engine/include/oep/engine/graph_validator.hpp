#pragma once

#include <string>
#include <vector>

#include "oep/engine/knowledge_graph.hpp"

namespace oep::engine {

enum class GraphIssueKind {
    MissingEndpoint,      // a relationship's source or target object is not in the node set
    DuplicateRelationship, // two edges share the same relationship_id
    SelfReference,          // a relationship's source and target are the same object
    BrokenReference,        // a relationship has an empty source or target object id
    Cycle,                  // a directed cycle exists in the edge set
    InvalidRelationshipType, // defensive: a relationship_type outside the known enum range
};

std::string to_string(GraphIssueKind kind);

struct GraphIssue {
    GraphIssueKind kind = GraphIssueKind::MissingEndpoint;
    std::string relationship_id; // empty when the issue isn't tied to one specific relationship (e.g. a Cycle)
    std::string detail;
};

// Immutable, per WP-EKE-002's "Produce immutable GraphValidationReport."
class GraphValidationReport {
public:
    GraphValidationReport(bool valid, std::vector<GraphIssue> issues) : valid_(valid), issues_(std::move(issues)) {}

    bool valid() const { return valid_; }
    const std::vector<GraphIssue>& issues() const { return issues_; }

private:
    bool valid_;
    std::vector<GraphIssue> issues_;
};

// Validates `nodes`/`edges` -- the RAW input a KnowledgeGraph was (or
// would be) built from, not the already-built graph, since
// KnowledgeGraph::build never silently drops anything (see its own doc
// comment) and this validator needs to see exactly what was supplied,
// including anything a graph's own adjacency index would otherwise
// treat as unconnected. Deterministic (WP-EKE-002 requirement): issues
// are reported in the exact order their relationships/nodes appear in
// the input, and cycle detection visits nodes in ascending object_id
// order at every choice point, so the same input always reports the
// same issues in the same order. Never mutates anything -- pure
// function of its inputs.
GraphValidationReport validate_graph(const std::vector<KnowledgeGraphNode>& nodes,
                                      const std::vector<KnowledgeGraphEdge>& edges);

} // namespace oep::engine
