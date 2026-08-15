#include "oep/repository/batch_processor.hpp"

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

void test_parse_create_rejects_malformed_json() {
    const oep::repository::BatchParseResult result = oep::repository::parse_batch_create_request("{ not json ");
    check(!result.success, "parsing malformed batch-create JSON fails");
}

void test_parse_create_rejects_unrecognized_type() {
    const oep::repository::BatchParseResult result = oep::repository::parse_batch_create_request(
        R"({"objects":[{"ref":"a","type":"NotARealType","name":"A"}]})");
    check(!result.success, "parsing a batch with an unrecognized object type fails");
}

void test_parse_delete_rejects_malformed_json() {
    const oep::repository::BatchDeleteParseResult result = oep::repository::parse_batch_delete_request("not json");
    check(!result.success, "parsing malformed batch-delete JSON fails");
}

void test_successful_create_with_in_batch_ref(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "create-success";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    const oep::repository::BatchParseResult parsed = oep::repository::parse_batch_create_request(
        R"({
          "objects": [
            {"ref": "manual", "type": "Document", "name": "Manual"},
            {"ref": "coil", "type": "Component", "name": "Coil"}
          ],
          "relationships": [
            {"source": "manual", "target": "coil", "type": "Documents"}
          ]
        })");
    check(parsed.success, "parsing a well-formed batch-create request succeeds");

    const oep::repository::BatchCreateResult result =
        oep::repository::execute_batch_create(parsed.request, objects, relationships);
    check(result.success, "executing a well-formed batch-create succeeds");
    check(result.objects_created == 2, "the batch creates both objects");
    check(result.relationships_created == 1, "the batch creates the relationship, resolving in-batch refs");

    const oep::repository::ListRelationshipsResult listed = relationships.list_all();
    check(listed.success && listed.relationships.size() == 1, "the created relationship is persisted");
    if (!listed.relationships.empty()) {
        check(listed.relationships.front().source_object_id.size() == 36 &&
                  listed.relationships.front().source_object_id != "manual",
              "the relationship's source was resolved from the ref to a real object ID");
    }
}

void test_validate_rejects_duplicate_ref(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "duplicate-ref";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);

    const oep::repository::BatchParseResult parsed = oep::repository::parse_batch_create_request(
        R"({"objects":[{"ref":"x","type":"Component","name":"A"},{"ref":"x","type":"Component","name":"B"}]})");
    check(parsed.success, "parsing succeeds even though the request has a duplicate ref");

    const std::vector<std::string> errors = oep::repository::validate_batch_create_request(parsed.request, objects);
    check(!errors.empty(), "validation detects the duplicate ref");
}

void test_validate_rejects_unknown_reference(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "unknown-ref";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);

    const oep::repository::BatchParseResult parsed = oep::repository::parse_batch_create_request(
        R"({"relationships":[{"source":"nonexistent","target":"also-nonexistent","type":"References"}]})");
    check(parsed.success, "parsing a batch referencing unknown objects succeeds structurally");

    const std::vector<std::string> errors = oep::repository::validate_batch_create_request(parsed.request, objects);
    check(errors.size() >= 2, "validation reports both the unknown source and unknown target");
}

void test_create_fails_without_executing_when_invalid(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid-create";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    const oep::repository::BatchParseResult parsed = oep::repository::parse_batch_create_request(
        R"({
          "objects": [{"ref": "a", "type": "Component", "name": "A"}],
          "relationships": [{"source": "a", "target": "nonexistent", "type": "References"}]
        })");
    check(parsed.success, "parsing succeeds structurally");

    const oep::repository::BatchCreateResult result =
        oep::repository::execute_batch_create(parsed.request, objects, relationships);
    check(!result.success, "execute_batch_create fails when validation would fail");

    const oep::repository::ListObjectsResult listed = objects.list_all();
    check(listed.success && listed.objects.empty(),
          "a failed batch validation creates nothing, even the objects with no problems");
}

void test_successful_delete(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "delete-success";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = "Widget";
    const oep::repository::LoadObjectResult created = objects.create(object);
    check(created.success, "creating the sample object succeeds");

    oep::repository::BatchDeleteRequest request;
    request.object_ids = {created.object.object_id};

    const oep::repository::BatchDeleteResult result =
        oep::repository::execute_batch_delete(request, objects, relationships);
    check(result.success, "batch delete succeeds for an existing object");
    check(result.objects_deleted == 1, "batch delete reports one deleted object");
    check(!objects.load(created.object.object_id).success, "the object no longer exists after batch delete");
}

void test_delete_fails_for_nonexistent_id_without_deleting_anything(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "delete-invalid";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = "Widget";
    const oep::repository::LoadObjectResult created = objects.create(object);

    oep::repository::BatchDeleteRequest request;
    request.object_ids = {created.object.object_id, "00000000-0000-4000-8000-000000000000"};

    const oep::repository::BatchDeleteResult result =
        oep::repository::execute_batch_delete(request, objects, relationships);
    check(!result.success, "batch delete fails when any referenced ID does not exist");
    check(objects.load(created.object.object_id).success,
          "a failed batch delete does not delete the objects that do exist");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_batch_processor_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_parse_create_rejects_malformed_json();
    test_parse_create_rejects_unrecognized_type();
    test_parse_delete_rejects_malformed_json();
    test_successful_create_with_in_batch_ref(scratch_dir);
    test_validate_rejects_duplicate_ref(scratch_dir);
    test_validate_rejects_unknown_reference(scratch_dir);
    test_create_fails_without_executing_when_invalid(scratch_dir);
    test_successful_delete(scratch_dir);
    test_delete_fails_for_nonexistent_id_without_deleting_anything(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All batch processor tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " batch processor test(s) failed.\n";
    return 1;
}
