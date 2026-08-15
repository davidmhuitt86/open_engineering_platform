#include "oep/validation/repository_validator.hpp"

#include <algorithm>
#include <set>

#include "oep/repository/metadata.hpp"

namespace oep::validation {

namespace {

template <typename T, typename KeyFn>
void sort_by_key(std::vector<T>& items, KeyFn key_fn) {
    std::sort(items.begin(), items.end(),
              [&key_fn](const T& a, const T& b) { return key_fn(a) < key_fn(b); });
}

} // namespace

RepositoryValidator::RepositoryValidator(std::filesystem::path metadata_path, oep::repository::ObjectStore objects,
                                          oep::repository::RelationshipStore relationships,
                                          oep::repository::AuditStore audit)
    : metadata_path_(std::move(metadata_path)),
      objects_(std::move(objects)),
      relationships_(std::move(relationships)),
      audit_(std::move(audit)) {}

std::vector<ValidationFinding> RepositoryValidator::validate_metadata() const {
    std::vector<ValidationFinding> findings;

    const oep::repository::LoadMetadataResult loaded = oep::repository::load_metadata(metadata_path_);
    if (!loaded.success) {
        findings.push_back({Severity::Error, "Metadata",
                             "repository metadata does not exist or is invalid: " + loaded.error, ""});
        return findings;
    }

    for (const std::string& error : oep::repository::validate_metadata(loaded.metadata)) {
        findings.push_back({Severity::Error, "Metadata", error, ""});
    }

    return findings;
}

std::vector<ValidationFinding> RepositoryValidator::validate_objects() const {
    std::vector<ValidationFinding> findings;

    const oep::repository::ListObjectsResult listed = objects_.list_all();
    if (!listed.success) {
        findings.push_back({Severity::Error, "Objects", listed.error, ""});
        return findings;
    }

    for (const std::string& invalid_entry : listed.invalid_entries) {
        findings.push_back({Severity::Error, "Objects", "invalid object file: " + invalid_entry, ""});
    }

    std::vector<oep::repository::EngineeringObject> objects = listed.objects;
    sort_by_key(objects, [](const oep::repository::EngineeringObject& object) { return object.object_id; });

    std::set<std::string> seen_ids;
    for (const oep::repository::EngineeringObject& object : objects) {
        if (!seen_ids.insert(object.object_id).second) {
            findings.push_back(
                {Severity::Error, "Objects", "duplicate object ID '" + object.object_id + "'", object.object_id});
        }
    }

    return findings;
}

std::vector<ValidationFinding> RepositoryValidator::validate_relationships() const {
    std::vector<ValidationFinding> findings;

    const oep::repository::ListRelationshipsResult listed = relationships_.list_all();
    if (!listed.success) {
        findings.push_back({Severity::Error, "Relationships", listed.error, ""});
        return findings;
    }

    for (const std::string& invalid_entry : listed.invalid_entries) {
        findings.push_back({Severity::Error, "Relationships", "invalid relationship file: " + invalid_entry, ""});
    }

    std::vector<oep::repository::Relationship> relationships = listed.relationships;
    sort_by_key(relationships,
                [](const oep::repository::Relationship& relationship) { return relationship.relationship_id; });

    std::set<std::string> seen_ids;
    for (const oep::repository::Relationship& relationship : relationships) {
        if (!seen_ids.insert(relationship.relationship_id).second) {
            findings.push_back({Severity::Error, "Relationships",
                                 "duplicate relationship ID '" + relationship.relationship_id + "'",
                                 relationship.relationship_id});
        }

        if (!objects_.load(relationship.source_object_id).success) {
            findings.push_back({Severity::Error, "Relationships",
                                 "relationship '" + relationship.relationship_id +
                                     "' references a nonexistent sourceObjectId '" +
                                     relationship.source_object_id + "'",
                                 relationship.relationship_id});
        }
        if (!objects_.load(relationship.target_object_id).success) {
            findings.push_back({Severity::Error, "Relationships",
                                 "relationship '" + relationship.relationship_id +
                                     "' references a nonexistent targetObjectId '" +
                                     relationship.target_object_id + "'",
                                 relationship.relationship_id});
        }
    }

    return findings;
}

namespace {

// Audit events for these event types describe an entity that should
// currently exist; *Deleted events legitimately reference an entity
// that no longer does, so they are not checked here.
bool implies_current_existence(oep::repository::AuditEventType type) {
    switch (type) {
        case oep::repository::AuditEventType::ObjectCreated:
        case oep::repository::AuditEventType::ObjectUpdated:
        case oep::repository::AuditEventType::RelationshipCreated:
        case oep::repository::AuditEventType::RelationshipUpdated:
            return true;
        default:
            return false;
    }
}

bool is_relationship_event(oep::repository::AuditEventType type) {
    return type == oep::repository::AuditEventType::RelationshipCreated ||
           type == oep::repository::AuditEventType::RelationshipUpdated;
}

} // namespace

ValidationReport RepositoryValidator::validate_repository() const {
    std::vector<ValidationFinding> findings = validate_metadata();

    const std::vector<ValidationFinding> object_findings = validate_objects();
    findings.insert(findings.end(), object_findings.begin(), object_findings.end());

    const std::vector<ValidationFinding> relationship_findings = validate_relationships();
    findings.insert(findings.end(), relationship_findings.begin(), relationship_findings.end());

    // Cross-cutting: no UUID reused across objects and relationships.
    const oep::repository::ListObjectsResult objects_listed = objects_.list_all();
    const oep::repository::ListRelationshipsResult relationships_listed = relationships_.list_all();
    if (objects_listed.success && relationships_listed.success) {
        std::set<std::string> object_ids;
        for (const oep::repository::EngineeringObject& object : objects_listed.objects) {
            object_ids.insert(object.object_id);
        }
        std::vector<std::string> collisions;
        for (const oep::repository::Relationship& relationship : relationships_listed.relationships) {
            if (object_ids.count(relationship.relationship_id) != 0) {
                collisions.push_back(relationship.relationship_id);
            }
        }
        std::sort(collisions.begin(), collisions.end());
        for (const std::string& collision : collisions) {
            findings.push_back({Severity::Error, "Integrity",
                                 "UUID '" + collision + "' is used by both an object and a relationship",
                                 collision});
        }
    }

    // Cross-cutting: audit events reference an existing object/relationship
    // when the event type implies one currently should.
    const oep::repository::ListAuditEventsResult events_listed = audit_.list_events();
    if (events_listed.success) {
        for (const oep::repository::AuditEvent& event : events_listed.events) {
            if (event.object_id.empty() || !implies_current_existence(event.event_type)) {
                continue;
            }
            const bool exists = is_relationship_event(event.event_type)
                                     ? relationships_.load(event.object_id).success
                                     : objects_.load(event.object_id).success;
            if (!exists) {
                findings.push_back({Severity::Warning, "Audit",
                                     "audit event '" + event.event_id + "' (" +
                                         oep::repository::to_string(event.event_type) +
                                         ") references an object or relationship that no longer exists",
                                     event.object_id});
            }
        }
    }

    return generate_validation_report(std::move(findings));
}

} // namespace oep::validation
