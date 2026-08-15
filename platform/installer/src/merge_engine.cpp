#include "oep/installer/merge_engine.hpp"

#include <algorithm>
#include <map>
#include <set>

namespace oep::installer {

namespace {

bool objects_equal_in_content(const oep::repository::EngineeringObject& a, const oep::repository::EngineeringObject& b) {
    // Deliberately excludes created_utc/last_modified_utc: those are
    // bookkeeping, not content, and would make an otherwise-identical
    // object look like a conflict purely because it was re-extracted at
    // a different moment.
    return a.object_type == b.object_type && a.name == b.name && a.description == b.description &&
           a.version == b.version && a.author == b.author && a.tags == b.tags;
}

bool relationships_equal_in_content(const oep::repository::Relationship& a, const oep::repository::Relationship& b) {
    return a.source_object_id == b.source_object_id && a.target_object_id == b.target_object_id &&
           a.relationship_type == b.relationship_type && a.author == b.author && a.description == b.description;
}

} // namespace

std::string to_string(MergeConflictKind kind) {
    switch (kind) {
        case MergeConflictKind::ObjectContentConflict: return "ObjectContentConflict";
        case MergeConflictKind::RelationshipContentConflict: return "RelationshipContentConflict";
        case MergeConflictKind::RelationshipMissingEndpoint: return "RelationshipMissingEndpoint";
    }
    return "Unknown";
}

MergePlan plan_merge(const std::string& source_id, const std::vector<oep::repository::EngineeringObject>& source_objects,
                      const std::vector<oep::repository::Relationship>& source_relationships,
                      const std::vector<oep::repository::EngineeringObject>& target_objects,
                      const std::vector<oep::repository::Relationship>& target_relationships) {
    std::map<std::string, const oep::repository::EngineeringObject*> target_objects_by_id;
    for (const oep::repository::EngineeringObject& object : target_objects) {
        target_objects_by_id[object.object_id] = &object;
    }
    std::map<std::string, const oep::repository::Relationship*> target_relationships_by_id;
    for (const oep::repository::Relationship& relationship : target_relationships) {
        target_relationships_by_id[relationship.relationship_id] = &relationship;
    }

    std::vector<ObjectChange> object_changes;
    std::vector<MergeConflict> conflicts;
    // Every object_id this plan will make present in the target once
    // applied -- either already there, or newly created by this plan --
    // so relationship endpoint checks below can see forward to objects
    // this same merge is about to create.
    std::set<std::string> objects_present_after_merge;
    for (const auto& [id, unused] : target_objects_by_id) {
        objects_present_after_merge.insert(id);
    }

    for (const oep::repository::EngineeringObject& source_object : source_objects) {
        const auto found = target_objects_by_id.find(source_object.object_id);
        if (found == target_objects_by_id.end()) {
            object_changes.emplace_back(ChangeKind::Create, source_object, source_id, source_object.object_id);
            objects_present_after_merge.insert(source_object.object_id);
        } else if (!objects_equal_in_content(source_object, *found->second)) {
            conflicts.push_back({MergeConflictKind::ObjectContentConflict, source_object.object_id,
                                  "an Engineering Object with this id already exists with different content ('" +
                                      found->second->name + "' vs '" + source_object.name + "')"});
        }
        // else: identical content already present -- a benign no-op,
        // not included in the change set.
    }

    std::vector<RelationshipChange> relationship_changes;
    for (const oep::repository::Relationship& source_relationship : source_relationships) {
        if (objects_present_after_merge.find(source_relationship.source_object_id) ==
                objects_present_after_merge.end() ||
            objects_present_after_merge.find(source_relationship.target_object_id) ==
                objects_present_after_merge.end()) {
            conflicts.push_back({MergeConflictKind::RelationshipMissingEndpoint, source_relationship.relationship_id,
                                  "references an object id that is neither already present in the target "
                                  "repository nor included in this merge"});
            continue;
        }

        const auto found = target_relationships_by_id.find(source_relationship.relationship_id);
        if (found == target_relationships_by_id.end()) {
            relationship_changes.emplace_back(ChangeKind::Create, source_relationship, source_id,
                                                source_relationship.relationship_id);
        } else if (!relationships_equal_in_content(source_relationship, *found->second)) {
            conflicts.push_back({MergeConflictKind::RelationshipContentConflict, source_relationship.relationship_id,
                                  "a Relationship with this id already exists with different content"});
        }
    }

    RepositoryChangeSet change_set(source_id, "merge " + source_id, std::move(object_changes),
                                    std::move(relationship_changes));
    return MergePlan{std::move(change_set), std::move(conflicts)};
}

} // namespace oep::installer
