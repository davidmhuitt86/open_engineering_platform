#include "oep/repository/engineering_object.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship.hpp"
#include "oep/repository/relationship_store.hpp"

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

oep::repository::EngineeringObject sample_object(const std::string& name) {
    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = name;
    object.version = "1.0.0";
    return object;
}

void test_create_succeeds_for_existing_objects(const oep::repository::ObjectStore& objects,
                                                 const oep::repository::RelationshipStore& relationships) {
    const oep::repository::LoadObjectResult source = objects.create(sample_object("Wiring Harness"));
    const oep::repository::LoadObjectResult target = objects.create(sample_object("ECU"));
    check(source.success && target.success, "creating the two sample objects succeeds");

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = target.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::ConnectedTo;
    relationship.author = "Test Author";
    relationship.description = "Harness connects to ECU";

    const oep::repository::LoadRelationshipResult result = relationships.create(relationship);
    check(result.success, "create succeeds when both objects exist");
    check(!result.relationship.relationship_id.empty(), "create assigns a relationshipId");
    check(!result.relationship.created_utc.empty(), "create assigns createdUtc");
}

void test_create_fails_for_missing_object(const oep::repository::ObjectStore& objects,
                                           const oep::repository::RelationshipStore& relationships) {
    const oep::repository::LoadObjectResult source = objects.create(sample_object("Sensor"));
    check(source.success, "creating the sample object succeeds");

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = "00000000-0000-4000-8000-000000000000"; // does not exist
    relationship.relationship_type = oep::repository::RelationshipType::References;

    const oep::repository::LoadRelationshipResult result = relationships.create(relationship);
    check(!result.success, "create fails when the target object does not exist");
}

void test_create_fails_for_matching_source_and_target(const oep::repository::ObjectStore& objects,
                                                        const oep::repository::RelationshipStore& relationships) {
    const oep::repository::LoadObjectResult object = objects.create(sample_object("Self"));
    check(object.success, "creating the sample object succeeds");

    oep::repository::Relationship relationship;
    relationship.source_object_id = object.object.object_id;
    relationship.target_object_id = object.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::References;

    const oep::repository::LoadRelationshipResult result = relationships.create(relationship);
    check(!result.success, "create fails when sourceObjectId equals targetObjectId");
}

void test_load_round_trips(const oep::repository::ObjectStore& objects,
                            const oep::repository::RelationshipStore& relationships) {
    const oep::repository::LoadObjectResult source = objects.create(sample_object("Battery"));
    const oep::repository::LoadObjectResult target = objects.create(sample_object("Fuse Box"));

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = target.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::DependsOn;

    const oep::repository::LoadRelationshipResult created = relationships.create(relationship);
    check(created.success, "create succeeds before load test");

    const oep::repository::LoadRelationshipResult loaded = relationships.load(created.relationship.relationship_id);
    check(loaded.success, "load succeeds for an existing relationship");
    check(loaded.relationship.source_object_id == source.object.object_id, "load preserves sourceObjectId");
    check(loaded.relationship.target_object_id == target.object.object_id, "load preserves targetObjectId");
    check(loaded.relationship.relationship_type == oep::repository::RelationshipType::DependsOn,
          "load preserves relationshipType");
}

void test_update_preserves_immutable_fields(const oep::repository::ObjectStore& objects,
                                             const oep::repository::RelationshipStore& relationships) {
    const oep::repository::LoadObjectResult source = objects.create(sample_object("Diagram A"));
    const oep::repository::LoadObjectResult target = objects.create(sample_object("Procedure B"));

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = target.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::Documents;
    relationship.description = "Original description";

    const oep::repository::LoadRelationshipResult created = relationships.create(relationship);
    check(created.success, "create succeeds before update test");

    oep::repository::Relationship updated = created.relationship;
    updated.description = "Updated description";
    updated.relationship_type = oep::repository::RelationshipType::Implements; // attempt to change; must be ignored
    updated.target_object_id = source.object.object_id; // attempt to change; must be ignored

    const oep::repository::RelationshipResult update_result = relationships.update(updated);
    check(update_result.success, "update succeeds for an existing relationship");

    const oep::repository::LoadRelationshipResult reloaded = relationships.load(created.relationship.relationship_id);
    check(reloaded.success, "load succeeds after update");
    check(reloaded.relationship.description == "Updated description", "update applies the new description");
    check(reloaded.relationship.relationship_type == oep::repository::RelationshipType::Documents,
          "update preserves the original relationshipType");
    check(reloaded.relationship.target_object_id == target.object.object_id,
          "update preserves the original targetObjectId");
}

