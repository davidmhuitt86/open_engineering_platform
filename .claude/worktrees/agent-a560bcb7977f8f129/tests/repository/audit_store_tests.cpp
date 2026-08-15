#include "oep/repository/audit_event.hpp"
#include "oep/repository/audit_store.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/repository/relationship_store.hpp"

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

bool contains_event_type(const std::vector<oep::repository::AuditEvent>& events,
                          oep::repository::AuditEventType type) {
    return std::any_of(events.begin(), events.end(),
                        [type](const oep::repository::AuditEvent& event) { return event.event_type == type; });
}

void test_record_and_list(const std::filesystem::path& scratch_dir) {
    const oep::repository::AuditStore audit(scratch_dir / "record_and_list");

    oep::repository::AuditEvent event;
    event.event_type = oep::repository::AuditEventType::RepositoryCreated;
    event.description = "Repository initialized";

    const oep::repository::RecordEventResult recorded = audit.record_event(event);
    check(recorded.success, "record_event succeeds for a valid event");
    check(!recorded.event.event_id.empty(), "record_event assigns an eventId");
    check(!recorded.event.timestamp_utc.empty(), "record_event assigns a timestampUtc");

    const oep::repository::ListAuditEventsResult listed = audit.list_events();
    check(listed.success && listed.events.size() == 1, "list_events finds the recorded event");
}

void test_list_events_for_object(const std::filesystem::path& scratch_dir) {
    const oep::repository::AuditStore audit(scratch_dir / "for_object");

    oep::repository::AuditEvent for_a;
    for_a.event_type = oep::repository::AuditEventType::ObjectCreated;
    for_a.object_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    check(audit.record_event(for_a).success, "recording the event for object A succeeds");

    oep::repository::AuditEvent for_b;
    for_b.event_type = oep::repository::AuditEventType::ObjectCreated;
    for_b.object_id = "2b9e1b02-e845-482a-b299-1e15ffe3932b";
    check(audit.record_event(for_b).success, "recording the event for object B succeeds");

    const oep::repository::ListAuditEventsResult for_object_a =
        audit.list_events_for_object("1b9e1b02-e845-482a-b299-1e15ffe3932b");
    check(for_object_a.success && for_object_a.events.size() == 1,
          "list_events_for_object finds only the event for object A");
}

void test_validation_rejects_missing_timestamp() {
    oep::repository::AuditEvent event;
    event.event_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    event.timestamp_utc = "";

    const std::vector<std::string> errors = oep::repository::validate_audit_event(event);
    check(!errors.empty(), "validate_audit_event rejects a missing timestampUtc");
}

void test_validation_rejects_bad_object_id() {
    oep::repository::AuditEvent event;
    event.event_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    event.timestamp_utc = "2026-01-01T00:00:00Z";
    event.object_id = "not-a-uuid";

    const std::vector<std::string> errors = oep::repository::validate_audit_event(event);
    check(!errors.empty(), "validate_audit_event rejects a malformed objectId");
}

void test_clear(const std::filesystem::path& scratch_dir) {
    const oep::repository::AuditStore audit(scratch_dir / "clear");

    oep::repository::AuditEvent event;
    event.event_type = oep::repository::AuditEventType::ObjectDeleted;
    check(audit.record_event(event).success, "recording an event before clear succeeds");

    check(audit.clear().success, "clear succeeds");

    const oep::repository::ListAuditEventsResult listed = audit.list_events();
    check(listed.success && listed.events.empty(), "list_events is empty after clear");
}

void test_object_lifecycle_records_events_automatically(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "object_integration";
    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);

    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = "Ignition Coil";
    object.version = "1.0.0";

    const oep::repository::LoadObjectResult created = objects.create(object);
    check(created.success, "creating the object succeeds");

    oep::repository::EngineeringObject updated = created.object;
    updated.name = "Ignition Coil (Rev B)";
    check(objects.update(updated).success, "updating the object succeeds");

    check(objects.remove(created.object.object_id).success, "removing the object succeeds");

    const oep::repository::ListAuditEventsResult events =
        audit.list_events_for_object(created.object.object_id);
    check(events.success, "listing audit events for the object succeeds");
    check(events.events.size() == 3, "create/update/remove each recorded exactly one audit event");
    check(contains_event_type(events.events, oep::repository::AuditEventType::ObjectCreated),
          "an ObjectCreated event was recorded automatically");
    check(contains_event_type(events.events, oep::repository::AuditEventType::ObjectUpdated),
          "an ObjectUpdated event was recorded automatically");
    check(contains_event_type(events.events, oep::repository::AuditEventType::ObjectDeleted),
          "an ObjectDeleted event was recorded automatically");
}

void test_relationship_lifecycle_records_events_automatically(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "relationship_integration";
    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);

    oep::repository::EngineeringObject source_object;
    source_object.object_type = oep::repository::ObjectType::Document;
    source_object.name = "Manual";
    source_object.version = "1.0.0";
    const oep::repository::LoadObjectResult source = objects.create(source_object);

    oep::repository::EngineeringObject target_object;
    target_object.object_type = oep::repository::ObjectType::Component;
    target_object.name = "Coil";
    target_object.version = "1.0.0";
    const oep::repository::LoadObjectResult target = objects.create(target_object);

    check(source.success && target.success, "creating the two sample objects succeeds");

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = target.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::Documents;

    const oep::repository::LoadRelationshipResult created = relationships.create(relationship);
    check(created.success, "creating the relationship succeeds");

    oep::repository::Relationship updated = created.relationship;
    updated.description = "Updated";
    check(relationships.update(updated).success, "updating the relationship succeeds");

    check(relationships.remove(created.relationship.relationship_id).success, "removing the relationship succeeds");

    const oep::repository::ListAuditEventsResult events =
        audit.list_events_for_object(created.relationship.relationship_id);
    check(events.success, "listing audit events for the relationship succeeds");
    check(events.events.size() == 3, "create/update/remove each recorded exactly one audit event");
    check(contains_event_type(events.events, oep::repository::AuditEventType::RelationshipCreated),
          "a RelationshipCreated event was recorded automatically");
    check(contains_event_type(events.events, oep::repository::AuditEventType::RelationshipUpdated),
          "a RelationshipUpdated event was recorded automatically");
    check(contains_event_type(events.events, oep::repository::AuditEventType::RelationshipDeleted),
          "a RelationshipDeleted event was recorded automatically");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_audit_store_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_record_and_list(scratch_dir);
    test_list_events_for_object(scratch_dir);
    test_validation_rejects_missing_timestamp();
    test_validation_rejects_bad_object_id();
    test_clear(scratch_dir);
    test_object_lifecycle_records_events_automatically(scratch_dir);
    test_relationship_lifecycle_records_events_automatically(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All audit store tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " audit store test(s) failed.\n";
    return 1;
}
