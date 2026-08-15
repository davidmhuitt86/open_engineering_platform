#include "oep/engine/rule_evaluator.hpp"

#include <algorithm>
#include <functional>
#include <map>
#include <set>

namespace oep::engine {

namespace {

std::vector<std::string> resolve_scope(const RuleScope& scope, const KnowledgeGraph& graph) {
    switch (scope.kind) {
        case RuleScopeKind::AllObjects: {
            std::vector<std::string> ids;
            for (const KnowledgeGraphNode* node : graph.all_nodes()) {
                ids.push_back(node->object_id);
            }
            return ids;
        }
        case RuleScopeKind::ByObjectType:
            return scope.object_type.has_value() ? graph.ids_by_object_type(*scope.object_type) : std::vector<std::string>{};
        case RuleScopeKind::ByDomain:
            return scope.domain.has_value() ? graph.ids_by_domain(*scope.domain) : std::vector<std::string>{};
        case RuleScopeKind::ByPackage:
            return scope.package_id.has_value() ? graph.ids_by_package(*scope.package_id) : std::vector<std::string>{};
        case RuleScopeKind::SingleObject:
            if (scope.object_id.has_value() && graph.contains(*scope.object_id)) {
                return {*scope.object_id};
            }
            return {};
    }
    return {};
}

int relationship_count(const KnowledgeGraph& graph, const std::string& object_id,
                        oep::repository::RelationshipType type, const std::optional<bool>& direction) {
    int count = 0;
    for (const KnowledgeGraphEdgeView& edge : graph.edges_of(object_id)) {
        if (edge.relationship_type != type) continue;
        if (direction.has_value() && edge.outgoing != *direction) continue;
        ++count;
    }
    return count;
}

// Returns true if the object satisfies `condition`; sets `*errored` if
// the condition is missing a parameter it requires to be checked at
// all (e.g. RequiresRelationship with no relationship_type set).
// `full_object`, when non-null, is the same object's full
// EngineeringObject record (description/author) from
// EngineeringContext's own RuntimeGraph (WP-EKE-001) -- KnowledgeGraph
// nodes (WP-EKE-002) deliberately carry only object_id/type/name/
// domains/package/publisher, not description/author, so
// HasDescription/HasAuthor read from this fuller record instead.
bool check_object_condition(const RuleCondition& condition, const std::string& object_id, const KnowledgeGraph& graph,
                             const oep::repository::EngineeringObject* full_object, bool& errored) {
    const KnowledgeGraphNode* node = graph.find_node(object_id);
    if (node == nullptr) {
        errored = true;
        return false;
    }
    switch (condition.kind) {
        case RuleConditionKind::RequiresRelationship: {
            if (!condition.relationship_type.has_value()) { errored = true; return false; }
            return relationship_count(graph, object_id, *condition.relationship_type, condition.direction) > 0;
        }
        case RuleConditionKind::ForbidsRelationship: {
            if (!condition.relationship_type.has_value()) { errored = true; return false; }
            return relationship_count(graph, object_id, *condition.relationship_type, condition.direction) == 0;
        }
        case RuleConditionKind::MinRelationshipCount: {
            if (!condition.relationship_type.has_value() || !condition.count.has_value()) { errored = true; return false; }
            return relationship_count(graph, object_id, *condition.relationship_type, condition.direction) >= *condition.count;
        }
        case RuleConditionKind::MaxRelationshipCount: {
            if (!condition.relationship_type.has_value() || !condition.count.has_value()) { errored = true; return false; }
            return relationship_count(graph, object_id, *condition.relationship_type, condition.direction) <= *condition.count;
        }
        case RuleConditionKind::RequiresTag: {
            if (!condition.tag.has_value()) { errored = true; return false; }
            return std::find(node->domains.begin(), node->domains.end(), *condition.tag) != node->domains.end();
        }
        case RuleConditionKind::ForbidsTag: {
            if (!condition.tag.has_value()) { errored = true; return false; }
            return std::find(node->domains.begin(), node->domains.end(), *condition.tag) == node->domains.end();
        }
        case RuleConditionKind::HasDescription:
            return full_object != nullptr && !full_object->description.empty();
        case RuleConditionKind::HasAuthor:
            return full_object != nullptr && !full_object->author.empty();
        case RuleConditionKind::NoCycles:
        case RuleConditionKind::NoIsolatedObjects:
            return true; // graph-level conditions are evaluated separately, never per-object
    }
    errored = true;
    return false;
}

bool has_graph_level_kind(const std::vector<RuleCondition>& conditions, RuleConditionKind kind) {
    return std::any_of(conditions.begin(), conditions.end(), [kind](const RuleCondition& c) { return c.kind == kind; });
}

// Deterministic directed-cycle detection restricted to edges of one
// relationship type (or every edge, if unset) -- same DFS-with-
// recursion-stack shape as WP-EKE-002's graph_validator.cpp, visiting
// nodes and outgoing edges in ascending id order.
std::optional<std::string> find_cycle_description(const KnowledgeGraph& graph,
                                                    const std::optional<oep::repository::RelationshipType>& type_filter) {
    std::map<std::string, std::vector<std::string>> outgoing;
    for (const KnowledgeGraphEdge& edge : graph.all_edges()) {
        if (type_filter.has_value() && edge.relationship_type != *type_filter) continue;
        outgoing[edge.source_object_id].push_back(edge.target_object_id);
    }
    for (auto& [id, neighbors] : outgoing) {
        std::sort(neighbors.begin(), neighbors.end());
    }

    std::vector<std::string> ordered_ids;
    for (const KnowledgeGraphNode* node : graph.all_nodes()) {
        ordered_ids.push_back(node->object_id);
    }

    std::set<std::string> visited;
    std::set<std::string> on_stack;
    std::vector<std::string> path;
    std::optional<std::string> description;

    std::function<bool(const std::string&)> visit = [&](const std::string& id) -> bool {
        visited.insert(id);
        on_stack.insert(id);
        path.push_back(id);
        const auto found = outgoing.find(id);
        if (found != outgoing.end()) {
            for (const std::string& next : found->second) {
                if (on_stack.count(next) != 0) {
                    path.push_back(next);
                    std::string text;
                    const auto start_it = std::find(path.begin(), path.end(), next);
                    for (auto it = start_it; it != path.end(); ++it) {
                        text += *it;
                        if (std::next(it) != path.end()) text += " -> ";
                    }
                    description = text;
                    return true;
                }
                if (visited.count(next) == 0 && visit(next)) return true;
            }
        }
        path.pop_back();
        on_stack.erase(id);
        return false;
    };

    for (const std::string& id : ordered_ids) {
        if (visited.count(id) == 0 && visit(id)) break;
    }
    return description;
}

} // namespace

RuleEvaluationResult RuleEvaluator::evaluate(const EngineeringRule& rule, const RuleEvaluationContext& context) {
    const KnowledgeGraph& graph = context.graph();
    const std::vector<std::string> scoped_ids = resolve_scope(rule.scope(), graph);

    std::vector<std::string> affected_objects;
    std::vector<RuleDiagnostic> diagnostics;
    bool any_error = false;

    for (const std::string& object_id : scoped_ids) {
        for (const RuleCondition& condition : rule.conditions()) {
            if (condition.kind == RuleConditionKind::NoCycles || condition.kind == RuleConditionKind::NoIsolatedObjects) {
                continue; // handled once, below
            }
            bool errored = false;
            const oep::repository::EngineeringObject* full_object =
                context.engineering_context().graph().find_object(object_id);
            const bool ok = check_object_condition(condition, object_id, graph, full_object, errored);
            if (errored) {
                any_error = true;
                diagnostics.push_back({object_id, "condition '" + to_string(condition.kind) + "' is missing a required parameter"});
                continue;
            }
            if (!ok) {
                affected_objects.push_back(object_id);
                diagnostics.push_back({object_id, "failed condition '" + to_string(condition.kind) + "'"});
            }
        }
    }

    // NoIsolatedObjects: within scope, every object must have >=1 edge.
    if (has_graph_level_kind(rule.conditions(), RuleConditionKind::NoIsolatedObjects)) {
        for (const std::string& object_id : scoped_ids) {
            if (graph.edges_of(object_id).empty()) {
                affected_objects.push_back(object_id);
                diagnostics.push_back({object_id, "object is isolated (no relationships)"});
            }
        }
    }

    // NoCycles: graph-level, ignores scope, checked once per matching condition.
    for (const RuleCondition& condition : rule.conditions()) {
        if (condition.kind != RuleConditionKind::NoCycles) continue;
        const std::optional<std::string> cycle = find_cycle_description(graph, condition.relationship_type);
        if (cycle.has_value()) {
            diagnostics.push_back({"", "cycle detected: " + *cycle});
        }
    }

    std::sort(affected_objects.begin(), affected_objects.end());
    affected_objects.erase(std::unique(affected_objects.begin(), affected_objects.end()), affected_objects.end());

    RuleEvaluationStatus status;
    if (any_error) {
        status = RuleEvaluationStatus::Error;
    } else if (!diagnostics.empty()) {
        status = RuleEvaluationStatus::Failed;
    } else if (scoped_ids.empty() && !has_graph_level_kind(rule.conditions(), RuleConditionKind::NoCycles)) {
        status = RuleEvaluationStatus::NotApplicable;
    } else {
        status = RuleEvaluationStatus::Passed;
    }

    const std::string message = status == RuleEvaluationStatus::Passed        ? "rule satisfied"
                                 : status == RuleEvaluationStatus::NotApplicable ? "rule scope matched no objects"
                                 : status == RuleEvaluationStatus::Error         ? "rule could not be evaluated: " + rule.message()
                                                                                  : rule.message();

    return RuleEvaluationResult(rule, status, message, std::move(affected_objects), std::move(diagnostics));
}

} // namespace oep::engine
