#include "oep/archive/repository_importer.hpp"

#include "oep/archive/repository_exporter.hpp"
#include "oep/packages/package_manager.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/relationship.hpp"

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

oep::repository::RepositoryMetadata sample_metadata() {
    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    metadata.repository_name = "my-workshop";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    metadata.last_modified_utc = "2026-01-01T00:00:00Z";
    return metadata;
}

// Builds a source repository with one object, one relationship, and
// exports it to `archive_path`. Returns the source object's ID.
std::string build_and_export_sample(const std::filesystem::path& source_root, const std::filesystem::path& archive_path) {
    const oep::repository::AuditStore audit(source_root / "repository" / "audit");
    const oep::repository::ObjectStore objects(source_root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(source_root / "repository" / "relationships", objects,
                                                             audit);

    oep::repository::EngineeringObject source_object;
    source_object.object_type = oep::repository::ObjectType::Document;
    source_object.name = "Manual";
    source_object.author = "Jane";
    source_object.tags = {"docs"};
    source_object.version = "1.0.0";
    const oep::repository::LoadObjectResult a = objects.create(source_object);

    oep::repository::EngineeringObject target_object;
    target_object.object_type = oep::repository::ObjectType::Component;
    target_object.name = "Coil";
    target_object.version = "1.0.0";
    const oep::repository::LoadObjectResult b = objects.create(target_object);

    oep::repository::Relationship relationship;
    relationship.source_object_id = a.object.object_id;
    relationship.target_object_id = b.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::Documents;
    relationships.create(relationship);

    const oep::archive::ExportResult exported =
        oep::archive::export_repository(sample_metadata(), objects, relationships, audit, nullptr, archive_path);
    if (!exported.success) {
        std::cerr << "FAIL: setting up a sample export succeeds: " << exported.error << "\n";
        ++g_failures;
    }

    return a.object.object_id;
}

void test_successful_import_preserves_identity(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path source_root = scratch_dir / "source1";
    const std::filesystem::path archive_path = scratch_dir / "archive1.json";
    const std::string original_object_id = build_and_export_sample(source_root, archive_path);

    const std::filesystem::path destination = scratch_dir / "destination1";
    const oep::archive::ImportResult result = oep::archive::import_repository(archive_path, destination, false);

    check(result.success, "import succeeds for a valid archive");
    check(result.manifest.object_count == 2, "the import result reports the correct object count");
    check(result.manifest.relationship_count == 1, "the import result reports the correct relationship count");
    check(std::filesystem::exists(destination / "repository.json"), "import writes repository.json");

    const oep::repository::LoadMetadataResult metadata =
        oep::repository::load_metadata(destination / "repository.json");
    check(metadata.success, "the imported repository.json loads successfully");

    const oep::repository::AuditStore audit(destination / "repository" / "audit");
    const oep::repository::ObjectStore objects(destination / "repository" / "objects", audit);
    const oep::repository::LoadObjectResult reloaded = objects.load(original_object_id);
    check(reloaded.success, "the imported repository contains the original object under its original ID");
    check(reloaded.object.author == "Jane", "the imported object preserves its author");
    check(!reloaded.object.tags.empty() && reloaded.object.tags.front() == "docs",
          "the imported object preserves its tags");
}

void test_import_rejects_existing_destination_without_overwrite(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path source_root = scratch_dir / "source2";
    const std::filesystem::path archive_path = scratch_dir / "archive2.json";
    build_and_export_sample(source_root, archive_path);

    const std::filesystem::path destination = scratch_dir / "destination2";
    check(oep::archive::import_repository(archive_path, destination, false).success, "first import succeeds");

    const oep::archive::ImportResult second_attempt =
        oep::archive::import_repository(archive_path, destination, false);
    check(!second_attempt.success, "importing into a non-empty destination without --overwrite fails");

    const oep::archive::ImportResult with_overwrite =
        oep::archive::import_repository(archive_path, destination, true);
    check(with_overwrite.success, "importing into a non-empty destination with overwrite=true succeeds");
}

void test_import_rejects_invalid_json(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path archive_path = scratch_dir / "invalid.json";
    write_raw(archive_path, "{ not valid json ");

    const oep::archive::ImportResult result =
        oep::archive::import_repository(archive_path, scratch_dir / "destination-invalid", false);
    check(!result.success, "import fails for an archive that is not valid JSON");
}

void test_import_rejects_missing_archive() {
    const oep::archive::ImportResult result = oep::archive::import_repository(
        "/nonexistent/archive.json", "/nonexistent/destination", false);
    check(!result.success, "import fails when the archive file does not exist");
}

void test_import_rejects_corrupted_manifest(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path archive_path = scratch_dir / "corrupted-manifest.json";
    write_raw(archive_path,
              "{\n"
              "  \"exportManifest\": { \"exportVersion\": \"1.0\" },\n"
              "  \"repositoryMetadata\": {},\n"
              "  \"objects\": [],\n"
              "  \"relationships\": [],\n"
              "  \"auditEvents\": []\n"
              "}\n");

    const oep::archive::ImportResult result =
        oep::archive::import_repository(archive_path, scratch_dir / "destination-corrupted", false);
    check(!result.success, "import fails for a manifest missing required fields");
}

void test_import_rejects_unsupported_export_version(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path archive_path = scratch_dir / "future-version.json";
    write_raw(archive_path,
              "{\n"
              "  \"exportManifest\": {\n"
              "    \"exportVersion\": \"99.0\",\n"
              "    \"exportTimestampUtc\": \"2026-01-01T00:00:00Z\",\n"
              "    \"repositoryId\": \"1b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
              "    \"repositoryVersion\": \"1.0.0\",\n"
              "    \"objectCount\": \"0\",\n"
              "    \"relationshipCount\": \"0\",\n"
              "    \"packageCount\": \"0\"\n"
              "  },\n"
              "  \"repositoryMetadata\": {}\n"
              "}\n");

    const oep::archive::ImportResult result =
        oep::archive::import_repository(archive_path, scratch_dir / "destination-future-version", false);
    check(!result.success, "import fails for an unsupported export version");
    check(result.error.find("version") != std::string::npos, "the error mentions the version mismatch");
}

void test_import_restores_packages(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path source_root = scratch_dir / "source-packages";
    const oep::repository::AuditStore audit(source_root / "repository" / "audit");
    const oep::repository::ObjectStore objects(source_root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(source_root / "repository" / "relationships", objects,
                                                             audit);

    const std::filesystem::path package_dir = source_root / "packages" / "sample-package";
    write_raw(package_dir / "package.json",
              "{\n"
              "  \"packageId\": \"2b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
              "  \"packageName\": \"Sample Package\",\n"
              "  \"packageVersion\": \"1.0.0\",\n"
              "  \"packageType\": \"Extension\",\n"
              "  \"foundationVersion\": \"0.1.0\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\"\n"
              "}\n");
    const oep::packages::PackageManager packages(source_root / "packages", "0.1.0");

    const std::filesystem::path archive_path = scratch_dir / "with-packages.json";
    const oep::archive::ExportResult exported =
        oep::archive::export_repository(sample_metadata(), objects, relationships, audit, &packages, archive_path);
    check(exported.success, "exporting with packages succeeds");

    const std::filesystem::path destination = scratch_dir / "destination-packages";
    const oep::archive::ImportResult result = oep::archive::import_repository(archive_path, destination, false);
    check(result.success, "importing an archive with packages succeeds");
    check(result.manifest.package_count == 1, "the import result reports one restored package");

    const oep::packages::PackageManager restored_packages(destination / "packages", "0.1.0");
    const oep::packages::ListPackagesResult listed = restored_packages.list_packages();
    check(listed.success && listed.packages.size() == 1, "the destination has exactly one discoverable package");
    check(!listed.packages.empty() && listed.packages.front().state == oep::packages::PackageState::Loaded,
          "the restored package loads successfully");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_repository_importer_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_successful_import_preserves_identity(scratch_dir);
    test_import_rejects_existing_destination_without_overwrite(scratch_dir);
    test_import_rejects_invalid_json(scratch_dir);
    test_import_rejects_missing_archive();
    test_import_rejects_corrupted_manifest(scratch_dir);
    test_import_rejects_unsupported_export_version(scratch_dir);
    test_import_restores_packages(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All repository importer tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " repository importer test(s) failed.\n";
    return 1;
}
