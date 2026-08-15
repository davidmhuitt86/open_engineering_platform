#pragma once

#include <cstddef>
#include <string>
#include <vector>

#include "oep/engine/knowledge_graph.hpp"

namespace oep::engine {

struct RelationshipTypeCount {
    oep::repository::RelationshipType type;
    std::size_t count = 0;
};

struct DomainCount {
    std::string domain;
    std::size_t count = 0;
};

// WP-EKE-002's Graph Statistics. `maximum_depth` is the graph's
// diameter (the longest shortest-path between any two connected
// nodes), computed by a BFS from every node -- O(V*(V+E)); acceptable
// for the in-memory graph sizes this Engine targets (a repository's
// Engineering Objects), documented here as a known cost rather than a
// silent surprise. `density` is 2E/(N*(N-1)) (undirected simple-graph
// density); 0 when N < 2. `average_degree` is 2E/N; 0 when N == 0.
struct GraphStatistics {
    std::size_t object_count = 0;
    std::size_t relationship_count = 0;
    std::size_t connected_component_count = 0;
    double density = 0.0;
    int maximum_depth = 0;
    double average_degree = 0.0;
    std::vector<RelationshipTypeCount> relationship_distribution; // sorted by relationship type's declared order
    std::vector<DomainCount> domain_distribution;                  // sorted by domain name
};

GraphStatistics compute_statistics(const KnowledgeGraph& graph);

} // namespace oep::engine
