#pragma once

#include <string>
#include <vector>

namespace oep::engine {

// WP-EKE-006's Analysis Reports. All immutable, all pure data derived
// from deterministic graph traversals the Analysis Engine already
// performed -- no field here is guessed or inferred; every list is the
// literal, reproducible result of a graph algorithm run against the
// Knowledge Graph (WP-EKE-002) at the time of the call. `evidence`
// names exactly which underlying algorithm/data produced the report,
// satisfying "every conclusion must reference its supporting evidence"
// at the Analysis Engine's own (structural, non-reasoning) level; the
// Reasoning Engine's EngineeringConclusion (reasoning_types.hpp) is
// where evidence referencing becomes fully structured.

// Dependency Analysis + Dependency Tree Generation: the transitive
// outgoing DependsOn closure of `object_id`, in the flattened form
// `dependency_graph`/`relationship_ids` (deterministic BFS order --
// see EngineeringContext::dependency_graph, whose algorithm this
// reuses via AnalysisEngine rather than duplicating).
class DependencyReport {
public:
    DependencyReport(std::string object_id, std::vector<std::string> dependency_object_ids,
                      std::vector<std::string> dependency_relationship_ids, int max_depth, std::string evidence)
        : object_id_(std::move(object_id)),
          dependency_object_ids_(std::move(dependency_object_ids)),
          dependency_relationship_ids_(std::move(dependency_relationship_ids)),
          max_depth_(max_depth),
          evidence_(std::move(evidence)) {}

    const std::string& object_id() const { return object_id_; }
    const std::vector<std::string>& dependency_object_ids() const { return dependency_object_ids_; }
    const std::vector<std::string>& dependency_relationship_ids() const { return dependency_relationship_ids_; }
    int max_depth() const { return max_depth_; }
    const std::string& evidence() const { return evidence_; }

private:
    std::string object_id_;
    std::vector<std::string> dependency_object_ids_;
    std::vector<std::string> dependency_relationship_ids_;
    int max_depth_;
    std::string evidence_;
};

// Impact Analysis + Change Propagation + Affected Object Discovery: the
// transitive INCOMING DependsOn closure of `object_id` -- every object
// that would be affected, directly or indirectly, by a change to
// `object_id` (the reverse of DependencyReport's direction).
class ImpactReport {
public:
    ImpactReport(std::string object_id, std::vector<std::string> affected_object_ids,
                 std::vector<std::string> affected_relationship_ids, int max_depth, std::string evidence)
        : object_id_(std::move(object_id)),
          affected_object_ids_(std::move(affected_object_ids)),
          affected_relationship_ids_(std::move(affected_relationship_ids)),
          max_depth_(max_depth),
          evidence_(std::move(evidence)) {}

    const std::string& object_id() const { return object_id_; }
    const std::vector<std::string>& affected_object_ids() const { return affected_object_ids_; }
    const std::vector<std::string>& affected_relationship_ids() const { return affected_relationship_ids_; }
    int max_depth() const { return max_depth_; }
    const std::string& evidence() const { return evidence_; }

private:
    std::string object_id_;
    std::vector<std::string> affected_object_ids_;
    std::vector<std::string> affected_relationship_ids_;
    int max_depth_;
    std::string evidence_;
};

// Reachability Analysis: whether `target_object_id` is reachable from
// `source_object_id` (any relationship type, either direction -- same
// connectivity convention as GraphAlgorithms::shortest_path), and the
// shortest path if so.
class ReachabilityReport {
public:
    ReachabilityReport(std::string source_object_id, std::string target_object_id, bool reachable,
                        std::vector<std::string> path, std::string evidence)
        : source_object_id_(std::move(source_object_id)),
          target_object_id_(std::move(target_object_id)),
          reachable_(reachable),
          path_(std::move(path)),
          evidence_(std::move(evidence)) {}

    const std::string& source_object_id() const { return source_object_id_; }
    const std::string& target_object_id() const { return target_object_id_; }
    bool reachable() const { return reachable_; }
    const std::vector<std::string>& path() const { return path_; }
    const std::string& evidence() const { return evidence_; }

private:
    std::string source_object_id_;
    std::string target_object_id_;
    bool reachable_;
    std::vector<std::string> path_;
    std::string evidence_;
};

// Root Cause Analysis + Failure Chain Analysis: given a `symptom_object_id`
// with one or more validation findings, `candidate_root_causes` lists
// every one of its transitive DEPENDENCIES (via DependencyReport's own
// closure) that ALSO has at least one validation finding, ordered by
// ascending dependency depth (the closest, most likely proximate
// cause first -- deterministic tie-break by object_id). `failure_chain`
// is the shortest DependsOn path from the first (closest) candidate to
// the symptom, if any candidate was found.
class RootCauseReport {
public:
    RootCauseReport(std::string symptom_object_id, std::vector<std::string> candidate_root_causes,
                     std::vector<std::string> failure_chain, std::string evidence)
        : symptom_object_id_(std::move(symptom_object_id)),
          candidate_root_causes_(std::move(candidate_root_causes)),
          failure_chain_(std::move(failure_chain)),
          evidence_(std::move(evidence)) {}

    const std::string& symptom_object_id() const { return symptom_object_id_; }
    const std::vector<std::string>& candidate_root_causes() const { return candidate_root_causes_; }
    const std::vector<std::string>& failure_chain() const { return failure_chain_; }
    const std::string& evidence() const { return evidence_; }

private:
    std::string symptom_object_id_;
    std::vector<std::string> candidate_root_causes_;
    std::vector<std::string> failure_chain_;
    std::string evidence_;
};

} // namespace oep::engine
