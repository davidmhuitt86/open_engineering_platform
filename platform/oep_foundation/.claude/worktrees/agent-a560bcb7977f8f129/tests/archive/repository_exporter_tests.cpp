#include "oep/archive/repository_exporter.hpp"

#include "oep/packages/package_manager.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/metadata.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
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

std::string read_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    std::ostringstream stream;
    stream << file.rdbuf();
    return stream.str();
}

bool contains(const std::string& haystack, const std::string& needle) {
    return haystack.find(needle) != std::string::npos;
}

void test_export_succeeds_with_content(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "with-content";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = "Ignition Coil";
    object.version = "1.0.0";
    const oep::repository::LoadObjectResult created = objects.create(object);
    check(created.success, "creating the sample object succeeds");

    const oep::repository::RepositoryMetadata metadata = sample_metadata();
    const std::filesystem::path output_file = scratch_dir / "with-content.json";

    const oep::archive::ExportResult result =
        oep::archive::export_repository(metadata, objects, relationships, audit, nullptr, output_file);

    check(result.success, "export succeeds for a repository with content");
    check(result.manifest.object_count == 1, "the manifest reports one object");
    check(result.manifest.relationship_count == 0, "the manifest reports zero relationships");
    check(result.manifest.repository_id == metadata.repository_id, "the manifest reports the repository ID");
    check(std::filesystem::exists(output_file), "export writes the archive file");

    const std::string contents = read_file(output_file);
    check(contains(contents, "Ignition Coil"), "the archive contains the exported object's data");
    check(contains(contents, "\"exportVersion\": \"1.0\""), "the archive contains the export manifest");
    check(!std::filesystem::exists(output_file.string() + ".tmp"),
          "export leaves no temporary file behind on success");
}

void test_export_empty_repository_succeeds(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "empty";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    const std::filesystem::path output_file = scratch_dir / "empty.json";
    const oep::archive::ExportResult result =
        oep::archive::export_repository(sample_metadata(), objects, relationships, audit, nullptr, output_file);

    check(result.success, "export succeeds for an empty repository");
    check(result.manifest.object_count == 0, "an empty repository's manifest reports zero objects");
    check(result.manifest.relationship_count == 0, "an empty repository's manifest reports zero relationships");
}

void test_export_fails_for_invalid_output_path(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid-path";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    // A parent directory that cannot exist (a regular file masquerading as one).
    const std::filesystem::path blocking_file = scratch_dir / "not-a-directory";
    std::ofstream(blocking_file, std::ios::binary) << "blocking";
    const std::filesystem::path output_file = blocking_file / "archive.json";

    const oep::archive::ExportResult result =
        oep::archive::export_repository(sample_metadata(), objects, relationships, audit, nullptr, output_file);

    check(!result.success, "export fails for an invalid output path");
    check(!result.error.empty(), "export reports a descriptive error for an invalid output path");
}

void test_export_include_packages(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "with-packages";
    const oep::repository::AuditStore audit(root / "repository" / "audit");
    const oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    const oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    const std::filesystem::path package_dir = root / "packages" / "sample-package";
    std::filesystem::create_directories(package_dir);
    std::ofstream manifest_file(package_dir / "package.json", std::ios::binary);
    manifest_file << "{\n"
                     "  \"packageId\": \"2b9e1b02-e845-482a-b299-1e15ffe3932b\",\n"
                     "  \"packageName\": \"Sample Package\",\n"
                     "  \"packageVersion\": \"1.0.0\",\n"
                     "  \"packageType\": \"Extension\",\n"
                     "  \"foundationVersion\": \"0.1.0\",\n"
                     "  \"createdUtc\": \"2026-01-01T00:00:00Z\"\n"
                     "}\n";
    manifest_file.close();

    const oep::packages::PackageManager packages(root / "packages", "0.1.0");

    const std::filesystem::path output_with = scratch_dir / "with-packages-included.json";
    const oep::archive::ExportResult with_result =
        oep::archive::export_repository(sample_metadata(), objects, relationships, audit, &packages, output_with);
    check(with_result.success, "export with packages succeeds");
    check(with_result.manifest.package_count == 1, "the manifest reports one package when included");
    check(contains(read_file(output_with), "Sample Package"), "the archive contains the package manifest data");

    const std::filesystem::path output_without = scratch_dir / "with-packages-excluded.json";
    const oep::archive::ExportResult without_result = oep::archive::export_repository(
        sample_metadata(), objects, relationships, audit, nullptr, output_without);
    check(without_result.success, "export without --include-packages still succeeds");
    check(without_result.manifest.package_count == 0,
          "the manifest reports zero packages when packages are not requested");
    check(!contains(read_file(output_without), "\"packages\""),
          "the archive omits the packages section entirely when not requested");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_repository_exporter_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_export_succeeds_with_content(scratch_dir);
    test_export_empty_repository_succeeds(scratch_dir);
    test_export_fails_for_invalid_output_path(scratch_dir);
    test_export_include_packages(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All repository exporter tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " repository exporter test(s) failed.\n";
    return 1;
}
