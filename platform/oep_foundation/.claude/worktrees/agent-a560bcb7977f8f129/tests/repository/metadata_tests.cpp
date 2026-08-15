#include "oep/repository/metadata.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

void write_raw(const std::filesystem::path& path, const std::string& contents) {
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
    metadata.description = "Sample repository";
    metadata.author = "Test Author";
    metadata.organization = "Test Org";
    metadata.tags = {"sample", "test"};
    return metadata;
}

void test_load_valid_metadata(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path path = scratch_dir / "valid_repository.json";
    const oep::repository::SaveMetadataResult save_result = oep::repository::save_metadata(path, sample_metadata());
    check(save_result.success, "save_metadata succeeds for valid metadata");

    const oep::repository::LoadMetadataResult load_result = oep::repository::load_metadata(path);
    check(load_result.success, "load_metadata succeeds for a well-formed file");
    check(load_result.metadata.repository_id == "1b9e1b02-e845-482a-b299-1e15ffe3932b",
          "load_metadata preserves repositoryId");
    check(load_result.metadata.repository_name == "my-workshop", "load_metadata preserves repositoryName");
    check(load_result.metadata.tags.size() == 2, "load_metadata preserves tags");
}

void test_load_invalid_json(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path path = scratch_dir / "invalid_json.json";
    write_raw(path, "{ not valid json ");

    const oep::repository::LoadMetadataResult result = oep::repository::load_metadata(path);
    check(!result.success, "load_metadata rejects invalid JSON");
    check(!result.error.empty(), "load_metadata reports a descriptive error for invalid JSON");
}

void test_load_missing_required_fields(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path path = scratch_dir / "missing_fields.json";
    write_raw(path, "{\n  \"repositoryId\": \"1b9e1b02-e845-482a-b299-1e15ffe3932b\"\n}\n");

    const oep::repository::LoadMetadataResult result = oep::repository::load_metadata(path);
    check(!result.success, "load_metadata rejects metadata missing required fields");
}

void test_load_bad_uuid(const std::filesystem::path& scratch_dir) {
    oep::repository::RepositoryMetadata metadata = sample_metadata();
    metadata.repository_id = "not-a-uuid";

    const std::filesystem::path path = scratch_dir / "bad_uuid.json";
    write_raw(path,
              "{\n"
              "  \"repositoryId\": \"not-a-uuid\",\n"
              "  \"repositoryName\": \"my-workshop\",\n"
              "  \"repositoryVersion\": \"1.0.0\",\n"
              "  \"foundationVersion\": \"0.1.0\",\n"
              "  \"templateVersion\": \"1.0\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\",\n"
              "  \"lastModifiedUtc\": \"2026-01-01T00:00:00Z\"\n"
              "}\n");

    const oep::repository::LoadMetadataResult result = oep::repository::load_metadata(path);
    check(!result.success, "load_metadata rejects a malformed repositoryId");
}

void test_save_updates_timestamp_and_round_trips(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path path = scratch_dir / "round_trip.json";

    oep::repository::RepositoryMetadata metadata = sample_metadata();
    metadata.last_modified_utc = "2000-01-01T00:00:00Z"; // deliberately stale

    const oep::repository::SaveMetadataResult save_result = oep::repository::save_metadata(path, metadata);
    check(save_result.success, "save_metadata succeeds");

    const oep::repository::LoadMetadataResult load_result = oep::repository::load_metadata(path);
    check(load_result.success, "load_metadata succeeds after save_metadata");
    check(load_result.metadata.last_modified_utc != "2000-01-01T00:00:00Z",
          "save_metadata refreshes lastModifiedUtc rather than trusting the caller");

    const std::filesystem::path temp_path = path.string() + ".tmp";
    check(!std::filesystem::exists(temp_path), "save_metadata leaves no temporary file behind on success");
}

void test_save_rejects_invalid_metadata(const std::filesystem::path& scratch_dir) {
    oep::repository::RepositoryMetadata metadata = sample_metadata();
    metadata.repository_name = ""; // required field

    const std::filesystem::path path = scratch_dir / "should_not_exist.json";
    const oep::repository::SaveMetadataResult result = oep::repository::save_metadata(path, metadata);
    check(!result.success, "save_metadata refuses to write invalid metadata");
    check(!std::filesystem::exists(path), "save_metadata does not create a file when metadata is invalid");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_repository_tests";
    std::filesystem::create_directories(scratch_dir);

    test_load_valid_metadata(scratch_dir);
    test_load_invalid_json(scratch_dir);
    test_load_missing_required_fields(scratch_dir);
    test_load_bad_uuid(scratch_dir);
    test_save_updates_timestamp_and_round_trips(scratch_dir);
    test_save_rejects_invalid_metadata(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All repository metadata tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " repository metadata test(s) failed.\n";
    return 1;
}
