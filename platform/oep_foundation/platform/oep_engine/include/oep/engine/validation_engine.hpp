#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

#include "oep/engine/engineering_query_engine.hpp"
#include "oep/engine/knowledge_graph_engine.hpp"
#include "oep/engine/rules_engine.hpp"
#include "oep/engine/validation_types.hpp"

namespace oep::engine {

// WP-EKE-005's Engineering Validation Engine (EVE): executes engineering
// rules (via the Rules Engine, WP-EKE-004) against a Validation Target,
// producing an immutable ValidationReport. Consumes EngineeringContext,
// the Knowledge Graph, the Query Engine, and the Rules Engine ONLY --
// never FoundationRuntime/RuntimeService/repository storage directly.
//
// "It consumes the Engineering Rules Engine and never embeds
// engineering rules directly": the ONLY policy ValidationEngine itself
// contains is the ValidationProfile -> RuleCategory mapping
// (validation_types.hpp) -- which CATEGORY of already-registered rules
// a named profile runs. It never constructs, evaluates, or interprets
// a rule condition itself; every actual rule check happens inside
// RuleEvaluator (WP-EKE-004), reached only through RulesEngine.
//
// Targeting: rather than re-deriving which objects a rule concerns
// (that is RuleEvaluator's job, via each rule's own RuleScope),
// ValidationEngine evaluates every profile-selected enabled rule in
// full via RulesEngine::evaluate_rule, then NARROWS each result's
// affected_objects/diagnostics down to whatever the requested
// ValidationTarget's object set intersects (or keeps everything
// unfiltered for EngineeringContext-scoped validation, the
// "no narrowing" case). A rule whose full evaluation failed, but whose
// failure did not touch any object inside a narrower target, is
// treated as satisfied FOR THAT TARGET (no finding is produced) --
// exactly the same "does this specific target violate this rule"
// question a caller narrowing to one object or one package expects
// answered, without ValidationEngine ever re-implementing scope
// resolution.
class ValidationEngine {
public:
    ValidationEngine(EngineeringContext& engineering_context, KnowledgeGraphEngine& knowledge_graph_engine,
                      EngineeringQueryEngine& query_engine, RulesEngine& rules_engine)
        : engineering_context_(engineering_context),
          knowledge_graph_engine_(knowledge_graph_engine),
          query_engine_(query_engine),
          rules_engine_(rules_engine) {}

    bool graph_ready() const { return rules_engine_.graph_ready(); }

    // Starts a new ValidationSession for `profile`, returning its
    // session_id. The session's target/statistics are finalized by
    // whichever validate_* call runs against it next; a session that
    // is created but never validated has empty target/zero statistics
    // if queried via validation_report()/validation_statistics().
    std::string create_validation_session(ValidationProfile profile);

    // The five Validation Scopes (WP-EKE-005). Each finalizes
    // `session_id`'s session (recording the resolved target, active
    // rule set, end time, and statistics) and returns the resulting
    // ValidationReport. Returns nullopt if `session_id` was never
    // created via create_validation_session(), or if graph_ready() is
    // false.
    std::optional<ValidationReport> validate_object(const std::string& session_id, const std::string& object_id);
    std::optional<ValidationReport> validate_objects(const std::string& session_id,
                                                       const std::vector<std::string>& object_ids);
    std::optional<ValidationReport> validate_context(const std::string& session_id);
    std::optional<ValidationReport> validate_package(const std::string& session_id, const std::string& package_id);
    std::optional<ValidationReport> validate_query_result(const std::string& session_id,
                                                            const EngineeringQueryResult& query_result);

    // The most recent ValidationReport/Statistics produced for
    // `session_id` (nullopt if the session doesn't exist or hasn't
    // been validated yet).
    std::optional<ValidationReport> validation_report(const std::string& session_id) const;
    std::optional<ValidationStatistics> validation_statistics(const std::string& session_id) const;

private:
    EngineeringContext& engineering_context_;
    KnowledgeGraphEngine& knowledge_graph_engine_;
    EngineeringQueryEngine& query_engine_;
    RulesEngine& rules_engine_;

    struct SessionState {
        std::string start_time_utc;
        ValidationProfile profile;
        std::optional<ValidationReport> last_report;
    };
    std::map<std::string, SessionState> sessions_;

    std::optional<ValidationReport> run(const std::string& session_id, ValidationTarget target,
                                         const std::optional<std::vector<std::string>>& narrow_to_object_ids);
};

} // namespace oep::engine
