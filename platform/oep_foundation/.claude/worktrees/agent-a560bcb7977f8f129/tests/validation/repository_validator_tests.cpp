#include "oep/validation/repository_validator.hpp"

#include "oep/repository/engineering_object.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/relationship.hpp"

#include <algorithm>
#include <filesystem>
#include <fstream>
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

void write_raw(const std::filesystem::path& path, const std::string& contents) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file << contents;
}

bool has_category(const std::vector<oep::validation::ValidationFinding>& findings, const std::string& category) {
    return std::any_of(findings.begin(), findings.end(),
                        [&category](const oep::validation::ValidationFinding& f) { return f.category == category; });
}

bool has_message_containing(const std::vector<oep::validation::ValidationFinding>& findings,
                             const std::string& substring) {
    return std::any_of(findings.begin(), findings.end(), [&substring](const oep::validation::ValidationFinding& f) {
        return f.message.find(substring) != std::string::npos;
    });
}

// Sets up a healthy repository: valid metadata, two objects, one
// relationship between them, and one audit event. Returns the root path.
std::filesystem::path build_healthy_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);

    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    metadata.repository_name = "my-workshop";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    check(oep::repository::save_metadata(root / "repository.json", metadata).success,
          "writing healthy metadata succeeds");

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);

    oep::repository::EngineeringObject source_object;
    source_object.object_type = oep::repository::ObjectType::Document;
    source_object.name = "Manual";
    source_object.version = "1.0.0";
    const oep::repository::LoadObjectResult source = objects.create(source_object);
    check(source.success, "creating the source object succeeds");

    oep::repository::EngineeringObject target_object;
    target_object.object_type = oep::repository::ObjectType::Component;
    target_object.name = "Coil";
    target_object.version = "1.0.0";
    const oep::repository::LoadObjectResult target = objects.create(target_object);
    check(target.success, "creating the target object succeeds");

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = target.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::Documents;
    check(relationships.create(relationship).success, "creating the sample relationship succeeds");

    return root;
}

void test_healthy_repository_produces_no_errors(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "healthy";
    build_healthy_repository(root);

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const oep::validation::ValidationReport report = validator.validate_repository();
    check(report.status == oep::validation::RepositoryStatus::Healthy, "a healthy repository reports Healthy status");
    check(report.error_count == 0, "a healthy repository has zero errors");
}

void test_missing_metadata_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "missing_metadata";
    std::filesystem::create_directories(root);

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_metadata();
    check(!findings.empty() && findings.front().severity == oep::validation::Severity::Error,
          "a missing repository.json is reported as an Error");
}

void test_invalid_metadata_json_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid_metadata";
    write_raw(root / "repository.json", "{ not valid json ");

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_metadata();
    check(!findings.empty(), "invalid metadata JSON is reported");
}

void test_invalid_repository_id_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid_repo_id";
    write_raw(root / "repository.json",
              "{\n"
              "  \"repositoryId\": \"not-a-uuid\",\n"
              "  \"repositoryName\": \"my-workshop\",\n"
              "  \"repositoryVersion\": \"1.0.0\",\n"
              "  \"foundationVersion\": \"0.1.0\",\n"
              "  \"templateVersion\": \"1.0\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"lastModifiedUtc\": \"2026-01-01T00:00:00Z\"\n"
              "}\n");

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_metadata();
    check(has_message_containing(findings, "repositoryId"), "an invalid repositoryId is reported");
}

void test_duplicate_object_id_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "duplicate_object";
    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);

    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = "Original";
    object.version = "1.0.0";
    const oep::repository::LoadObjectResult created = objects.create(object);
    check(created.success, "creating the original object succeeds");

    // Simulate corruption: a second file whose internal objectId duplicates
    // an existing object, which ObjectStore's own API cannot produce.
    write_raw(root / "objects" / "duplicate-copy.json",
              "{\n"
              "  \"objectId\": \"" + created.object.object_id + "\",\n"
              "  \"objectType\": \"Component\",\n"
              "  \"name\": \"Duplicate\",\n"
              "  \"description\": \"\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"lastModifiedUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"version\": \"1.0.0\",\n"
              "  \"author\": \"\",\n"
              "  \"tags\": []\n"
              "}\n");

    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);
    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_objects();
    check(has_message_containing(findings, "duplicate object ID"), "a duplicate object ID is detected");
}

void test_duplicate_relationship_id_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "duplicate_relationship";
    build_healthy_repository(root);

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);

    const oep::repository::ListRelationshipsResult existing = relationships.list_all();
    check(existing.success && !existing.relationships.empty(), "the healthy repository has a relationship to copy");
    const std::string relationship_id = existing.relationships.front().relationship_id;

    write_raw(root / "relationships" / "duplicate-copy.json",
              "{\n"
              "  \"relationshipId\": \"" + relationship_id + "\",\n"
              "  \"sourceObjectId\": \"" + existing.relationships.front().source_object_id + "\",\n"
              "  \"targetObjectId\": \"" + existing.relationships.front().target_object_id + "\",\n"
              "  \"relationshipType\": \"Documents\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"author\": \"\",\n"
              "  \"description\": \"\"\n"
              "}\n");

    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);
    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_relationships();
    check(has_message_containing(findings, "duplicate relationship ID"), "a duplicate relationship ID is detected");
}

