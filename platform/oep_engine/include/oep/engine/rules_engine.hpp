#pragma once

#include <optional>
#include <vector>

#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/rule_context.hpp"
#include "oep/engine/rule_registry.hpp"
#include "oep/engine/rule_types.hpp"

namespace oep::engine {

// WP-EKE-004's Engineering Rules Engine (ERE): the top-level facade,
// exposing the exact five-method Runtime API the work package
// specifies: register_rule, evaluate_rule, evaluate_all, enabled_rules,
// disabled_rules (plus the natural registry completions remove_rule/
// enable_rule/disable_rule/all_rules).
//
// Consumes EngineeringContext, the Knowledge Graph Engine, and the
// Engineering Query Engine ONLY (constructor takes references to all
// three) -- never FoundationRuntime, RuntimeService, or repository
// storage. It does not perform validation itself (WP-EKE-004's own
// framing: "It provides the reusable rule evaluation framework
// consumed by the Validation Engine and future reasoning systems") --
// this class only registers and evaluates rules; deciding WHAT rules
// mean for a repository's overall validity is a future work package's
// job.
//
// Both `EngineeringContext::load_graph()` and
// `KnowledgeGraphEngine::build_graph()` must have already been called
// successfully before evaluate_rule/evaluate_all are meaningful --
// exactly the same precondition WP-EKE-002/003 already impose on their
// own graph-dependent operations; this class does not call either
// itself; use `graph_ready()` to check this yourself.
class RulesEngine {
public:
    RulesEngine(EngineeringContext& engineering_context, KnowledgeGraphEngine& knowledge_graph_engine,
                EngineeringQueryEngine& query_engine)
        : engineering_context_(engineering_context),
          knowledge_graph_engine_(knowledge_graph_engine),
          query_engine_(query_engine) {}

    bool register_rule(EngineeringRule rule) { return registry_.register_rule(std::move(rule)); }
    bool remove_rule(const std::string& rule_id) { return registry_.remove_rule(rule_id); }
    bool enable_rule(const std::string& rule_id) { return registry_.enable_rule(rule_id); }
    bool disable_rule(const std::string& rule_id) { return registry_.disable_rule(rule_id); }

    std::vector<EngineeringRule> all_rules() const { return registry_.all_rules(); }
    std::vector<EngineeringRule> enabled_rules() const { return registry_.enabled_rules(); }
    std::vector<EngineeringRule> disabled_rules() const { return registry_.disabled_rules(); }

    bool graph_ready() const { return engineering_context_.graph_loaded() && knowledge_graph_engine_.graph_built(); }

    // Evaluates one registered rule by id, REGARDLESS of its
    // enabled/disabled state (an explicit request to evaluate a
    // specific rule overrides the enabled flag, which only gates
    // evaluate_all()). Returns nullopt if `rule_id` is not registered.
    std::optional<RuleEvaluationResult> evaluate_rule(const std::string& rule_id) const;

    // Evaluates every ENABLED rule, sorted by rule_id -- determinism.
    std::vector<RuleEvaluationResult> evaluate_all() const;

    void set_configuration(RuleConfiguration configuration) { configuration_ = std::move(configuration); }
    const RuleConfiguration& configuration() const { return configuration_; }

private:
    EngineeringContext& engineering_context_;
    KnowledgeGraphEngine& knowledge_graph_engine_;
    EngineeringQueryEngine& query_engine_;
    RuleRegistry registry_;
    RuleConfiguration configuration_;

    RuleEvaluationContext build_context() const;
};

} // namespace oep::engine
