#include "oep/engine/rules_engine.hpp"

#include "oep/engine/rule_evaluator.hpp"

namespace oep::engine {

RuleEvaluationContext RulesEngine::build_context() const {
    return RuleEvaluationContext(engineering_context_, knowledge_graph_engine_, query_engine_,
                                  compute_statistics(knowledge_graph_engine_.graph()), configuration_);
}

std::optional<RuleEvaluationResult> RulesEngine::evaluate_rule(const std::string& rule_id) const {
    const std::optional<EngineeringRule> rule = registry_.find_rule(rule_id);
    if (!rule.has_value()) return std::nullopt;
    return RuleEvaluator::evaluate(*rule, build_context());
}

std::vector<RuleEvaluationResult> RulesEngine::evaluate_all() const {
    const RuleEvaluationContext context = build_context();
    std::vector<RuleEvaluationResult> results;
    for (const EngineeringRule& rule : registry_.enabled_rules()) {
        results.push_back(RuleEvaluator::evaluate(rule, context));
    }
    return results;
}

} // namespace oep::engine
