#include "oep/installer/package_installer.hpp"

#include <cstdint>
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

void append_u16(std::vector<std::uint8_t>& out, std::uint16_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}

void append_u32(std::vector<std::uint8_t>& out, std::uint32_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}

void append_bytes(std::vector<std::uint8_t>& out, const std::string& text) {
    out.insert(out.end(), text.begin(), text.end());
}

// Same minimal, Stored-only ZIP builder as tests/installer/zip_reader_tests.cpp
// — duplicated rather than shared, matching this codebase's own convention
// of self-contained test files (see e.g. tests/repository's own per-file
// sample_object() helpers).
std::vector<std::uint8_t> build_stored_zip(const std::vector<std::pair<std::string, std::string>>& entries) {
    std::vector<std::uint8_t> out;
    std::vector<std::uint32_t> local_header_offsets;

    for (const auto& [name, content] : entries) {
        local_header_offsets.push_back(static_cast<std::uint32_t>(out.size()));
        append_u32(out, 0x04034b50);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_bytes(out, name);
        append_bytes(out, content);
    }

    const std::uint32_t central_directory_start = static_cast<std::uint32_t>(out.size());
    for (std::size_t i = 0; i < entries.size(); ++i) {
        const auto& [name, content] = entries[i];
        append_u32(out, 0x02014b50);
        append_u16(out, 20);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, local_header_offsets[i]);
        append_bytes(out, name);
    }
    const std::uint32_t central_directory_size = static_cast<std::uint32_t>(out.size()) - central_directory_start;

    append_u32(out, 0x06054b50);
    append_u16(out, 0);
    append_u16(out, 0);
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u32(out, central_directory_size);
    append_u32(out, central_directory_start);
    append_u16(out, 0);

    return out;
}

std::filesystem::path write_temp_archive(const std::vector<std::uint8_t>& bytes, const std::string& file_name) {
    const std::filesystem::path path = std::filesystem::temp_directory_path() / "oep_package_installer_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

const char* kValidManifest = R"({
  "schemaVersion": "1.0", "packageId": "com.oep.demo.engineering-showcase", "version": "1.0.0",
  "publisher": {"id": "demo-publisher", "name": "OEP Demo Publisher"},
  "title": "Engineering Demo Package", "summary": "s", "description": "d", "category": "demonstration",
  "engineeringDomains": ["Automotive"], "license": {}, "dependencies": [], "capabilities": [],
  "repository": {}, "statistics": {}, "signatures": {}, "build": {}
})";

void test_extracts_manifest_objects_and_relationships() {
    const std::string object_a = R"({"objectId":"aaaaaaaa-0000-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a",)"
                                  R"("tags":["demo"]})";
    const std::string object_b = R"({"objectId":"bbbbbbbb-0000-4000-8000-000000000002","objectType":"Diagram",)"
                                  R"("name":"Wiring Diagram","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";
    const std::string relationship = R"({"relationshipId":"cccccccc-0000-4000-8000-000000000003",)"
                                      R"("sourceObjectId":"bbbbbbbb-0000-4000-8000-000000000002",)"
                                      R"("targetObjectId":"aaaaaaaa-0000-4000-8000-000000000001",)"
                                      R"("relationshipType":"Documents","createdUtc":"2026-01-01T00:00:00Z",)"
                                      R"("author":"a","description":"d"})";

    const std::filesystem::path path = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kValidManifest},
            {"fragment/objects/a.json", object_a},
            {"fragment/objects/b.json", object_b},
            {"fragment/relationships/r.json", relationship},
            {"package.info", "Engineering Demo Package"},
        }),
        "full.oep");

    const oep::installer::ExtractPackageResult result = oep::installer::extract_package(path);
    check(result.success, "extract_package succeeds for a well-formed archive: " + result.error);
    if (!result.success) return;

    check(result.package.manifest.package_id == "com.oep.demo.engineering-showcase",
          "the extracted manifest has the correct packageId");
    check(result.package.objects.size() == 2, "both Repository Fragment objects are extracted");
    check(result.package.relationships.size() == 1, "the Repository Fragment relationship is extracted");
    check(result.package.objects[0].name == "Harness", "object fields are read via the camelCase convention");
    check(result.package.relationships[0].source_object_id == "bbbbbbbb-0000-4000-8000-000000000002",
          "relationship sourceObjectId is read correctly");
}

// WP-REP-002 terminology migration: the in-archive directory is now
// `fragment/`, not `repository/` (OEP-ARCH-002 §0.2(b)) -- but an already
// -built archive using the legacy name must remain installable (least
// -disruptive migration path).
void test_extracts_from_a_legacy_repository_named_archive() {
    const std::string object_a = R"({"objectId":"aaaaaaaa-0000-4000-8000-000000000009","objectType":"Component",)"
                                  R"("name":"Legacy Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";

    const std::filesystem::path path = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kValidManifest},
            {"repository/objects/a.json", object_a},
        }),
        "legacy-repository-naming.oep");

    const oep::installer::ExtractPackageResult result = oep::installer::extract_package(path);
    check(result.success, "extract_package still succeeds for an archive using the legacy repository/ directory: " +
                               result.error);
    if (!result.success) return;
    check(result.package.objects.size() == 1, "the legacy-named object entry is extracted");
    check(result.package.objects[0].name == "Legacy Harness", "the legacy-named object's fields are read correctly");
}

void test_fails_when_manifest_entry_is_missing() {
    const std::filesystem::path path =
        write_temp_archive(build_stored_zip({{"package.info", "no manifest here"}}), "no-manifest.oep");
    const oep::installer::ExtractPackageResult result = oep::installer::extract_package(path);
    check(!result.success, "extract_package fails when manifest/package.json is absent");
}

void test_fails_when_manifest_is_invalid() {
    const std::filesystem::path path =
        write_temp_archive(build_stored_zip({{"manifest/package.json", "{\"incomplete\":true}"}}), "bad-manifest.oep");
    const oep::installer::ExtractPackageResult result = oep::installer::extract_package(path);
    check(!result.success, "extract_package fails when the manifest is missing required fields");
}

void test_fails_for_an_unrecognized_object_type() {
    const std::string bad_object = R"({"objectId":"x","objectType":"NotARealType","name":"n"})";
    const std::filesystem::path path = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kValidManifest},
            {"fragment/objects/x.json", bad_object},
        }),
        "bad-object-type.oep");
    const oep::installer::ExtractPackageResult result = oep::installer::extract_package(path);
    check(!result.success, "extract_package fails for an unrecognized objectType");
}

void test_fails_for_a_relationship_missing_endpoints() {
    const std::string bad_relationship = R"({"relationshipType":"References"})";
    const std::filesystem::path path = write_temp_archive(
        build_stored_zip({
            {"manifest/package.json", kValidManifest},
            {"fragment/relationships/r.json", bad_relationship},
        }),
        "bad-relationship.oep");
    const oep::installer::ExtractPackageResult result = oep::installer::extract_package(path);
    check(!result.success, "extract_package fails for a relationship missing source/targetObjectId");
}

} // namespace

int main() {
    test_extracts_manifest_objects_and_relationships();
    test_extracts_from_a_legacy_repository_named_archive();
    test_fails_when_manifest_entry_is_missing();
    test_fails_when_manifest_is_invalid();
    test_fails_for_an_unrecognized_object_type();
    test_fails_for_a_relationship_missing_endpoints();

    std::filesystem::remove_all(std::filesystem::temp_directory_path() / "oep_package_installer_tests");

    if (g_failures == 0) {
        std::cout << "All package_installer tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " package_installer test(s) failed.\n";
    return 1;
}
