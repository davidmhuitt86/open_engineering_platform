#pragma once

#include "oep/engine/rule_context.hpp"
#include "oep/engine/rule_types.hpp"

namespace oep::engine {

// WP-EKE-004's Rule Evaluator: the ONLY place condition PRIMITIVES
// (RuleConditionKind) are interpreted. Deterministic and read-only --
// never mutates the Knowledge Graph, never persists anything, never
// performs AI inference (every condition is a direct, mechanical
// lookup/count against already-materialized graph data, nothing more).
class RuleEvaluator {
public:
    static RuleEvaluationResult evaluate(const EngineeringRule& rule, const RuleEvaluationContext& context);
};

} // namespace oep::engine
