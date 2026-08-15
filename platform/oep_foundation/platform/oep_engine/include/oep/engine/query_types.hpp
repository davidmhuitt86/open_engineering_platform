#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::engine {

// WP-EKE-003: the ten minimum query categories this work package requires.
enum class QueryCategory {
    Object,
    Relationship,
    Domain,
    Type,
    Dependency,
    Neighborhood,
    Path,
    Reference,
    Metadata,
    Composite,
};

std::string to_string(QueryCategory category);

enum class TraversalStrategy {
    None,           // direct index lookup, no graph walk
    BreadthFirst,
    DepthFirst,
};

std::string to_string(TraversalStrategy strategy);

// Every filter WP-EKE-003 names, all optional -- "multiple filters may
// be combined." `tags` (Metadata queries) requires ALL listed tags to
// be present (AND, not OR) -- documented here since it's the one
// non-obvious combination rule.
struct QueryFilter {
    std::optional<oep::repository::ObjectType> object_type;
    std::optional<std::string> domain;
    std::optional<oep::repository::RelationshipType> relationship_type;
    std::optional<std::string> publisher_id;
    std::optional<std::string> package_id;
    std::vector<std::string> tags;
    std::optional<int> max_depth;
    // Direction: nullopt == both directions; true == outgoing only;
    // false == incoming only. Meaningful for Reference/Neighborhood/
    // Dependency queries.
    std::optional<bool> outgoing_only;
};

// The caller's request -- immutable, since it is itself passed around
// and cached against. `primary_object_id` is the query's main subject
// (Object/Dependency/Neighborhood/Path/Reference queries);
// `secondary_object_id` is used only by Path queries (the target).
class QueryRequest {
public:
    QueryRequest(QueryCategory category, std::string primary_object_id, std::string secondary_object_id,
                 QueryFilter filter)
        : category_(category),
          primary_object_id_(std::move(primary_object_id)),
          secondary_object_id_(std::move(secondary_object_id)),
          filter_(std::move(filter)) {}

    QueryCategory category() const { return category_; }
    const std::string& primary_object_id() const { return primary_object_id_; }
    const std::string& secondary_object_id() const { return secondary_object_id_; }
    const QueryFilter& filter() const { return filter_; }

private:
    QueryCategory category_;
    std::string primary_object_id_;
    std::string secondary_object_id_;
    QueryFilter filter_;
};

// A canonical, deterministic string key for `request` -- identical
// requests (same category/ids/filter values) always produce the
// identical key, used by QueryCache for lookup and by tests to assert
// determinism. Not intended to be human-authored, only compared.
std::string cache_key(const QueryRequest& request);

// WP-EKE-003's immutable QueryPlan: Query Type, Filters, Traversal
// Strategy, Indexes Used, Estimated Cost, Execution Order -- exactly
// the fields the work package names. Produced by QueryPlanner (pure,
// side-effect-free: "Planning shall never execute the query" -- see
// query_planner.hpp), consumed by QueryExecutor.
class QueryPlan {
public:
    QueryPlan(QueryRequest request, TraversalStrategy strategy, std::vector<std::string> indexes_used,
              double estimated_cost, std::vector<std::string> execution_order)
        : request_(std::move(request)),
          strategy_(strategy),
          indexes_used_(std::move(indexes_used)),
          estimated_cost_(estimated_cost),
          execution_order_(std::move(execution_order)) {}

    const QueryRequest& request() const { return request_; }
    QueryCategory category() const { return request_.category(); }
    const QueryFilter& filter() const { return request_.filter(); }
    TraversalStrategy strategy() const { return strategy_; }
    const std::vector<std::string>& indexes_used() const { return indexes_used_; }
    double estimated_cost() const { return estimated_cost_; }
    // The ids QueryExecutor will visit/inspect, in the exact order it
    // will visit them -- already deterministic at planning time, since
    // every index QueryPlanner consults is itself sorted.
    const std::vector<std::string>& execution_order() const { return execution_order_; }

private:
    QueryRequest request_;
    TraversalStrategy strategy_;
    std::vector<std::string> indexes_used_;
    double estimated_cost_;
    std::vector<std::string> execution_order_;
};

// WP-EKE-003's Query Statistics.
struct QueryStatistics {
    double execution_time_ms = 0.0;
    std::size_t objects_examined = 0;
    std::size_t relationships_examined = 0;
    int traversal_depth = 0;
    std::vector<std::string> indexes_used;
    std::size_t result_count = 0;
};

// WP-EKE-003's immutable EngineeringQueryResult: Objects, Relationships,
// Statistics, Execution Time (folded into `statistics`), Result Count
// (also folded into `statistics`, and mirrored by object/relationship
// id list sizes), Traversal Summary (`traversal_summary`, a short
// human-readable description of what was walked).
class EngineeringQueryResult {
public:
    EngineeringQueryResult(std::vector<std::string> object_ids, std::vector<std::string> relationship_ids,
                QueryStatistics statistics, std::string traversal_summary)
        : object_ids_(std::move(object_ids)),
          relationship_ids_(std::move(relationship_ids)),
          statistics_(std::move(statistics)),
          traversal_summary_(std::move(traversal_summary)) {}

    const std::vector<std::string>& object_ids() const { return object_ids_; }
    const std::vector<std::string>& relationship_ids() const { return relationship_ids_; }
    const QueryStatistics& statistics() const { return statistics_; }
    const std::string& traversal_summary() const { return traversal_summary_; }

private:
    std::vector<std::string> object_ids_;
    std::vector<std::string> relationship_ids_;
    QueryStatistics statistics_;
    std::string traversal_summary_;
};

} // namespace oep::engine