void test_missing_relationship_endpoint_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "missing_endpoint";
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

    oep::repository::Relationship relationship;
    relationship.source_object_id = source.object.object_id;
    relationship.target_object_id = target.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::Documents;
    const oep::repository::LoadRelationshipResult created = relationships.create(relationship);
    check(created.success, "creating the relationship while both objects exist succeeds");

    // Now remove the target object, orphaning the relationship's endpoint.
    check(objects.remove(target.object.object_id).success, "removing the target object succeeds");

    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);
    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_relationships();
    check(has_message_containing(findings, "nonexistent targetObjectId"),
          "a relationship with a missing endpoint is detected");
}

void test_invalid_object_type_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid_object_type";
    write_raw(root / "objects" / "bad-type.json",
              "{\n"
              "  \"objectId\": \"1b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
              "  \"objectType\": \"NotARealType\",\n"
              "  \"name\": \"Bad\",\n"
              "  \"description\": \"\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"lastModifiedUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"version\": \"1.0.0\",\n"
              "  \"author\": \"\",\n"
              "  \"tags\": []\n"
              "}\n");

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_objects();
    check(has_category(findings, "Objects") && has_message_containing(findings, "invalid object file"),
          "an invalid objectType is detected");
}

void test_invalid_relationship_type_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid_relationship_type";
    write_raw(root / "relationships" / "bad-type.json",
              "{\n"
              "  \"relationshipId\": \"1b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
              "  \"sourceObjectId\": \"2b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
              "  \"targetObjectId\": \"3b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
              "  \"relationshipType\": \"NotARealType\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"author\": \"\",\n"
              "  \"description\": \"\"\n"
              "}\n");

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const std::vector<oep::validation::ValidationFinding> findings = validator.validate_relationships();
    check(has_category(findings, "Relationships") && has_message_containing(findings, "invalid relationship file"),
          "an invalid relationshipType is detected");
}

void test_duplicate_uuid_across_objects_and_relationships_is_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "cross_collision";
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

    // Simulate corruption: a relationship whose ID collides with an existing object's ID.
    write_raw(root / "relationships" / (source.object.object_id + ".json"),
              "{\n"
              "  \"relationshipId\": \"" + source.object.object_id + "\",\n"
              "  \"sourceObjectId\": \"" + source.object.object_id + "\",\n"
              "  \"targetObjectId\": \"" + target.object.object_id + "\",\n"
              "  \"relationshipType\": \"References\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"author\": \"\",\n"
              "  \"description\": \"\"\n"
              "}\n");

    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);
    const oep::validation::ValidationReport report = validator.validate_repository();
    check(has_message_containing(report.findings, "used by both an object and a relationship"),
          "a UUID reused across an object and a relationship is detected");
}

void test_validation_continues_after_errors(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "multiple_errors";
    // No metadata written at all, and an invalid object file present.
    write_raw(root / "objects" / "bad-type.json",
              "{\n"
              "  \"objectId\": \"1b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
              "  \"objectType\": \"NotARealType\",\n"
              "  \"name\": \"Bad\",\n"
              "  \"description\": \"\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"lastModifiedUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"version\": \"1.0.0\",\n"
              "  \"author\": \"\",\n"
              "  \"tags\": []\n"
              "}\n");

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const oep::validation::ValidationReport report = validator.validate_repository();
    check(report.status == oep::validation::RepositoryStatus::Unhealthy,
          "a repository with multiple problems reports Unhealthy status");
    check(has_category(report.findings, "Metadata"), "validation still reports the metadata problem");
    check(has_category(report.findings, "Objects"),
          "validation continues past the metadata error and still reports the object problem");
    check(report.error_count >= 2, "both independent errors are counted");
}

void test_report_is_deterministic(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "determinism";
    build_healthy_repository(root);

    const oep::repository::AuditStore audit(root / "audit");
    const oep::repository::ObjectStore objects(root / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "relationships", objects, audit);
    const oep::validation::RepositoryValidator validator(root / "repository.json", objects, relationships, audit);

    const oep::validation::ValidationReport first = validator.validate_repository();
    const oep::validation::ValidationReport second = validator.validate_repository();

    check(first.status == second.status, "repeated validation reports the same status");
    check(first.error_count == second.error_count && first.warning_count == second.warning_count &&
              first.information_count == second.information_count,
          "repeated validation reports the same counts");
    check(first.findings.size() == second.findings.size(), "repeated validation reports the same number of findings");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_repository_validator_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_healthy_repository_produces_no_errors(scratch_dir);
    test_missing_metadata_is_detected(scratch_dir);
    test_invalid_metadata_json_is_detected(scratch_dir);
    test_invalid_repository_id_is_detected(scratch_dir);
    test_duplicate_object_id_is_detected(scratch_dir);
    test_duplicate_relationship_id_is_detected(scratch_dir);
    test_missing_relationship_endpoint_is_detected(scratch_dir);
    test_invalid_object_type_is_detected(scratch_dir);
    test_invalid_relationship_type_is_detected(scratch_dir);
    test_duplicate_uuid_across_objects_and_relationships_is_detected(scratch_dir);
    test_validation_continues_after_errors(scratch_dir);
    test_report_is_deterministic(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All repository validator tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " repository validator test(s) failed.\n";
    return 1;
}
