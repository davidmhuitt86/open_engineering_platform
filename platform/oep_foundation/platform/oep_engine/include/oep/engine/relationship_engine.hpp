#pragma once

#include <string>
#include <vector>

#include "oep/engine/runtime_graph.hpp"

namespace oep::engine {

struct RelatedObjectsResult {
    bool success = false;
    std::string error;
    std::vector<std::string> object_ids; // sorted, deduplicated
};

// WP-EKE-001's Relationship Engine: classifies `graph`'s edges touching
// one object into the categories the work package names explicitly.
// All read-only against `graph` (an already-loaded RuntimeGraph); none
// of these query Foundation or RuntimeService directly -- by the time a
// caller has a RuntimeGraph to pass in, it was already built from data
// fetched via RuntimeService (see EngineeringContext::load_graph).
//
// Classification, per OEP-SPEC-005's RelationshipType vocabulary:
//   - parents(id):   Contains edges where `id` is the TARGET (the
//                     source is `id`'s parent).
//   - children(id):  Contains edges where `id` is the SOURCE (the
//                     target is `id`'s child).
//   - neighbors(id):/related_objects(id): every directly connected
//                     object, any relationship type, either direction.
//   - references(id): References edges where `id` is the source
//                     (objects `id` references).
//   - dependencies(id): DependsOn edges where `id` is the source
//                     (objects `id` depends on).
class RelationshipEngine {
public:
    static RelatedObjectsResult parents(const RuntimeGraph& graph, const std::string& object_id);
    static RelatedObjectsResult children(const RuntimeGraph& graph, const std::string& object_id);
    static RelatedObjectsResult neighbors(const RuntimeGraph& graph, const std::string& object_id);
    static RelatedObjectsResult references(const RuntimeGraph& graph, const std::string& object_id);
    static RelatedObjectsResult dependencies(const RuntimeGraph& graph, const std::string& object_id);
};

} // namespace oep::engine
