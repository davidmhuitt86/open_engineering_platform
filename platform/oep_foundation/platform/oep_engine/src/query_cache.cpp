#include "oep/engine/query_cache.hpp"

namespace oep::engine {

std::optional<QueryPlan> QueryCache::find_plan(const std::string& key) const {
    const auto found = plans_.find(key);
    if (found == plans_.end()) return std::nullopt;
    return found->second;
}

void QueryCache::store_plan(const std::string& key, QueryPlan plan) {
    plans_.erase(key);
    plans_.emplace(key, std::move(plan));
}

std::optional<EngineeringQueryResult> QueryCache::find_result(const std::string& key) const {
    const auto found = results_.find(key);
    if (found == results_.end()) return std::nullopt;
    return found->second;
}

void QueryCache::store_result(const std::string& key, EngineeringQueryResult result) {
    results_.erase(key);
    results_.emplace(key, std::move(result));
}

void QueryCache::clear() {
    plans_.clear();
    results_.clear();
}

} // namespace oep::engine
