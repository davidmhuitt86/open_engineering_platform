#pragma once

#include <map>
#include <optional>
#include <string>

#include "oep/engine/query_types.hpp"

namespace oep::engine {

// WP-EKE-003's Query Cache: caches immutable QueryPlans and (where
// appropriate -- see EngineeringQueryEngine's own doc comment)
// immutable QueryResults, keyed by cache_key(request). "Cache
// invalidation shall occur only when EngineeringContext refreshes" --
// this class has no automatic invalidation of its own (it cannot know
// when that happens, same caller-driven limitation already documented
// for WP-EKE-002's incremental updates); EngineeringQueryEngine::
// clear_query_cache() is the caller-invoked trigger a caller must call
// after rebuilding/refreshing the Knowledge Graph.
class QueryCache {
public:
    std::optional<QueryPlan> find_plan(const std::string& key) const;
    void store_plan(const std::string& key, QueryPlan plan);

    std::optional<EngineeringQueryResult> find_result(const std::string& key) const;
    void store_result(const std::string& key, EngineeringQueryResult result);

    void clear();

    std::size_t plan_count() const { return plans_.size(); }
    std::size_t result_count() const { return results_.size(); }

private:
    std::map<std::string, QueryPlan> plans_;
    std::map<std::string, EngineeringQueryResult> results_;
};

} // namespace oep::engine
