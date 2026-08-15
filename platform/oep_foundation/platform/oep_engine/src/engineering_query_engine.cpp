#include "oep/engine/engineering_query_engine.hpp"

#include "oep/engine/query_executor.hpp"
#include "oep/engine/query_planner.hpp"

namespace oep::engine {

QueryPlan EngineeringQueryEngine::plan_query(const QueryRequest& request) {
    const std::string key = cache_key(request);
    const std::optional<QueryPlan> cached = cache_.find_plan(key);
    if (cached.has_value()) {
        return *cached;
    }
    QueryPlan plan = QueryPlanner::plan(request, knowledge_graph_engine_);
    cache_.store_plan(key, plan);
    return plan;
}

EngineeringQueryResult EngineeringQueryEngine::execute_query(const QueryPlan& plan) {
    const std::string key = cache_key(plan.request());
    const std::optional<EngineeringQueryResult> cached = cache_.find_result(key);
    if (cached.has_value()) {
        last_statistics_ = cached->statistics();
        return *cached;
    }
    EngineeringQueryResult result = QueryExecutor::execute(plan, knowledge_graph_engine_);
    last_statistics_ = result.statistics();
    cache_.store_result(key, result);
    return result;
}

EngineeringQueryResult EngineeringQueryEngine::execute_query(const QueryRequest& request) {
    return execute_query(plan_query(request));
}

} // namespace oep::engine