void test_remove_deletes_relationship(const oep::repository::ObjectStore& objects,
                                       const oep::repository::RelationshipStore& relationships) {
    const oep::repository::LoadObjectResult source = objects.create(sample_object("Cable"));
    const oep::repository::LoadObjectResult target = objects.create(sample_object("Connector"));

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = target.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::ConnectedTo;

    const oep::repository::LoadRelationshipResult created = relationships.create(relationship);
    check(created.success, "create succeeds before remove test");

    const oep::repository::RelationshipResult remove_result =
        relationships.remove(created.relationship.relationship_id);
    check(remove_result.success, "remove succeeds for an existing relationship");

    const oep::repository::LoadRelationshipResult reloaded = relationships.load(created.relationship.relationship_id);
    check(!reloaded.success, "load fails after the relationship has been removed");
}

void test_list_by_object_enumerates_both_directions(const oep::repository::ObjectStore& objects,
                                                      const oep::repository::RelationshipStore& relationships) {
    const oep::repository::LoadObjectResult hub = objects.create(sample_object("Hub"));
    const oep::repository::LoadObjectResult leaf_a = objects.create(sample_object("Leaf A"));
    const oep::repository::LoadObjectResult leaf_b = objects.create(sample_object("Leaf B"));

    oep::repository::Relationship outgoing;
    outgoing.source_object_id = hub.object.object_id;
    outgoing.target_object_id = leaf_a.object.object_id;
    outgoing.relationship_type = oep::repository::RelationshipType::Contains;
    check(relationships.create(outgoing).success, "creating the outgoing relationship succeeds");

    oep::repository::Relationship incoming;
    incoming.source_object_id = leaf_b.object.object_id;
    incoming.target_object_id = hub.object.object_id;
    incoming.relationship_type = oep::repository::RelationshipType::References;
    check(relationships.create(incoming).success, "creating the incoming relationship succeeds");

    const oep::repository::ListRelationshipsResult result = relationships.list_by_object(hub.object.object_id);
    check(result.success, "list_by_object succeeds");
    check(result.relationships.size() == 2, "list_by_object finds relationships in both directions");
}

void test_validation_rejects_matching_ids() {
    oep::repository::Relationship relationship;
    relationship.relationship_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    relationship.source_object_id = "2b9e1b02-e845-482a-b299-1e15ffe3932b";
    relationship.target_object_id = "2b9e1b02-e845-482a-b299-1e15ffe3932b";
    relationship.created_utc = "2026-01-01T00:00:00Z";

    const std::vector<std::string> errors = oep::repository::validate_relationship(relationship);
    check(!errors.empty(), "validate_relationship rejects matching source/target ids");
}

void test_validation_rejects_bad_uuid() {
    oep::repository::Relationship relationship;
    relationship.relationship_id = "not-a-uuid";
    relationship.source_object_id = "2b9e1b02-e845-482a-b299-1e15ffe3932b";
    relationship.target_object_id = "3b9e1b02-e845-482a-b299-1e15ffe3932b";
    relationship.created_utc = "2026-01-01T00:00:00Z";

    const std::vector<std::string> errors = oep::repository::validate_relationship(relationship);
    check(!errors.empty(), "validate_relationship rejects a malformed relationshipId");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_relationship_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    const oep::repository::ObjectStore objects(scratch_dir / "objects",
                                                oep::repository::AuditStore(scratch_dir / "audit"));
    const oep::repository::RelationshipStore relationships(
        scratch_dir / "relationships", objects, oep::repository::AuditStore(scratch_dir / "audit"));

    test_create_succeeds_for_existing_objects(objects, relationships);
    test_create_fails_for_missing_object(objects, relationships);
    test_create_fails_for_matching_source_and_target(objects, relationships);
    test_load_round_trips(objects, relationships);
    test_update_preserves_immutable_fields(objects, relationships);
    test_remove_deletes_relationship(objects, relationships);
    test_list_by_object_enumerates_both_directions(objects, relationships);
    test_validation_rejects_matching_ids();
    test_validation_rejects_bad_uuid();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All relationship tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " relationship test(s) failed.\n";
    return 1;
}
