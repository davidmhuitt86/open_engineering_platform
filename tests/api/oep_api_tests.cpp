#include "oep/api/oep_api.h"

#include "oep/repository/audit_store.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship_store.hpp"

#include <cstdint>
#include <cstring>
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

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);

    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    metadata.repository_name = "my-workshop";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);

    return root;
}

// Builds a repository with the same metadata as build_repository, plus two
// Engineering Objects (one Component with tags, one Document) and one
// Relationship between them, for enumeration/statistics tests.
std::filesystem::path build_populated_repository(const std::filesystem::path& root) {
    build_repository(root);

    oep::repository::AuditStore audit(root / "repository" / "audit");
    oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    oep::repository::EngineeringObject coil;
    coil.object_type = oep::repository::ObjectType::Component;
    coil.name = "Ignition Coil";
    coil.description = "Generates spark";
    coil.author = "Jane";
    coil.tags = {"electrical", "ignition"};
    const oep::repository::LoadObjectResult coil_created = objects.create(coil);

    oep::repository::EngineeringObject manual;
    manual.object_type = oep::repository::ObjectType::Document;
    manual.name = "Manual";
    manual.author = "Jane";
    const oep::repository::LoadObjectResult manual_created = objects.create(manual);

    oep::repository::Relationship relationship;
    relationship.source_object_id = manual_created.object.object_id;
    relationship.target_object_id = coil_created.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::Documents;
    relationships.create(relationship);

    return root;
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

// Same minimal, Stored-only ZIP builder as tests/installer/*_tests.cpp —
// duplicated per this codebase's own self-contained-test-file convention.
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

// A minimal valid .oep archive with one Component ("API Harness") and no
// relationships, for the Package Installation / Lifecycle Query tests.
std::filesystem::path write_demo_archive(const std::filesystem::path& scratch_dir) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":"com.oep.demo.capi","version":"1.0.0",)"
        R"("publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"C API Demo Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":["Automotive"],"license":{},"dependencies":[],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":"aaaaaaaa-3333-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"API Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";

    const std::filesystem::path path = scratch_dir / "capi-demo.oep";
    const std::vector<std::uint8_t> bytes = build_stored_zip({
        {"manifest/package.json", manifest},
        {"fragment/objects/a.json", object_a},
    });
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

// A minimal valid .oep archive declaring one dependency (WP-REP-005).
std::filesystem::path write_archive_with_dependency(const std::filesystem::path& scratch_dir,
                                                      const std::string& package_id,
                                                      const std::string& dependency_package_id,
                                                      const std::string& dependency_constraint,
                                                      const std::string& file_name) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":")" + package_id +
        R"(","version":"1.0.0","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"Dependency API Test Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":[],"license":{},"dependencies":[{"packageId":")" +
        dependency_package_id + R"(","version":")" + dependency_constraint +
        R"("}],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":"aaaaaaaa-6666-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"Dependency Test Widget","description":"d",)"
                                  R"("createdUtc":"2026-01-01T00:00:00Z","lastModifiedUtc":"2026-01-01T00:00:00Z",)"
                                  R"("version":"1.0.0","author":"a","tags":[]})";

    const std::filesystem::path path = scratch_dir / file_name;
    const std::vector<std::uint8_t> bytes = build_stored_zip({
        {"manifest/package.json", manifest},
        {"fragment/objects/a.json", object_a},
    });
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

// A minimal valid .oep archive with an explicit package id and version and
// no dependencies, for the Update (WP-REP-007) tests where a candidate
// version different from the currently-installed one is needed.
std::filesystem::path write_versioned_archive(const std::filesystem::path& scratch_dir, const std::string& package_id,
                                                const std::string& version, const std::string& file_name) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":")" + package_id + R"(","version":")" + version +
        R"(","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"Versioned API Test Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":[],"license":{},"dependencies":[],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":"aaaaaaaa-7777-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"Versioned Test Widget","description":"d",)"
                                  R"("createdUtc":"2026-01-01T00:00:00Z","lastModifiedUtc":"2026-01-01T00:00:00Z",)"
                                  R"("version":")" + version + R"(","author":"a","tags":[]})";

    const std::filesystem::path path = scratch_dir / file_name;
    const std::vector<std::uint8_t> bytes = build_stored_zip({
        {"manifest/package.json", manifest},
        {"fragment/objects/a.json", object_a},
    });
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

// A minimal valid .oep archive with an explicit package id/object id/object
// name and no dependencies, for the Merge Engine (WP-REP-008) tests, where
// two archives declaring the SAME object_id with DIFFERENT content are
// needed to provoke an ObjectContentConflict.
std::filesystem::path write_merge_archive(const std::filesystem::path& scratch_dir, const std::string& package_id,
                                            const std::string& object_id, const std::string& object_name,
                                            const std::string& file_name) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":")" + package_id +
        R"(","version":"1.0.0","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"Merge API Test Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":[],"license":{},"dependencies":[],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":")" + object_id + R"(","objectType":"Component",)"
                                  R"("name":")" + object_name + R"(","description":"d",)"
                                  R"("createdUtc":"2026-01-01T00:00:00Z","lastModifiedUtc":"2026-01-01T00:00:00Z",)"
                                  R"("version":"1.0.0","author":"a","tags":[]})";

    const std::filesystem::path path = scratch_dir / file_name;
    const std::vector<std::uint8_t> bytes = build_stored_zip({
        {"manifest/package.json", manifest},
        {"fragment/objects/a.json", object_a},
    });
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

void test_resolve_dependencies_reports_missing_and_rejects_install(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "resolve_missing");
    const std::filesystem::path archive = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.needs-missing", "com.oep.demo.does-not-exist", ">=1.0.0", "needs-missing.oep");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "resolve_missing").string().c_str());

    oep_dependency_resolution_result_t resolution;
    oep_dependency_entry_list_t entries;
    oep_package_id_list_t install_order;
    oep_result_t result =
        oep_package_resolve_dependencies(runtime, archive.string().c_str(), &resolution, &entries, &install_order);
    check(result.success == 1, std::string("oep_package_resolve_dependencies succeeds operationally: ") +
                                    result.error_message);
    check(resolution.resolved == 0, "the resolution itself reports unresolved (a required dependency is missing)");
    check(resolution.cycle_detected == 0, "no cycle is reported for a simple missing dependency");
    check(entries.count == 1 && std::string(entries.items[0].package_id) == "com.oep.demo.does-not-exist",
          "the entry list names the missing dependency");
    check(entries.items[0].state == OEP_DEPENDENCY_MISSING, "the entry is reported as OEP_DEPENDENCY_MISSING");
    check(install_order.count == 0, "install_order is empty when resolution fails");
    oep_dependency_entry_list_release(&entries);
    oep_package_id_list_release(&install_order);
    check(entries.items == nullptr && install_order.items == nullptr, "release zeroes both lists");

    // oep_package_install must independently reject this for the same
    // reason (resolution runs automatically as part of install).
    oep_package_install_result_t install_result;
    result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 0, "oep_package_install rejects a package with an unresolved required dependency");

    oep_runtime_destroy(runtime);
}

void test_resolve_dependencies_reports_satisfied(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "resolve_satisfied");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "resolve_satisfied").string().c_str());

    // Install a base package with no dependencies of its own
    // (write_demo_archive's manifest declares an empty dependencies list).
    const std::filesystem::path base_archive = write_demo_archive(scratch_dir);
    oep_package_install_result_t base_install;
    oep_result_t result = oep_package_install(runtime, base_archive.string().c_str(), &base_install);
    check(result.success == 1, std::string("installing the base package succeeds: ") + result.error_message);

    const std::filesystem::path dependent = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.dependent-capi", "com.oep.demo.capi", ">=1.0.0", "dependent-capi.oep");
    oep_dependency_resolution_result_t resolution;
    result = oep_package_resolve_dependencies(runtime, dependent.string().c_str(), &resolution, nullptr, nullptr);
    check(result.success == 1, std::string("oep_package_resolve_dependencies succeeds: ") + result.error_message);
    check(resolution.resolved == 1, "resolution reports Resolved when the dependency is installed and satisfied");

    oep_runtime_destroy(runtime);
}

void test_resolve_dependencies_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_dependency_resolution_result_t resolution;
    check(oep_package_resolve_dependencies(runtime, "does-not-matter.oep", &resolution, nullptr, nullptr).error_code ==
              OEP_ERROR_INVALID_STATE,
          "oep_package_resolve_dependencies requires an open repository");

    oep_runtime_destroy(runtime);
}

// ------------------------------------------------------------------
// Package Uninstall & Update (WP-REP-007)
// ------------------------------------------------------------------

void test_uninstall_impact_and_uninstall_success(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "uninstall_ok");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "uninstall_ok").string().c_str());

    const std::filesystem::path archive = write_demo_archive(scratch_dir);
    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("install succeeds: ") + result.error_message);

    oep_uninstall_impact_t impact;
    oep_package_id_list_t blocking;
    result = oep_package_analyze_uninstall_impact(runtime, "com.oep.demo.capi", &impact, &blocking);
    check(result.success == 1, std::string("analyze_uninstall_impact succeeds: ") + result.error_message);
    check(impact.found == 1, "package is found");
    check(impact.objects_affected == 1, "one object would be affected");
    check(impact.removable == 1, "package is removable (no dependents)");
    check(blocking.count == 0, "no blocking dependents");
    oep_package_id_list_release(&blocking);

    oep_package_uninstall_result_t uninstall_result;
    result = oep_package_uninstall(runtime, "com.oep.demo.capi", &uninstall_result);
    check(result.success == 1, std::string("uninstall succeeds: ") + result.error_message);
    check(std::string(uninstall_result.package_id) == "com.oep.demo.capi", "uninstall result reports package id");
    check(uninstall_result.objects_removed == 1, "uninstall removed one object");

    // Uninstalling again fails (no longer installed).
    result = oep_package_uninstall(runtime, "com.oep.demo.capi", &uninstall_result);
    check(result.success == 0, "uninstalling a package that is no longer installed fails");
    check(uninstall_result.package_id[0] == '\0', "result is zeroed on failure");

    oep_runtime_destroy(runtime);
}

void test_uninstall_impact_blocked_by_dependent(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "uninstall_blocked");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "uninstall_blocked").string().c_str());

    const std::filesystem::path base_archive = write_demo_archive(scratch_dir);
    oep_package_install_result_t base_install;
    oep_result_t result = oep_package_install(runtime, base_archive.string().c_str(), &base_install);
    check(result.success == 1, std::string("installing base package succeeds: ") + result.error_message);

    const std::filesystem::path dependent = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.dependent-uninstall", "com.oep.demo.capi", ">=1.0.0", "dependent-uninstall.oep");
    oep_package_install_result_t dependent_install;
    result = oep_package_install(runtime, dependent.string().c_str(), &dependent_install);
    check(result.success == 1, std::string("installing dependent package succeeds: ") + result.error_message);

    oep_uninstall_impact_t impact;
    oep_package_id_list_t blocking;
    result = oep_package_analyze_uninstall_impact(runtime, "com.oep.demo.capi", &impact, &blocking);
    check(result.success == 1, std::string("analyze_uninstall_impact succeeds: ") + result.error_message);
    check(impact.found == 1, "base package is found");
    check(impact.removable == 0, "base package is not removable (blocked by dependent)");
    check(blocking.count == 1 && std::string(blocking.items[0].id) == "com.oep.demo.dependent-uninstall",
          "blocking dependent is named");
    oep_package_id_list_release(&blocking);

    oep_package_uninstall_result_t uninstall_result;
    result = oep_package_uninstall(runtime, "com.oep.demo.capi", &uninstall_result);
    check(result.success == 0, "uninstall refuses when a dependent would break");

    oep_runtime_destroy(runtime);
}

void test_uninstall_impact_not_found(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "uninstall_not_found");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "uninstall_not_found").string().c_str());

    oep_uninstall_impact_t impact;
    oep_result_t result = oep_package_analyze_uninstall_impact(runtime, "com.oep.demo.nope", &impact, nullptr);
    check(result.success == 1, std::string("analyze_uninstall_impact succeeds even for a missing package: ") +
                                    result.error_message);
    check(impact.found == 0, "package is not found");
    check(impact.removable == 0, "not removable when not found");

    oep_runtime_destroy(runtime);
}

void test_update_impact_and_update_success(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "update_ok");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "update_ok").string().c_str());

    const std::filesystem::path archive_v1 = write_demo_archive(scratch_dir);
    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive_v1.string().c_str(), &install_result);
    check(result.success == 1, std::string("install v1 succeeds: ") + result.error_message);

    oep_update_impact_t impact;
    oep_package_id_list_t broken;
    result = oep_package_analyze_update_impact(runtime, archive_v1.string().c_str(), &impact, &broken);
    check(result.success == 1, std::string("analyze_update_impact succeeds: ") + result.error_message);
    check(impact.currently_installed == 1, "package is currently installed");
    check(std::string(impact.current_version) == "1.0.0", "current version reported");
    check(std::string(impact.candidate_version) == "1.0.0", "candidate version reported");
    check(broken.count == 0, "no broken dependents");
    oep_package_id_list_release(&broken);

    oep_package_update_result_t update_result;
    result = oep_package_update(runtime, archive_v1.string().c_str(), &update_result);
    check(result.success == 1, std::string("update succeeds: ") + result.error_message);
    check(std::string(update_result.package_id) == "com.oep.demo.capi", "update result reports package id");
    check(update_result.objects_created == 1, "update recreated the object");

    oep_runtime_destroy(runtime);
}

void test_update_impact_not_installed(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "update_not_installed");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "update_not_installed").string().c_str());

    const std::filesystem::path archive = write_demo_archive(scratch_dir);

    oep_update_impact_t impact;
    oep_result_t result = oep_package_analyze_update_impact(runtime, archive.string().c_str(), &impact, nullptr);
    check(result.success == 1, std::string("analyze_update_impact succeeds even when not installed: ") +
                                    result.error_message);
    check(impact.currently_installed == 0, "package is not currently installed");
    check(impact.updatable == 0, "not updatable when not currently installed");

    oep_package_update_result_t update_result;
    result = oep_package_update(runtime, archive.string().c_str(), &update_result);
    check(result.success == 0, "update refuses when the package isn't currently installed");

    oep_runtime_destroy(runtime);
}

void test_update_impact_breaks_dependent(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "update_breaks_dependent");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "update_breaks_dependent").string().c_str());

    const std::filesystem::path base_v1 =
        write_versioned_archive(scratch_dir, "com.oep.demo.updatable", "1.0.0", "updatable-v1.oep");
    oep_package_install_result_t base_install;
    oep_result_t result = oep_package_install(runtime, base_v1.string().c_str(), &base_install);
    check(result.success == 1, std::string("installing base package succeeds: ") + result.error_message);

    // A dependent that requires the base package to stay below 2.0.0.
    const std::filesystem::path dependent = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.dependent-update", "com.oep.demo.updatable", "<2.0.0", "dependent-update.oep");
    oep_package_install_result_t dependent_install;
    result = oep_package_install(runtime, dependent.string().c_str(), &dependent_install);
    check(result.success == 1, std::string("installing constrained dependent succeeds: ") + result.error_message);

    // The candidate archive bumps the base package to 2.0.0, which the
    // dependent's "<2.0.0" constraint would no longer satisfy.
    const std::filesystem::path base_v2 =
        write_versioned_archive(scratch_dir, "com.oep.demo.updatable", "2.0.0", "updatable-v2.oep");

    oep_update_impact_t impact;
    oep_package_id_list_t broken;
    result = oep_package_analyze_update_impact(runtime, base_v2.string().c_str(), &impact, &broken);
    check(result.success == 1, std::string("analyze_update_impact succeeds: ") + result.error_message);
    check(impact.currently_installed == 1, "base package is currently installed");
    check(std::string(impact.current_version) == "1.0.0", "current version reported as 1.0.0");
    check(std::string(impact.candidate_version) == "2.0.0", "candidate version reported as 2.0.0");
    check(impact.updatable == 0, "not updatable when a dependent would break");
    check(broken.count == 1 && std::string(broken.items[0].id) == "com.oep.demo.dependent-update",
          "broken dependent is named");
    oep_package_id_list_release(&broken);

    oep_package_update_result_t update_result;
    result = oep_package_update(runtime, base_v2.string().c_str(), &update_result);
    check(result.success == 0, "update refuses when it would break a dependent's required constraint");

    oep_runtime_destroy(runtime);
}

void test_uninstall_and_update_require_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_uninstall_impact_t uninstall_impact;
    check(oep_package_analyze_uninstall_impact(runtime, "x", &uninstall_impact, nullptr).error_code ==
              OEP_ERROR_INVALID_STATE,
          "analyze_uninstall_impact requires an open repository");

    oep_package_uninstall_result_t uninstall_result;
    check(oep_package_uninstall(runtime, "x", &uninstall_result).error_code == OEP_ERROR_INVALID_STATE,
          "uninstall requires an open repository");

    oep_update_impact_t update_impact;
    check(oep_package_analyze_update_impact(runtime, "x.oep", &update_impact, nullptr).error_code ==
              OEP_ERROR_INVALID_STATE,
          "analyze_update_impact requires an open repository");

    oep_package_update_result_t update_result;
    check(oep_package_update(runtime, "x.oep", &update_result).error_code == OEP_ERROR_INVALID_STATE,
          "update requires an open repository");

    oep_runtime_destroy(runtime);
}

void test_uninstall_and_update_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_uninstall_impact_t uninstall_impact;
    oep_package_uninstall_result_t uninstall_result;
    oep_update_impact_t update_impact;
    oep_package_update_result_t update_result;

    check(oep_package_analyze_uninstall_impact(nullptr, "x", &uninstall_impact, nullptr).error_code ==
              OEP_ERROR_INVALID_ARGUMENT,
          "analyze_uninstall_impact rejects a null runtime");
    check(oep_package_analyze_uninstall_impact(runtime, nullptr, &uninstall_impact, nullptr).error_code ==
              OEP_ERROR_INVALID_ARGUMENT,
          "analyze_uninstall_impact rejects a null package_id");
    check(oep_package_uninstall(nullptr, "x", &uninstall_result).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "uninstall rejects a null runtime");
    check(oep_package_uninstall(runtime, nullptr, &uninstall_result).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "uninstall rejects a null package_id");
    check(oep_package_analyze_update_impact(nullptr, "x.oep", &update_impact, nullptr).error_code ==
              OEP_ERROR_INVALID_ARGUMENT,
          "analyze_update_impact rejects a null runtime");
    check(oep_package_analyze_update_impact(runtime, nullptr, &update_impact, nullptr).error_code ==
              OEP_ERROR_INVALID_ARGUMENT,
          "analyze_update_impact rejects a null archive_path");
    check(oep_package_update(nullptr, "x.oep", &update_result).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "update rejects a null runtime");
    check(oep_package_update(runtime, nullptr, &update_result).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "update rejects a null archive_path");

    oep_runtime_destroy(runtime);
}

void test_event_type_includes_uninstall_and_update() {
    check(std::string(oep_event_type_to_string(OEP_EVENT_PACKAGE_UNINSTALLED)) == "PackageUninstalled",
          "OEP_EVENT_PACKAGE_UNINSTALLED stringifies correctly");
    check(std::string(oep_event_type_to_string(OEP_EVENT_PACKAGE_UPDATED)) == "PackageUpdated",
          "OEP_EVENT_PACKAGE_UPDATED stringifies correctly");
}

// Merge Engine (WP-REP-008): oep_repository_plan_merge / oep_repository_execute_merge.

void test_merge_plan_and_execute_clean_success(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "merge_ok");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "merge_ok").string().c_str());

    const std::filesystem::path archive =
        write_merge_archive(scratch_dir, "com.oep.demo.merge-clean", "aaaaaaaa-8888-4000-8000-000000000001",
                             "Merge Widget", "merge-clean.oep");

    oep_merge_plan_t plan;
    oep_merge_conflict_list_t conflicts;
    oep_result_t result = oep_repository_plan_merge(runtime, archive.string().c_str(), &plan, &conflicts);
    check(result.success == 1, std::string("oep_repository_plan_merge succeeds: ") + result.error_message);
    check(std::string(plan.package_id) == "com.oep.demo.merge-clean", "plan reports package id");
    check(std::string(plan.version) == "1.0.0", "plan reports version");
    check(plan.already_registered == 0, "package is not yet registered");
    check(plan.objects_to_create == 1, "one object would be created");
    check(plan.relationships_to_create == 0, "no relationships would be created");
    check(conflicts.count == 0, "no conflicts for a clean merge");
    check(plan.mergeable == 1, "plan is mergeable");
    oep_merge_conflict_list_release(&conflicts);

    oep_merge_result_t merge_result;
    result = oep_repository_execute_merge(runtime, archive.string().c_str(), &merge_result);
    check(result.success == 1, std::string("oep_repository_execute_merge succeeds: ") + result.error_message);
    check(std::string(merge_result.package_id) == "com.oep.demo.merge-clean", "merge result reports package id");
    check(std::string(merge_result.version) == "1.0.0", "merge result reports version");
    check(merge_result.objects_created == 1, "merge created one object");
    check(merge_result.relationships_created == 0, "merge created no relationships");

    oep_runtime_destroy(runtime);
}

void test_merge_plan_reports_conflict_and_refuses_execute(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "merge_conflict");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "merge_conflict").string().c_str());

    // First package installs an object with a given id and name.
    const std::filesystem::path first =
        write_merge_archive(scratch_dir, "com.oep.demo.merge-first", "aaaaaaaa-9999-4000-8000-000000000001",
                             "Original Name", "merge-first.oep");
    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, first.string().c_str(), &install_result);
    check(result.success == 1, std::string("installing first package succeeds: ") + result.error_message);

    // Second package declares the SAME object id with DIFFERENT content --
    // an ObjectContentConflict.
    const std::filesystem::path second =
        write_merge_archive(scratch_dir, "com.oep.demo.merge-second", "aaaaaaaa-9999-4000-8000-000000000001",
                             "Conflicting Name", "merge-second.oep");

    oep_merge_plan_t plan;
    oep_merge_conflict_list_t conflicts;
    result = oep_repository_plan_merge(runtime, second.string().c_str(), &plan, &conflicts);
    check(result.success == 1, std::string("oep_repository_plan_merge succeeds operationally: ") + result.error_message);
    check(plan.mergeable == 0, "plan with a conflict is not mergeable");
    check(conflicts.count == 1, "exactly one conflict is reported");
    if (conflicts.count == 1) {
        check(conflicts.items[0].kind == OEP_MERGE_CONFLICT_OBJECT_CONTENT, "conflict kind is ObjectContentConflict");
        check(std::string(conflicts.items[0].entity_id) == "aaaaaaaa-9999-4000-8000-000000000001",
              "conflict entity_id names the colliding object");
        check(std::string(oep_merge_conflict_kind_to_string(conflicts.items[0].kind)) == "ObjectContentConflict",
              "oep_merge_conflict_kind_to_string stringifies correctly");
    }
    oep_merge_conflict_list_release(&conflicts);

    oep_merge_result_t merge_result;
    result = oep_repository_execute_merge(runtime, second.string().c_str(), &merge_result);
    check(result.success == 0, "execute_merge refuses an unmergeable (conflicting) plan");

    oep_runtime_destroy(runtime);
}

void test_merge_already_registered_refusal(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "merge_already_registered");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "merge_already_registered").string().c_str());

    const std::filesystem::path archive = write_demo_archive(scratch_dir);
    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("install succeeds: ") + result.error_message);

    oep_merge_plan_t plan;
    result = oep_repository_plan_merge(runtime, archive.string().c_str(), &plan, nullptr);
    check(result.success == 1, std::string("plan_merge succeeds operationally: ") + result.error_message);
    check(plan.already_registered == 1, "package_id is already registered");
    check(plan.mergeable == 0, "an already-registered package is not mergeable");

    oep_merge_result_t merge_result;
    result = oep_repository_execute_merge(runtime, archive.string().c_str(), &merge_result);
    check(result.success == 0, "execute_merge refuses an already-registered package");

    oep_runtime_destroy(runtime);
}

void test_merge_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_merge_plan_t plan;
    check(oep_repository_plan_merge(runtime, "x.oep", &plan, nullptr).error_code == OEP_ERROR_INVALID_STATE,
          "plan_merge requires an open repository");

    oep_merge_result_t merge_result;
    check(oep_repository_execute_merge(runtime, "x.oep", &merge_result).error_code == OEP_ERROR_INVALID_STATE,
          "execute_merge requires an open repository");

    oep_runtime_destroy(runtime);
}

void test_merge_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_merge_plan_t plan;
    oep_merge_result_t merge_result;

    check(oep_repository_plan_merge(nullptr, "x.oep", &plan, nullptr).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "plan_merge rejects a null runtime");
    check(oep_repository_plan_merge(runtime, nullptr, &plan, nullptr).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "plan_merge rejects a null archive_path");
    check(oep_repository_plan_merge(runtime, "x.oep", nullptr, nullptr).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "plan_merge rejects a null out_plan");
    check(oep_repository_execute_merge(nullptr, "x.oep", &merge_result).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "execute_merge rejects a null runtime");
    check(oep_repository_execute_merge(runtime, nullptr, &merge_result).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "execute_merge rejects a null archive_path");

    oep_runtime_destroy(runtime);
}

void test_event_type_includes_merge() {
    check(std::string(oep_event_type_to_string(OEP_EVENT_REPOSITORY_MERGED)) == "RepositoryMerged",
          "OEP_EVENT_REPOSITORY_MERGED stringifies correctly");
}

void test_dependency_state_to_string_is_deterministic() {
    check(std::string(oep_dependency_state_to_string(OEP_DEPENDENCY_SATISFIED)) == "Satisfied",
          "OEP_DEPENDENCY_SATISFIED stringifies correctly");
    check(std::string(oep_dependency_state_to_string(OEP_DEPENDENCY_CYCLIC)) == "Cyclic",
          "OEP_DEPENDENCY_CYCLIC stringifies correctly");
}

// Repository Events (WP-REP-006): oep_runtime_recent_events reads back
// the events RuntimeService publishes as object/relationship mutations
// and package installs are sequenced through it.

void test_recent_events_reports_object_and_relationship_mutations(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "events_mutations");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    // A freshly opened repository has published no events of its own.
    oep_repository_event_list_t before_list;
    oep_result_t result = oep_runtime_recent_events(runtime, 0, &before_list);
    check(result.success == 1, std::string("oep_runtime_recent_events succeeds: ") + result.error_message);
    const int before_count = before_list.count;
    oep_repository_event_list_release(&before_list);

    oep_object_list_t objects;
    oep_object_store_list(runtime, &objects);
    check(objects.count == 2, "the fixture repository has exactly two objects for the events test");
    const std::string source_id = objects.count == 2 ? objects.items[0].object_id : "";
    const std::string target_id = objects.count == 2 ? objects.items[1].object_id : "";
    oep_object_list_release(&objects);

    oep_object_info_t created_object;
    const oep_result_t object_create_result = oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "Event Widget",
                                                                  "", "", nullptr, 0, &created_object);
    check(object_create_result.success, "oep_object_create succeeds for the events test");

    oep_relationship_info_t created_relationship;
    const oep_result_t relationship_create_result =
        oep_relationship_create(runtime, source_id.c_str(), target_id.c_str(), OEP_RELATIONSHIP_TYPE_CONTAINS, "",
                                 "", &created_relationship);
    check(relationship_create_result.success, "oep_relationship_create succeeds for the events test");

    oep_repository_event_list_t after_list;
    result = oep_runtime_recent_events(runtime, 0, &after_list);
    check(result.success == 1, std::string("oep_runtime_recent_events succeeds after mutations: ") +
                                    result.error_message);
    check(after_list.count == before_count + 2,
          "one event was published for the object create and one for the relationship create");

    bool found_object_created = false;
    bool found_relationship_created = false;
    for (int i = 0; i < after_list.count; ++i) {
        const oep_repository_event_t& event = after_list.items[i];
        if (event.type == OEP_EVENT_OBJECT_CREATED && std::string(event.subject_id) == created_object.object_id) {
            found_object_created = true;
            check(std::string(event.detail) == "Event Widget", "the ObjectCreated event's detail names the object");
        }
        if (event.type == OEP_EVENT_RELATIONSHIP_CREATED &&
            std::string(event.subject_id) == created_relationship.relationship_id) {
            found_relationship_created = true;
        }
    }
    check(found_object_created, "the object creation is queryable as an ObjectCreated event");
    check(found_relationship_created, "the relationship creation is queryable as a RelationshipCreated event");

    // Events are oldest-first, so sequence numbers increase monotonically.
    for (int i = 1; i < after_list.count; ++i) {
        check(after_list.items[i].sequence > after_list.items[i - 1].sequence,
              "events are reported oldest-first by increasing sequence");
    }

    oep_repository_event_list_release(&after_list);
    check(after_list.items == nullptr && after_list.count == 0, "release zeroes the event list");

    oep_runtime_destroy(runtime);
}

void test_recent_events_reports_package_install(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "events_install");
    const std::filesystem::path archive = write_demo_archive(scratch_dir);

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "events_install").string().c_str());

    // oep_package_install is the migrated thin wrapper (WP-REP-006): it
    // must still behave exactly as before...
    oep_package_install_result_t install_result;
    const oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("oep_package_install still succeeds: ") + result.error_message);
    check(std::string(install_result.package_id) == "com.oep.demo.capi",
          "oep_package_install still reports the installed packageId");
    check(install_result.objects_created == 1, "oep_package_install still reports the created object count");

    // ...and now additionally produce a PackageInstalled event.
    oep_repository_event_list_t events;
    const oep_result_t events_result = oep_runtime_recent_events(runtime, 0, &events);
    check(events_result.success == 1, "oep_runtime_recent_events succeeds after a package install");

    bool found_package_installed = false;
    for (int i = 0; i < events.count; ++i) {
        if (events.items[i].type == OEP_EVENT_PACKAGE_INSTALLED &&
            std::string(events.items[i].subject_id) == "com.oep.demo.capi") {
            found_package_installed = true;
        }
    }
    check(found_package_installed, "the package install is queryable as a PackageInstalled event");
    oep_repository_event_list_release(&events);

    oep_runtime_destroy(runtime);
}

void test_recent_events_limit_truncates(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "events_limit");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    for (int i = 0; i < 5; ++i) {
        oep_object_info_t created;
        const oep_result_t create_result = oep_object_create(
            runtime, OEP_OBJECT_TYPE_COMPONENT, ("Limit Widget " + std::to_string(i)).c_str(), "", "", nullptr, 0,
            &created);
        check(create_result.success, "creating object " + std::to_string(i) + " for the limit test succeeds");
    }

    oep_repository_event_list_t unlimited;
    oep_result_t result = oep_runtime_recent_events(runtime, 0, &unlimited);
    check(result.success == 1 && unlimited.count == 5, "limit 0 returns every published event (five creates)");
    const long long last_sequence = unlimited.items[unlimited.count - 1].sequence;
    oep_repository_event_list_release(&unlimited);

    oep_repository_event_list_t limited;
    result = oep_runtime_recent_events(runtime, 2, &limited);
    check(result.success == 1, std::string("oep_runtime_recent_events succeeds with a limit: ") + result.error_message);
    check(limited.count == 2, "limit 2 returns exactly two events");
    check(limited.items[1].sequence == last_sequence,
          "limit truncates to the most recently published events, not the oldest");
    oep_repository_event_list_release(&limited);

    oep_runtime_destroy(runtime);
}

void test_recent_events_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_repository_event_list_t list;
    const oep_result_t null_runtime_result = oep_runtime_recent_events(nullptr, 0, &list);
    check(!null_runtime_result.success && null_runtime_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_runtime_recent_events fails with OEP_ERROR_INVALID_ARGUMENT for a NULL runtime");

    const oep_result_t null_out_list_result = oep_runtime_recent_events(runtime, 0, nullptr);
    check(!null_out_list_result.success && null_out_list_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_runtime_recent_events fails with OEP_ERROR_INVALID_ARGUMENT for a NULL out_list");

    // Valid in any Runtime state, including before a repository is open.
    oep_repository_event_list_t no_repo_list;
    const oep_result_t no_repo_result = oep_runtime_recent_events(runtime, 0, &no_repo_list);
    check(no_repo_result.success == 1, "oep_runtime_recent_events succeeds without an open repository");
    check(no_repo_list.count == 0, "a freshly initialized runtime with no repository reports zero events");
    oep_repository_event_list_release(&no_repo_list);

    oep_runtime_destroy(runtime);
}

void test_version_reporting() {
    check(std::string(oep_foundation_version()) == "0.1.0", "oep_foundation_version reports the Foundation version");
    check(oep_api_version() == OEP_API_VERSION, "oep_api_version reports OEP_API_VERSION");
    check(oep_abi_version() == OEP_ABI_VERSION, "oep_abi_version reports OEP_ABI_VERSION");
}

void test_state_to_string_is_deterministic() {
    check(std::string(oep_runtime_state_to_string(OEP_STATE_UNINITIALIZED)) == "Uninitialized",
          "OEP_STATE_UNINITIALIZED stringifies correctly");
    check(std::string(oep_runtime_state_to_string(OEP_STATE_REPOSITORY_OPEN)) == "RepositoryOpen",
          "OEP_STATE_REPOSITORY_OPEN stringifies correctly");
    check(std::string(oep_runtime_state_to_string(OEP_STATE_REPOSITORY_OPEN)) ==
              std::string(oep_runtime_state_to_string(OEP_STATE_REPOSITORY_OPEN)),
          "state_to_string is deterministic across repeated calls");
}

void test_error_code_and_category_strings() {
    check(std::string(oep_error_code_to_string(OEP_ERROR_INVALID_STATE)) == "InvalidState",
          "OEP_ERROR_INVALID_STATE stringifies correctly");
    check(std::string(oep_error_category_to_string(OEP_ERROR_CATEGORY_STATE)) == "State",
          "OEP_ERROR_CATEGORY_STATE stringifies correctly");
}

void test_create_rejects_null_version() {
    OEP_Runtime runtime = oep_runtime_create(nullptr);
    check(runtime == nullptr, "oep_runtime_create returns NULL for a NULL foundation_version");
}

void test_destroy_is_null_safe() {
    oep_runtime_destroy(nullptr); // must not crash
    check(true, "oep_runtime_destroy(NULL) does not crash");
}

void test_null_handle_calls_return_invalid_argument() {
    const oep_result_t init_result = oep_runtime_initialize(nullptr);
    check(!init_result.success && init_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_runtime_initialize(NULL) fails with OEP_ERROR_INVALID_ARGUMENT");
    check(init_result.error_category == OEP_ERROR_CATEGORY_VALIDATION,
          "a NULL-handle failure reports OEP_ERROR_CATEGORY_VALIDATION");
    check(std::strlen(init_result.error_message) > 0, "a failed result carries a non-empty error message");

    check(oep_runtime_get_state(nullptr) == OEP_STATE_UNINITIALIZED,
          "oep_runtime_get_state(NULL) returns OEP_STATE_UNINITIALIZED rather than crashing");
}

void test_full_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "lifecycle");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    check(runtime != nullptr, "oep_runtime_create succeeds for a valid foundation_version");
    check(oep_runtime_get_state(runtime) == OEP_STATE_UNINITIALIZED, "a fresh handle starts Uninitialized");

    const oep_result_t open_before_init = oep_runtime_open_repository(runtime, root.string().c_str());
    check(!open_before_init.success && open_before_init.error_code == OEP_ERROR_INVALID_STATE,
          "opening a repository before initialize() fails with OEP_ERROR_INVALID_STATE");

    const oep_result_t init_result = oep_runtime_initialize(runtime);
    check(init_result.success, "oep_runtime_initialize succeeds from Uninitialized");
    check(oep_runtime_get_state(runtime) == OEP_STATE_INITIALIZED, "initialize transitions to Initialized");

    const oep_result_t reinit_result = oep_runtime_initialize(runtime);
    check(!reinit_result.success && reinit_result.error_code == OEP_ERROR_INVALID_STATE,
          "re-initializing an already-initialized Runtime fails with OEP_ERROR_INVALID_STATE");

    const oep_result_t open_result = oep_runtime_open_repository(runtime, root.string().c_str());
    check(open_result.success, "oep_runtime_open_repository succeeds for a valid repository");
    check(oep_runtime_get_state(runtime) == OEP_STATE_REPOSITORY_OPEN, "open_repository transitions to RepositoryOpen");

    oep_repository_status_t status;
    const oep_result_t status_result = oep_runtime_get_repository_status(runtime, &status);
    check(status_result.success, "oep_runtime_get_repository_status succeeds while a repository is open");
    check(status.repository_open != 0, "the status reports repository_open");
    check(std::string(status.repository_id) == "1b9e1b02-e845-482a-b299-1e15ffe3932b",
          "the status reports the correct repository_id");
    check(std::string(status.repository_name) == "my-workshop", "the status reports the correct repository_name");
    check(status.loaded_package_count == 0, "the status reports zero loaded packages for an empty repository");

    const oep_result_t close_result = oep_runtime_close_repository(runtime);
    check(close_result.success, "oep_runtime_close_repository succeeds while a repository is open");
    check(oep_runtime_get_state(runtime) == OEP_STATE_REPOSITORY_CLOSED, "close_repository transitions to RepositoryClosed");

    const oep_result_t close_again_result = oep_runtime_close_repository(runtime);
    check(!close_again_result.success && close_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "closing an already-closed repository fails with OEP_ERROR_INVALID_STATE");

    const oep_result_t shutdown_result = oep_runtime_shutdown(runtime);
    check(shutdown_result.success, "oep_runtime_shutdown succeeds");
    check(oep_runtime_get_state(runtime) == OEP_STATE_SHUTDOWN, "shutdown transitions to Shutdown");

    const oep_result_t shutdown_again_result = oep_runtime_shutdown(runtime);
    check(!shutdown_again_result.success && shutdown_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "shutting down an already-shut-down Runtime fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

void test_open_repository_reports_not_found(const std::filesystem::path& scratch_dir) {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    const std::filesystem::path missing = scratch_dir / "does-not-exist";
    const oep_result_t result = oep_runtime_open_repository(runtime, missing.string().c_str());
    check(!result.success, "opening a nonexistent repository fails");
    check(result.error_code == OEP_ERROR_NOT_FOUND, "opening a nonexistent repository reports OEP_ERROR_NOT_FOUND");
    check(result.error_category == OEP_ERROR_CATEGORY_IO, "a NotFound error reports OEP_ERROR_CATEGORY_IO");

    oep_runtime_destroy(runtime);
}

void test_open_repository_rejects_null_path() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    const oep_result_t result = oep_runtime_open_repository(runtime, nullptr);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "opening with a NULL repository_path fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_repository_status_fails_without_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_repository_status_t status;
    status.repository_open = 1; // deliberately non-zero, to confirm the API resets it
    const oep_result_t result = oep_runtime_get_repository_status(runtime, &status);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_STATE,
          "getting repository status without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(status.repository_open == 0, "a failed status call zero-initializes the output structure");

    oep_runtime_destroy(runtime);
}

void test_object_enumeration(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "enumeration");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    int count = -1;
    const oep_result_t count_result = oep_object_store_get_count(runtime, &count);
    check(count_result.success, "oep_object_store_get_count succeeds while a repository is open");
    check(count == 2, "the object count reflects both created objects");

    oep_object_list_t list;
    const oep_result_t list_result = oep_object_store_list(runtime, &list);
    check(list_result.success, "oep_object_store_list succeeds while a repository is open");
    check(list.count == 2, "the enumerated list contains both objects");
    check(list.items != nullptr, "a non-empty list has a non-NULL items array");

    if (list.count == 2) {
        check(std::string(list.items[0].object_id) < std::string(list.items[1].object_id),
              "the enumerated list is sorted deterministically by object_id");
    }

    bool found_coil = false;
    for (int i = 0; i < list.count; ++i) {
        if (std::string(list.items[i].name) == "Ignition Coil") {
            found_coil = true;
            check(list.items[i].object_type == OEP_OBJECT_TYPE_COMPONENT,
                  "the enumerated Ignition Coil object reports OEP_OBJECT_TYPE_COMPONENT");
            check(std::string(list.items[i].author) == "Jane", "the enumerated object reports the correct author");
            check(list.items[i].tag_count == 2, "the enumerated object reports both tags");
        }
    }
    check(found_coil, "the enumerated list includes the Ignition Coil object");

    // Repeating enumeration produces the same order (determinism across calls).
    oep_object_list_t second_list;
    oep_object_store_list(runtime, &second_list);
    bool same_order = second_list.count == list.count;
    for (int i = 0; same_order && i < list.count; ++i) {
        same_order = std::string(list.items[i].object_id) == std::string(second_list.items[i].object_id);
    }
    check(same_order, "repeated enumeration produces the same deterministic order");

    oep_object_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_object_list_release zeroes the released list");
    oep_object_list_release(&second_list);

    // Releasing an already-released (zeroed) list is a safe no-op.
    oep_object_list_release(&list);
    check(true, "releasing an already-released list does not crash");

    oep_object_list_release(nullptr);
    check(true, "oep_object_list_release(NULL) does not crash");

    oep_runtime_destroy(runtime);
}

void test_object_lookup_by_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "lookup");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t list;
    oep_object_store_list(runtime, &list);
    check(list.count == 2, "the fixture repository has exactly two objects for the lookup test");

    if (list.count == 2) {
        oep_object_info_t looked_up;
        const oep_result_t lookup_result = oep_object_store_get_by_id(runtime, list.items[0].object_id, &looked_up);
        check(lookup_result.success, "looking up an existing object by ID succeeds");
        check(std::string(looked_up.object_id) == std::string(list.items[0].object_id),
              "the looked-up object has the requested object_id");
        check(std::string(looked_up.name) == std::string(list.items[0].name),
              "the looked-up object has the requested name");
    }
    oep_object_list_release(&list);

    oep_object_info_t missing;
    const oep_result_t missing_result =
        oep_object_store_get_by_id(runtime, "00000000-0000-4000-8000-000000000000", &missing);
    check(!missing_result.success && missing_result.error_code == OEP_ERROR_NOT_FOUND,
          "looking up a nonexistent object ID fails with OEP_ERROR_NOT_FOUND");
    check(std::string(missing.object_id).empty(), "a failed lookup zero-initializes the output structure");

    const oep_result_t null_id_result = oep_object_store_get_by_id(runtime, nullptr, &missing);
    check(!null_id_result.success && null_id_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "looking up with a NULL object_id fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_object_enumeration_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    int count = -1;
    const oep_result_t count_result = oep_object_store_get_count(runtime, &count);
    check(!count_result.success && count_result.error_code == OEP_ERROR_INVALID_STATE,
          "getting the object count without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(count == 0, "a failed count call resets out_count to zero");

    oep_object_list_t list;
    const oep_result_t list_result = oep_object_store_list(runtime, &list);
    check(!list_result.success && list_result.error_code == OEP_ERROR_INVALID_STATE,
          "listing objects without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(list.items == nullptr && list.count == 0, "a failed list call is zero-initialized");

    oep_runtime_destroy(runtime);
}

void test_repository_statistics(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "statistics");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_repository_statistics_t statistics;
    const oep_result_t statistics_result = oep_runtime_get_repository_statistics(runtime, &statistics);
    check(statistics_result.success, "oep_runtime_get_repository_statistics succeeds while a repository is open");
    check(std::string(statistics.repository_id) == "1b9e1b02-e845-482a-b299-1e15ffe3932b",
          "statistics report the correct repository_id");
    check(std::string(statistics.repository_name) == "my-workshop", "statistics report the correct repository_name");
    check(statistics.total_object_count == 2, "statistics report the correct total object count");
    check(statistics.object_count_by_type[OEP_OBJECT_TYPE_COMPONENT] == 1,
          "statistics report exactly one Component object");
    check(statistics.object_count_by_type[OEP_OBJECT_TYPE_DOCUMENT] == 1,
          "statistics report exactly one Document object");
    check(statistics.object_count_by_type[OEP_OBJECT_TYPE_DIAGRAM] == 0,
          "statistics report zero for an object type not present in the repository");
    check(statistics.relationship_count == 1, "statistics report the correct relationship count");
    check(statistics.package_count == 0, "statistics report zero packages for a package-free repository");

    oep_runtime_destroy(runtime);
}

void test_repository_statistics_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_repository_statistics_t statistics;
    statistics.total_object_count = 99; // deliberately nonzero, to confirm the API resets it
    const oep_result_t result = oep_runtime_get_repository_statistics(runtime, &statistics);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_STATE,
          "getting repository statistics without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(statistics.total_object_count == 0, "a failed statistics call zero-initializes the output structure");

    oep_runtime_destroy(runtime);
}

void test_object_type_to_string() {
    check(std::string(oep_object_type_to_string(OEP_OBJECT_TYPE_COMPONENT)) == "Component",
          "OEP_OBJECT_TYPE_COMPONENT stringifies correctly");
    check(std::string(oep_object_type_to_string(OEP_OBJECT_TYPE_DOCUMENT)) == "Document",
          "OEP_OBJECT_TYPE_DOCUMENT stringifies correctly");
}

void test_relationship_enumeration(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "relationship-enumeration");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    int count = -1;
    const oep_result_t count_result = oep_relationship_store_get_count(runtime, &count);
    check(count_result.success, "oep_relationship_store_get_count succeeds while a repository is open");
    check(count == 1, "the relationship count reflects the one created relationship");

    oep_relationship_list_t list;
    const oep_result_t list_result = oep_relationship_store_list(runtime, &list);
    check(list_result.success, "oep_relationship_store_list succeeds while a repository is open");
    check(list.count == 1, "the enumerated list contains the one relationship");
    check(list.items != nullptr, "a non-empty list has a non-NULL items array");

    if (list.count == 1) {
        check(list.items[0].relationship_type == OEP_RELATIONSHIP_TYPE_DOCUMENTS,
              "the enumerated relationship reports OEP_RELATIONSHIP_TYPE_DOCUMENTS");
        check(std::strlen(list.items[0].source_object_id) == 36, "the relationship reports a source_object_id");
        check(std::strlen(list.items[0].target_object_id) == 36, "the relationship reports a target_object_id");
    }

    // Repeated enumeration produces the same deterministic order.
    oep_relationship_list_t second_list;
    oep_relationship_store_list(runtime, &second_list);
    bool same_order = second_list.count == list.count;
    for (int i = 0; same_order && i < list.count; ++i) {
        same_order = std::string(list.items[i].relationship_id) == std::string(second_list.items[i].relationship_id);
    }
    check(same_order, "repeated relationship enumeration produces the same deterministic order");

    oep_relationship_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_relationship_list_release zeroes the released list");
    oep_relationship_list_release(&second_list);

    oep_relationship_list_release(&list); // already released; must be a safe no-op
    check(true, "releasing an already-released relationship list does not crash");
    oep_relationship_list_release(nullptr);
    check(true, "oep_relationship_list_release(NULL) does not crash");

    oep_runtime_destroy(runtime);
}

void test_relationship_lookup_by_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "relationship-lookup");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_relationship_list_t list;
    oep_relationship_store_list(runtime, &list);
    check(list.count == 1, "the fixture repository has exactly one relationship for the lookup test");

    if (list.count == 1) {
        oep_relationship_info_t looked_up;
        const oep_result_t lookup_result =
            oep_relationship_store_get_by_id(runtime, list.items[0].relationship_id, &looked_up);
        check(lookup_result.success, "looking up an existing relationship by ID succeeds");
        check(std::string(looked_up.relationship_id) == std::string(list.items[0].relationship_id),
              "the looked-up relationship has the requested relationship_id");
        check(std::string(looked_up.source_object_id) == std::string(list.items[0].source_object_id),
              "the looked-up relationship has the requested source_object_id");
    }
    oep_relationship_list_release(&list);

    oep_relationship_info_t missing;
    const oep_result_t missing_result =
        oep_relationship_store_get_by_id(runtime, "00000000-0000-4000-8000-000000000000", &missing);
    check(!missing_result.success && missing_result.error_code == OEP_ERROR_NOT_FOUND,
          "looking up a nonexistent relationship ID fails with OEP_ERROR_NOT_FOUND");
    check(std::string(missing.relationship_id).empty(), "a failed lookup zero-initializes the output structure");

    const oep_result_t null_id_result = oep_relationship_store_get_by_id(runtime, nullptr, &missing);
    check(!null_id_result.success && null_id_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "looking up with a NULL relationship_id fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_relationship_enumeration_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    int count = -1;
    const oep_result_t count_result = oep_relationship_store_get_count(runtime, &count);
    check(!count_result.success && count_result.error_code == OEP_ERROR_INVALID_STATE,
          "getting the relationship count without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(count == 0, "a failed count call resets out_count to zero");

    oep_relationship_list_t list;
    const oep_result_t list_result = oep_relationship_store_list(runtime, &list);
    check(!list_result.success && list_result.error_code == OEP_ERROR_INVALID_STATE,
          "listing relationships without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(list.items == nullptr && list.count == 0, "a failed list call is zero-initialized");

    oep_runtime_destroy(runtime);
}

void test_relationship_type_to_string() {
    check(std::string(oep_relationship_type_to_string(OEP_RELATIONSHIP_TYPE_DOCUMENTS)) == "Documents",
          "OEP_RELATIONSHIP_TYPE_DOCUMENTS stringifies correctly");
    check(std::string(oep_relationship_type_to_string(OEP_RELATIONSHIP_TYPE_REFERENCES)) == "References",
          "OEP_RELATIONSHIP_TYPE_REFERENCES stringifies correctly");
}

void test_match_location_to_string() {
    check(std::string(oep_match_location_to_string(OEP_MATCH_LOCATION_NAME)) == "Name",
          "OEP_MATCH_LOCATION_NAME stringifies correctly");
    check(std::string(oep_match_location_to_string(OEP_MATCH_LOCATION_TAGS)) == "Tags",
          "OEP_MATCH_LOCATION_TAGS stringifies correctly");
}

void test_search_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "search-objects");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_search_result_list_t list;
    const oep_result_t result = oep_search_objects(runtime, "coil", &list);
    check(result.success, "oep_search_objects succeeds for a matching query");
    check(list.count == 1, "searching for 'coil' finds exactly the Ignition Coil object");
    if (list.count == 1) {
        check(std::string(list.items[0].display_name) == "Ignition Coil",
              "the search result reports the correct display_name");
        check(list.items[0].object_type == OEP_OBJECT_TYPE_COMPONENT,
              "the search result reports the correct object_type");
        check(list.items[0].match_score > 0.0, "the search result reports a positive match_score");
    }
    oep_object_search_result_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_object_search_result_list_release zeroes the list");

    oep_object_search_result_list_t no_match_list;
    oep_search_objects(runtime, "zzz-nomatch", &no_match_list);
    check(no_match_list.count == 0, "searching for a nonexistent term finds no objects");
    oep_object_search_result_list_release(&no_match_list);

    oep_object_search_result_list_t empty_query_list;
    const oep_result_t empty_query_result = oep_search_objects(runtime, "", &empty_query_list);
    check(!empty_query_result.success, "searching with an empty query fails");

    const oep_result_t null_query_result = oep_search_objects(runtime, nullptr, &list);
    check(!null_query_result.success && null_query_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "searching with a NULL query fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_search_relationships(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "search-relationships");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_relationship_search_result_list_t list;
    const oep_result_t result = oep_search_relationships(runtime, "documents", &list);
    check(result.success, "oep_search_relationships succeeds for a matching query");
    check(list.count == 1, "searching for 'documents' finds the one Documents relationship");
    if (list.count == 1) {
        check(list.items[0].relationship_type == OEP_RELATIONSHIP_TYPE_DOCUMENTS,
              "the search result reports the correct relationship_type");
    }
    oep_relationship_search_result_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_relationship_search_result_list_release zeroes the list");

    oep_runtime_destroy(runtime);
}

void test_search_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "search-repository");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_repository_search_result_t result;
    const oep_result_t search_result = oep_search_repository(runtime, "jane", &result);
    check(search_result.success, "oep_search_repository succeeds for a matching query");
    check(result.objects.count >= 1, "searching 'jane' finds at least one object (both objects have author Jane)");
    check(result.relationships.count >= 0, "the relationships list is present, even if zero-length");
    oep_repository_search_result_release(&result);
    check(result.objects.items == nullptr && result.objects.count == 0,
          "oep_repository_search_result_release zeroes the objects list");
    check(result.relationships.items == nullptr && result.relationships.count == 0,
          "oep_repository_search_result_release zeroes the relationships list");

    oep_repository_search_result_release(nullptr);
    check(true, "oep_repository_search_result_release(NULL) does not crash");

    oep_runtime_destroy(runtime);
}

void test_search_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_object_search_result_list_t objects_list;
    const oep_result_t objects_result = oep_search_objects(runtime, "anything", &objects_list);
    check(!objects_result.success && objects_result.error_code == OEP_ERROR_INVALID_STATE,
          "searching objects without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(objects_list.items == nullptr && objects_list.count == 0, "the failed search's list is zero-initialized");

    oep_repository_search_result_t repo_result;
    const oep_result_t repo_search_result = oep_search_repository(runtime, "anything", &repo_result);
    check(!repo_search_result.success && repo_search_result.error_code == OEP_ERROR_INVALID_STATE,
          "searching the repository without an open repository fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

// ---------------------------------------------------------------------
// Work Package 014: Object Mutation, Relationship Mutation,
// Transactions, Batch Mutation.
// ---------------------------------------------------------------------

void test_object_create_update_delete(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "object-mutation");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    const char* tags[2] = {"electrical", "ignition"};
    oep_object_info_t created;
    const oep_result_t create_result =
        oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "Ignition Coil", "Generates spark", "Jane", tags, 2,
                           &created);
    check(create_result.success, "oep_object_create succeeds for a valid Component");
    check(std::strlen(created.object_id) == 36, "the created object has a generated object_id");
    check(std::string(created.name) == "Ignition Coil", "the created object reports the given name");
    check(created.object_type == OEP_OBJECT_TYPE_COMPONENT, "the created object reports the given type");
    check(created.tag_count == 2, "the created object reports both tags");

    oep_object_info_t null_name_result;
    const oep_result_t null_name = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, nullptr, "", "", nullptr, 0,
                                                       &null_name_result);
    check(!null_name.success && null_name.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_create fails with OEP_ERROR_INVALID_ARGUMENT for a NULL name");

    oep_object_info_t empty_name_result;
    const oep_result_t empty_name =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "", "", "", nullptr, 0, &empty_name_result);
    check(!empty_name.success && empty_name.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_create fails for an empty name via Foundation's own validation");

    oep_object_info_t updated;
    const oep_result_t update_result =
        oep_object_update(runtime, created.object_id, "Ignition Coil (Rev B)", "Updated", "Jane Doe", nullptr, 0,
                           &updated);
    check(update_result.success, "oep_object_update succeeds");
    check(std::string(updated.name) == "Ignition Coil (Rev B)", "the updated object reports the new name");
    check(std::string(updated.object_id) == std::string(created.object_id), "the updated object keeps its object_id");
    check(updated.object_type == OEP_OBJECT_TYPE_COMPONENT, "the updated object keeps its original object_type");
    check(updated.tag_count == 0, "the updated object reflects the new (empty) tag list");

    oep_object_info_t missing_update;
    const oep_result_t missing_update_result = oep_object_update(
        runtime, "00000000-0000-4000-8000-000000000000", "X", "", "", nullptr, 0, &missing_update);
    check(!missing_update_result.success && missing_update_result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_object_update fails with OEP_ERROR_NOT_FOUND for a nonexistent object_id");

    const oep_result_t delete_result = oep_object_delete(runtime, created.object_id);
    check(delete_result.success, "oep_object_delete succeeds");

    const oep_result_t double_delete_result = oep_object_delete(runtime, created.object_id);
    check(!double_delete_result.success && double_delete_result.error_code == OEP_ERROR_NOT_FOUND,
          "deleting the same object twice fails with OEP_ERROR_NOT_FOUND");

    const oep_result_t null_object_id_result = oep_object_delete(runtime, nullptr);
    check(!null_object_id_result.success && null_object_id_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_delete fails with OEP_ERROR_INVALID_ARGUMENT for a NULL object_id");

    oep_runtime_destroy(runtime);
}

// AP-DS-002: oep_object_update_content / oep_object_get_content, the
// owned-heap-string content payload used to persist Diagram Studio's
// presentation-layer state without inventing a fixed-layout field on
// oep_object_info_t.
void test_object_content_update_and_get(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "object-content");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_info_t created;
    const oep_result_t create_result =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DIAGRAM, "Wiring Diagram", "", "Jane", nullptr, 0, &created);
    check(create_result.success, "setup: oep_object_create succeeds");

    char* empty_content = nullptr;
    std::size_t empty_length = 12345;
    const oep_result_t empty_get = oep_object_get_content(runtime, created.object_id, &empty_content, &empty_length);
    check(empty_get.success, "oep_object_get_content succeeds for a freshly created object");
    check(empty_content != nullptr && std::string(empty_content).empty() && empty_length == 0,
          "a freshly created object's content is an empty, owned string, not an error");
    oep_string_release(&empty_content);
    check(empty_content == nullptr, "oep_string_release nulls the pointer");

    const std::string payload = R"({"nodes":[{"id":"n1","x":10,"y":20}],"viewport":{"zoom":1.5}})";
    oep_object_info_t updated;
    const oep_result_t update_result =
        oep_object_update_content(runtime, created.object_id, payload.c_str(), &updated);
    check(update_result.success, "oep_object_update_content succeeds");
    check(std::string(updated.name) == "Wiring Diagram", "oep_object_update_content leaves name unchanged");
    check(updated.object_type == OEP_OBJECT_TYPE_DIAGRAM, "oep_object_update_content leaves object_type unchanged");

    char* fetched_content = nullptr;
    std::size_t fetched_length = 0;
    const oep_result_t fetch_result =
        oep_object_get_content(runtime, created.object_id, &fetched_content, &fetched_length);
    check(fetch_result.success, "oep_object_get_content succeeds after an update");
    check(fetched_content != nullptr && std::string(fetched_content) == payload && fetched_length == payload.size(),
          "oep_object_get_content returns exactly the content set by oep_object_update_content, with a matching length");
    oep_string_release(&fetched_content);

    oep_object_info_t missing_update;
    const oep_result_t missing_update_result = oep_object_update_content(
        runtime, "00000000-0000-4000-8000-000000000000", "{}", &missing_update);
    check(!missing_update_result.success && missing_update_result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_object_update_content fails with OEP_ERROR_NOT_FOUND for a nonexistent object_id");

    char* missing_get_content = nullptr;
    std::size_t missing_get_length = 0;
    const oep_result_t missing_get_result = oep_object_get_content(
        runtime, "00000000-0000-4000-8000-000000000000", &missing_get_content, &missing_get_length);
    check(!missing_get_result.success && missing_get_result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_object_get_content fails with OEP_ERROR_NOT_FOUND for a nonexistent object_id");
    check(missing_get_content == nullptr, "a failed oep_object_get_content leaves out_text NULL");

    const oep_result_t null_runtime_result = oep_object_get_content(nullptr, created.object_id, &fetched_content, &fetched_length);
    check(!null_runtime_result.success && null_runtime_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_get_content fails with OEP_ERROR_INVALID_ARGUMENT for a NULL runtime handle");

    oep_runtime_destroy(runtime);
}

void test_object_mutation_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_object_info_t out_object;
    const oep_result_t create_result =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "X", "", "", nullptr, 0, &out_object);
    check(!create_result.success && create_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_object_create fails with OEP_ERROR_INVALID_STATE without an open repository");

    const oep_result_t delete_result = oep_object_delete(runtime, "00000000-0000-4000-8000-000000000000");
    check(!delete_result.success && delete_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_object_delete fails with OEP_ERROR_INVALID_STATE without an open repository");

    oep_runtime_destroy(runtime);
}

void test_relationship_create_update_delete(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "relationship-mutation");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects;
    oep_object_store_list(runtime, &objects);
    check(objects.count == 2, "the fixture repository has exactly two objects for relationship mutation tests");
    const std::string source_id = objects.count == 2 ? objects.items[0].object_id : "";
    const std::string target_id = objects.count == 2 ? objects.items[1].object_id : "";
    oep_object_list_release(&objects);

    oep_relationship_info_t created;
    const oep_result_t create_result =
        oep_relationship_create(runtime, source_id.c_str(), target_id.c_str(), OEP_RELATIONSHIP_TYPE_CONTAINS,
                                 "Jane", "a new relationship", &created);
    check(create_result.success, "oep_relationship_create succeeds for two existing objects");
    check(std::strlen(created.relationship_id) == 36, "the created relationship has a generated relationship_id");
    check(created.relationship_type == OEP_RELATIONSHIP_TYPE_CONTAINS, "the created relationship reports the given type");

    oep_relationship_info_t missing_source_result;
    const oep_result_t missing_source = oep_relationship_create(
        runtime, "00000000-0000-4000-8000-000000000000", target_id.c_str(), OEP_RELATIONSHIP_TYPE_REFERENCES, "", "",
        &missing_source_result);
    check(!missing_source.success && missing_source.error_code == OEP_ERROR_NOT_FOUND,
          "oep_relationship_create fails with OEP_ERROR_NOT_FOUND for a nonexistent source object");

    oep_relationship_info_t updated;
    const oep_result_t update_result =
        oep_relationship_update(runtime, created.relationship_id, "Jane Doe", "revised description", &updated);
    check(update_result.success, "oep_relationship_update succeeds");
    check(std::string(updated.author) == "Jane Doe", "the updated relationship reports the new author");
    check(updated.relationship_type == OEP_RELATIONSHIP_TYPE_CONTAINS,
          "the updated relationship keeps its original relationship_type");
    check(std::string(updated.source_object_id) == source_id,
          "the updated relationship keeps its original source_object_id");

    oep_relationship_info_t missing_update;
    const oep_result_t missing_update_result = oep_relationship_update(
        runtime, "00000000-0000-4000-8000-000000000000", "", "", &missing_update);
    check(!missing_update_result.success && missing_update_result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_relationship_update fails with OEP_ERROR_NOT_FOUND for a nonexistent relationship_id");

    const oep_result_t delete_result = oep_relationship_delete(runtime, created.relationship_id);
    check(delete_result.success, "oep_relationship_delete succeeds");

    const oep_result_t double_delete_result = oep_relationship_delete(runtime, created.relationship_id);
    check(!double_delete_result.success && double_delete_result.error_code == OEP_ERROR_NOT_FOUND,
          "deleting the same relationship twice fails with OEP_ERROR_NOT_FOUND");

    oep_runtime_destroy(runtime);
}

void test_transaction_commit(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "transaction-commit");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    check(!oep_transaction_is_active(runtime), "no transaction is active initially");

    const oep_result_t begin_result = oep_transaction_begin(runtime);
    check(begin_result.success, "oep_transaction_begin succeeds from RepositoryOpen");
    check(oep_transaction_is_active(runtime), "the transaction reports active after begin");

    const oep_result_t nested_begin_result = oep_transaction_begin(runtime);
    check(!nested_begin_result.success && nested_begin_result.error_code == OEP_ERROR_INVALID_STATE,
          "a nested oep_transaction_begin fails with OEP_ERROR_INVALID_STATE");

    oep_object_info_t created;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Committed Object", "", "", nullptr, 0, &created);

    const oep_result_t commit_result = oep_transaction_commit(runtime);
    check(commit_result.success, "oep_transaction_commit succeeds");
    check(!oep_transaction_is_active(runtime), "the transaction reports inactive after commit");

    oep_object_info_t looked_up;
    const oep_result_t lookup_result = oep_object_store_get_by_id(runtime, created.object_id, &looked_up);
    check(lookup_result.success, "the committed object still exists after commit");

    const oep_result_t commit_again_result = oep_transaction_commit(runtime);
    check(!commit_again_result.success && commit_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "committing with no active transaction fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

void test_transaction_rollback(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "transaction-rollback");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_info_t survivor;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Survivor", "", "", nullptr, 0, &survivor);

    oep_transaction_begin(runtime);

    oep_object_info_t doomed_object;
    const oep_result_t create_result =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Doomed", "", "", nullptr, 0, &doomed_object);
    check(create_result.success, "create inside a transaction succeeds and is visible immediately");

    oep_object_info_t updated_survivor;
    oep_object_update(runtime, survivor.object_id, "Survivor (Modified)", "", "", nullptr, 0, &updated_survivor);

    const oep_result_t rollback_result = oep_transaction_rollback(runtime);
    check(rollback_result.success, "oep_transaction_rollback succeeds");
    check(!oep_transaction_is_active(runtime), "the transaction reports inactive after rollback");

    oep_object_info_t missing_doomed;
    const oep_result_t doomed_lookup = oep_object_store_get_by_id(runtime, doomed_object.object_id, &missing_doomed);
    check(!doomed_lookup.success && doomed_lookup.error_code == OEP_ERROR_NOT_FOUND,
          "the object created inside the rolled-back transaction no longer exists");

    oep_object_info_t restored_survivor;
    const oep_result_t survivor_lookup =
        oep_object_store_get_by_id(runtime, survivor.object_id, &restored_survivor);
    check(survivor_lookup.success && std::string(restored_survivor.name) == "Survivor",
          "the object updated inside the rolled-back transaction is restored to its pre-transaction name");

    const oep_result_t rollback_again_result = oep_transaction_rollback(runtime);
    check(!rollback_again_result.success && rollback_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "rolling back with no active transaction fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

void test_transaction_automatic_rollback_on_failure(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "transaction-auto-rollback");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_transaction_begin(runtime);

    oep_object_info_t first;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "First", "", "", nullptr, 0, &first);

    oep_object_info_t failed;
    const oep_result_t failing_create =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "", "", "", nullptr, 0, &failed);
    check(!failing_create.success, "a create with an invalid empty name fails inside the transaction");
    check(!oep_transaction_is_active(runtime),
          "the transaction is automatically deactivated after the failure, per TASK-000029");

    oep_object_info_t missing_first;
    const oep_result_t first_lookup = oep_object_store_get_by_id(runtime, first.object_id, &missing_first);
    check(!first_lookup.success && first_lookup.error_code == OEP_ERROR_NOT_FOUND,
          "the successful create earlier in the transaction was automatically rolled back too");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 0, "the repository has zero objects after the automatic rollback");

    oep_runtime_destroy(runtime);
}

void test_transaction_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    const oep_result_t begin_result = oep_transaction_begin(runtime);
    check(!begin_result.success && begin_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_transaction_begin fails with OEP_ERROR_INVALID_STATE without an open repository");
    check(!oep_transaction_is_active(runtime), "oep_transaction_is_active(NULL-state runtime) reports inactive");

    oep_runtime_destroy(runtime);
}

void test_batch_create_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "batch-create-objects");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_create_spec_t specs[3];
    specs[0] = {OEP_OBJECT_TYPE_DOCUMENT, "Batch A", "", "", nullptr, 0};
    specs[1] = {OEP_OBJECT_TYPE_COMPONENT, "Batch B", "", "", nullptr, 0};
    specs[2] = {OEP_OBJECT_TYPE_DOCUMENT, "Batch C", "", "", nullptr, 0};

    oep_batch_create_objects_result_t result;
    const oep_result_t call_result = oep_batch_create_objects(runtime, specs, 3, &result);
    check(call_result.success, "oep_batch_create_objects succeeds for three valid specs");
    check(result.success != 0, "the batch result itself reports success");
    check(result.failed_index == -1, "failed_index is -1 on a fully successful batch");
    check(result.created.count == 3, "three objects were created");
    check(std::string(result.created.items[0].name) == "Batch A",
          "the created list preserves execution order (index 0)");
    check(std::string(result.created.items[1].name) == "Batch B",
          "the created list preserves execution order (index 1)");
    check(std::string(result.created.items[2].name) == "Batch C",
          "the created list preserves execution order (index 2)");
    oep_batch_create_objects_result_release(&result);
    check(result.created.items == nullptr, "oep_batch_create_objects_result_release zeroes the created list");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 3, "all three batch-created objects are persisted");

    oep_runtime_destroy(runtime);
}

void test_batch_create_objects_rolls_back_on_failure(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "batch-create-objects-failure");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_create_spec_t specs[3];
    specs[0] = {OEP_OBJECT_TYPE_DOCUMENT, "Should Not Survive 1", "", "", nullptr, 0};
    specs[1] = {OEP_OBJECT_TYPE_DOCUMENT, "", "", "", nullptr, 0}; // invalid: empty name
    specs[2] = {OEP_OBJECT_TYPE_DOCUMENT, "Should Not Survive 3", "", "", nullptr, 0};

    oep_batch_create_objects_result_t result;
    const oep_result_t call_result = oep_batch_create_objects(runtime, specs, 3, &result);
    check(!call_result.success, "oep_batch_create_objects fails when one spec is invalid");
    check(result.failed_index == 1, "failed_index identifies the second (0-based) spec");
    check(result.created.count == 0, "the created list is empty — the whole batch was rolled back");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 0, "no objects were persisted after the failed batch rolled back");

    oep_runtime_destroy(runtime);
}

void test_batch_create_relationships(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "batch-create-relationships");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects;
    oep_object_store_list(runtime, &objects);
    check(objects.count == 2, "the fixture repository has exactly two objects for batch relationship tests");
    const std::string source_id = objects.count == 2 ? objects.items[0].object_id : "";
    const std::string target_id = objects.count == 2 ? objects.items[1].object_id : "";
    oep_object_list_release(&objects);

    oep_relationship_create_spec_t specs[2];
    specs[0] = {source_id.c_str(), target_id.c_str(), OEP_RELATIONSHIP_TYPE_REFERENCES, "Jane", "first"};
    specs[1] = {target_id.c_str(), source_id.c_str(), OEP_RELATIONSHIP_TYPE_CONNECTED_TO, "Jane", "second"};

    oep_batch_create_relationships_result_t result;
    const oep_result_t call_result = oep_batch_create_relationships(runtime, specs, 2, &result);
    check(call_result.success, "oep_batch_create_relationships succeeds for two valid specs");
    check(result.created.count == 2, "two relationships were created");
    oep_batch_create_relationships_result_release(&result);
    check(result.created.items == nullptr, "oep_batch_create_relationships_result_release zeroes the created list");

    int count = -1;
    oep_relationship_store_get_count(runtime, &count);
    check(count == 3, "both batch-created relationships are persisted alongside the fixture's existing one");

    oep_runtime_destroy(runtime);
}

void test_batch_participates_in_caller_transaction(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "batch-caller-transaction");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_transaction_begin(runtime);

    oep_object_info_t manual_object;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Manually Created", "", "", nullptr, 0, &manual_object);

    oep_object_create_spec_t specs[1] = {{OEP_OBJECT_TYPE_DOCUMENT, "Batch Item", "", "", nullptr, 0}};
    oep_batch_create_objects_result_t batch_result;
    oep_batch_create_objects(runtime, specs, 1, &batch_result);

    check(oep_transaction_is_active(runtime) != 0,
          "the transaction the caller began is still active after a successful batch participates in it");

    const oep_result_t rollback_result = oep_transaction_rollback(runtime);
    check(rollback_result.success, "rolling back the caller's transaction succeeds");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 0,
          "rolling back the caller's transaction undoes both the manual create and the batch create together");

    oep_runtime_destroy(runtime);
}

void test_destroy_closes_an_open_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "destroy-open");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    const oep_result_t open_result = oep_runtime_open_repository(runtime, root.string().c_str());
    check(open_result.success, "opening the fixture repository succeeds for the destroy-while-open test");

    oep_runtime_destroy(runtime); // must not leak or crash even with a repository still open
    check(true, "destroying a handle with an open repository does not crash");
}

} // namespace

void test_package_install_and_lifecycle_queries(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "package_lifecycle");
    const std::filesystem::path archive = write_demo_archive(scratch_dir);

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "package_lifecycle").string().c_str());

    // install
    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("oep_package_install succeeds: ") + result.error_message);
    check(std::string(install_result.package_id) == "com.oep.demo.capi",
          "the install result carries the installed packageId");
    check(install_result.objects_created == 1, "the install result counts the installed object");

    // list
    oep_installed_package_list_t installed;
    result = oep_package_list_installed(runtime, &installed);
    check(result.success == 1 && installed.count == 1, "oep_package_list_installed lists the installed package");
    oep_installed_package_list_release(&installed);

    // get_info
    oep_package_details_t details;
    result = oep_package_get_info(runtime, "com.oep.demo.capi", &details);
    check(result.success == 1, std::string("oep_package_get_info succeeds: ") + result.error_message);
    check(std::string(details.title) == "C API Demo Package", "package details carry the title");
    check(std::string(details.publisher_name) == "OEP Demo Publisher", "package details carry the publisher");
    check(std::string(details.runtime_state) == "Installed", "package details carry the runtime state");
    check(std::strlen(details.package_hash) == 64, "package details carry a SHA-256 hash");
    check(details.engineering_domain_count == 1 &&
              std::string(details.engineering_domains[0]) == "Automotive",
          "package details carry the engineering domains");
    check(details.object_count == 1 && details.relationship_count == 0,
          "package details carry contribution counts");

    result = oep_package_get_info(runtime, "com.oep.no-such", &details);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_get_info reports NOT_FOUND for an uninstalled package");

    // get_contents
    oep_object_list_t content_objects;
    oep_relationship_list_t content_relationships;
    result = oep_package_get_contents(runtime, "com.oep.demo.capi", &content_objects, &content_relationships);
    check(result.success == 1, std::string("oep_package_get_contents succeeds: ") + result.error_message);
    check(content_objects.count == 1 && std::string(content_objects.items[0].name) == "API Harness",
          "package contents include the installed object, loaded live from the repository");
    check(content_relationships.count == 0, "package contents report no relationships for this package");
    oep_object_list_release(&content_objects);
    oep_relationship_list_release(&content_relationships);

    // locate
    oep_package_owner_t owner;
    result = oep_package_locate(runtime, "aaaaaaaa-3333-4000-8000-000000000001", &owner);
    check(result.success == 1 && owner.found == 1 && owner.kind == OEP_OWNED_ENTITY_OBJECT,
          "oep_package_locate resolves an installed object to its owner");
    check(std::string(owner.package_id) == "com.oep.demo.capi", "the owner is the installed package");

    result = oep_package_locate(runtime, "not-an-id", &owner);
    check(result.success == 1 && owner.found == 0,
          "oep_package_locate succeeds with found == 0 for an unowned id — a normal answer, not an error");

    // verify
    oep_package_verify_result_t verify_result;
    result = oep_package_verify(runtime, "com.oep.demo.capi", &verify_result);
    check(result.success == 1 && verify_result.verified == 1,
          "oep_package_verify passes for an intact install");
    check(verify_result.archive_available == 1 && verify_result.archive_hash_matches == 1,
          "oep_package_verify confirms the archive hash");

    result = oep_package_verify(runtime, "com.oep.no-such", &verify_result);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_verify reports NOT_FOUND for an uninstalled package");

    // search
    oep_installed_package_list_t matches;
    result = oep_package_search(runtime, "API Harness", &matches);
    check(result.success == 1 && matches.count == 1,
          "oep_package_search matches by installed object name");
    oep_installed_package_list_release(&matches);

    result = oep_package_search(runtime, "", &matches);
    check(result.success == 0 && result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_package_search rejects an empty query");

    oep_runtime_destroy(runtime);
}

void test_transaction_engine_info_and_history(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "transaction_engine");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "transaction_engine").string().c_str());

    // No transaction active: info succeeds with active == 0.
    oep_transaction_info_t info;
    oep_result_t result = oep_transaction_get_info(runtime, &info);
    check(result.success == 1 && info.active == 0,
          "oep_transaction_get_info reports no active transaction as a normal answer");

    // Active transaction: id and description are visible.
    oep_transaction_begin(runtime);
    result = oep_transaction_get_info(runtime, &info);
    check(result.success == 1 && info.active == 1 && std::strlen(info.transaction_id) == 36,
          "an active transaction reports a UUIDv4 transaction id");

    oep_object_info_t created;
    oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "Journaled Widget", "", "author", nullptr, 0, &created);
    result = oep_transaction_get_info(runtime, &info);
    check(result.success == 1 && info.journal_entry_count == 1,
          "the active transaction counts its journaled operations");

    oep_transaction_commit(runtime);

    // A single mutation outside a transaction is journaled too (implicit
    // transaction), so history now has two records.
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Implicit Doc", "", "author", nullptr, 0, nullptr);

    oep_transaction_record_list_t history;
    result = oep_transaction_history(runtime, &history);
    check(result.success == 1 && history.count == 2,
          "oep_transaction_history lists the explicit and the implicit transaction");
    bool all_committed = true;
    for (int i = 0; i < history.count; ++i) {
        if (std::string(history.items[i].state) != "Committed") all_committed = false;
        check(std::strlen(history.items[i].transaction_id) == 36, "every history record has a transaction id");
    }
    check(all_committed, "both journaled transactions are Committed");
    oep_transaction_record_list_release(&history);
    check(history.items == nullptr && history.count == 0, "release zeroes the history list");

    oep_runtime_destroy(runtime);
}

void test_transaction_engine_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_transaction_info_t info;
    check(oep_transaction_get_info(runtime, &info).error_code == OEP_ERROR_INVALID_STATE,
          "oep_transaction_get_info requires an open repository");
    oep_transaction_record_list_t history;
    check(oep_transaction_history(runtime, &history).error_code == OEP_ERROR_INVALID_STATE,
          "oep_transaction_history requires an open repository");

    oep_runtime_destroy(runtime);
}

void test_trust_store_certificate_lifecycle(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "trust_capi");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "trust_capi").string().c_str());

    // Default policy: signatures not required.
    int require_signatures = -1;
    oep_result_t result = oep_trust_get_policy(runtime, &require_signatures);
    check(result.success == 1 && require_signatures == 0, "the default trust policy does not require signatures");

    // No certificate yet: NOT_FOUND.
    oep_publisher_certificate_t certificate;
    result = oep_trust_get_certificate(runtime, "com.pub.capi", &certificate);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_trust_get_certificate reports NOT_FOUND before any certificate is added");

    // Add.
    const char* public_key_hex = "99c4ac9e6560c3a1e4bfd6a20e5ab6513aa77eea9233c01fe296e8b17f106cff";
    result = oep_trust_add_certificate(runtime, "com.pub.capi", "CAPI Publisher", public_key_hex,
                                        "2026-01-01T00:00:00Z", "2030-01-01T00:00:00Z", "self", "1", &certificate);
    check(result.success == 1, std::string("oep_trust_add_certificate succeeds: ") + result.error_message);
    check(std::string(certificate.publisher_name) == "CAPI Publisher", "the returned certificate carries its fields");
    check(std::strlen(certificate.fingerprint) == 64, "the returned certificate carries a computed fingerprint");
    check(certificate.revoked == 0, "a freshly added certificate is not revoked");

    // Adding again for the same publisher is rejected (no renewal).
    result = oep_trust_add_certificate(runtime, "com.pub.capi", "CAPI Publisher", public_key_hex, nullptr, nullptr,
                                        nullptr, nullptr, nullptr);
    check(result.success == 0, "a second certificate for the same publisher is rejected");

    // Get.
    result = oep_trust_get_certificate(runtime, "com.pub.capi", &certificate);
    check(result.success == 1 && std::string(certificate.publisher_id) == "com.pub.capi",
          "oep_trust_get_certificate finds the added certificate");

    // List.
    oep_certificate_list_t list;
    result = oep_trust_list_certificates(runtime, &list);
    check(result.success == 1 && list.count == 1, "oep_trust_list_certificates lists the added certificate");
    oep_certificate_list_release(&list);
    check(list.items == nullptr && list.count == 0, "release zeroes the certificate list");

    // Set policy, then revoke.
    result = oep_trust_set_policy(runtime, 1);
    check(result.success == 1, "oep_trust_set_policy succeeds");
    result = oep_trust_get_policy(runtime, &require_signatures);
    check(result.success == 1 && require_signatures == 1, "the policy change round-trips");

    result = oep_trust_revoke_certificate(runtime, "com.pub.capi");
    check(result.success == 1, "oep_trust_revoke_certificate succeeds");
    result = oep_trust_get_certificate(runtime, "com.pub.capi", &certificate);
    check(result.success == 1 && certificate.revoked == 1, "the certificate is kept, marked revoked");

    result = oep_trust_revoke_certificate(runtime, "com.pub.capi");
    check(result.success == 0, "revoking an already-revoked certificate fails");
    result = oep_trust_revoke_certificate(runtime, "com.pub.never-added");
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "revoking an unknown publisher reports NOT_FOUND");

    oep_runtime_destroy(runtime);
}

void test_package_trust_status_and_unsigned_install(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "trust_status_capi");
    const std::filesystem::path archive = write_demo_archive(scratch_dir);

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "trust_status_capi").string().c_str());

    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("an unsigned package still installs by default: ") + result.error_message);

    oep_package_trust_status_t trust_status;
    result = oep_package_get_trust_status(runtime, "com.oep.demo.capi", &trust_status);
    check(result.success == 1 && trust_status.state == OEP_TRUST_UNSIGNED,
          "oep_package_get_trust_status reports OEP_TRUST_UNSIGNED for an unsigned install");

    result = oep_package_get_trust_status(runtime, "com.oep.no-such", &trust_status);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_get_trust_status reports NOT_FOUND for an uninstalled package");

    oep_runtime_destroy(runtime);
}

void test_trust_functions_require_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_publisher_certificate_t certificate;
    check(oep_trust_add_certificate(runtime, "x", nullptr, "y", nullptr, nullptr, nullptr, nullptr, nullptr)
                  .error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_add_certificate requires an open repository");
    check(oep_trust_get_certificate(runtime, "x", &certificate).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_get_certificate requires an open repository");
    oep_certificate_list_t list;
    check(oep_trust_list_certificates(runtime, &list).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_list_certificates requires an open repository");
    check(oep_trust_revoke_certificate(runtime, "x").error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_revoke_certificate requires an open repository");
    int require_signatures = 0;
    check(oep_trust_get_policy(runtime, &require_signatures).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_get_policy requires an open repository");
    check(oep_trust_set_policy(runtime, 1).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_set_policy requires an open repository");
    oep_package_trust_status_t trust_status;
    check(oep_package_get_trust_status(runtime, "x", &trust_status).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_get_trust_status requires an open repository");

    oep_runtime_destroy(runtime);
}

void test_package_queries_require_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_package_details_t details;
    check(oep_package_get_info(runtime, "x", &details).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_get_info requires an open repository");
    oep_package_owner_t owner;
    check(oep_package_locate(runtime, "x", &owner).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_locate requires an open repository");
    oep_package_verify_result_t verify_result;
    check(oep_package_verify(runtime, "x", &verify_result).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_verify requires an open repository");
    oep_installed_package_list_t list;
    check(oep_package_search(runtime, "x", &list).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_search requires an open repository");
    oep_object_list_t objects;
    oep_relationship_list_t relationships;
    check(oep_package_get_contents(runtime, "x", &objects, &relationships).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_get_contents requires an open repository");

    oep_runtime_destroy(runtime);
}

// -------------------------------------------------------------------
// Engineering Knowledge Runtime (WP-EKE-001)
// -------------------------------------------------------------------

void test_engine_load_object_and_load_graph(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "engine-load");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects{};
    oep_object_store_list(runtime, &objects);
    check(objects.count == 2, "the populated fixture has two objects to load");
    const std::string coil_id = objects.items[0].name == std::string("Ignition Coil") ? objects.items[0].object_id
                                                                                        : objects.items[1].object_id;
    oep_object_list_release(&objects);

    oep_object_info_t loaded_object{};
    int found = 0;
    const oep_result_t load_object_result = oep_engine_load_object(runtime, coil_id.c_str(), &loaded_object, &found);
    check(load_object_result.success, "oep_engine_load_object succeeds for an existing object");
    check(found != 0, "oep_engine_load_object reports found for an existing object");
    check(std::string(loaded_object.name) == "Ignition Coil", "oep_engine_load_object returns the correct object");

    int not_found = 1;
    oep_object_info_t missing_object{};
    const oep_result_t missing_result =
        oep_engine_load_object(runtime, "00000000-0000-4000-8000-000000000000", &missing_object, &not_found);
    check(missing_result.success, "oep_engine_load_object succeeds (as an operation) for a nonexistent id");
    check(not_found == 0, "oep_engine_load_object reports not-found for a nonexistent id");

    int objects_loaded = 0;
    int relationships_loaded = 0;
    const oep_result_t load_graph_result = oep_engine_load_graph(runtime, &objects_loaded, &relationships_loaded);
    check(load_graph_result.success, "oep_engine_load_graph succeeds");
    check(objects_loaded == 2, "oep_engine_load_graph reports two objects loaded");
    check(relationships_loaded == 1, "oep_engine_load_graph reports one relationship loaded");

    oep_runtime_destroy(runtime);
}

void test_engine_load_object_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_object_info_t out_object{};
    int found = 0;
    const oep_result_t result = oep_engine_load_object(runtime, "x", &out_object, &found);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_engine_load_object fails with OEP_ERROR_INVALID_STATE without an open repository");

    int objects_loaded = 0;
    int relationships_loaded = 0;
    const oep_result_t load_graph_result = oep_engine_load_graph(runtime, &objects_loaded, &relationships_loaded);
    check(!load_graph_result.success && load_graph_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_engine_load_graph fails with OEP_ERROR_INVALID_STATE without an open repository");

    oep_runtime_destroy(runtime);
}

void test_engine_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");

    oep_object_info_t out_object{};
    check(!oep_engine_load_object(nullptr, "x", &out_object, nullptr).success,
          "oep_engine_load_object rejects a NULL runtime handle");
    check(!oep_engine_load_object(runtime, nullptr, &out_object, nullptr).success,
          "oep_engine_load_object rejects a NULL object_id");
    check(!oep_engine_load_graph(nullptr, nullptr, nullptr).success,
          "oep_engine_load_graph rejects a NULL runtime handle");
    check(!oep_engine_query(nullptr, nullptr, nullptr, nullptr, nullptr).success,
          "oep_engine_query rejects a NULL runtime handle");
    check(!oep_engine_query(runtime, nullptr, nullptr, nullptr, nullptr).success,
          "oep_engine_query rejects a NULL request");
    check(!oep_engine_traverse(nullptr, "x", 0, 0, OEP_RELATIONSHIP_TYPE_REFERENCES, 0, 0, nullptr).success,
          "oep_engine_traverse rejects a NULL runtime handle");
    check(!oep_engine_traverse(runtime, nullptr, 0, 0, OEP_RELATIONSHIP_TYPE_REFERENCES, 0, 0, nullptr).success,
          "oep_engine_traverse rejects a NULL start_object_id");
    check(!oep_engine_related_objects(nullptr, "x", nullptr).success,
          "oep_engine_related_objects rejects a NULL runtime handle");
    check(!oep_engine_related_objects(runtime, nullptr, nullptr).success,
          "oep_engine_related_objects rejects a NULL object_id");
    check(!oep_engine_dependency_graph(nullptr, "x", nullptr, nullptr).success,
          "oep_engine_dependency_graph rejects a NULL runtime handle");
    check(!oep_engine_dependency_graph(runtime, nullptr, nullptr, nullptr).success,
          "oep_engine_dependency_graph rejects a NULL object_id");

    oep_runtime_destroy(runtime);
}

void test_engine_query_by_id_and_by_type(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "engine-query");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects{};
    oep_object_store_list(runtime, &objects);
    const std::string coil_id = objects.items[0].name == std::string("Ignition Coil") ? objects.items[0].object_id
                                                                                        : objects.items[1].object_id;
    oep_object_list_release(&objects);

    // query() before load_graph() fails descriptively.
    oep_engine_query_request_t not_loaded_request{};
    not_loaded_request.kind = OEP_ENGINE_QUERY_BY_ID;
    not_loaded_request.object_id = coil_id.c_str();
    oep_package_id_list_t not_loaded_ids{};
    const oep_result_t not_loaded_result = oep_engine_query(runtime, &not_loaded_request, &not_loaded_ids, nullptr, nullptr);
    check(!not_loaded_result.success && not_loaded_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_engine_query fails with OEP_ERROR_INVALID_STATE before oep_engine_load_graph");
    oep_package_id_list_release(&not_loaded_ids);

    int objects_loaded = 0;
    check(oep_engine_load_graph(runtime, &objects_loaded, nullptr).success, "oep_engine_load_graph succeeds");

    oep_engine_query_request_t by_id_request{};
    by_id_request.kind = OEP_ENGINE_QUERY_BY_ID;
    by_id_request.object_id = coil_id.c_str();
    oep_package_id_list_t by_id_result{};
    const oep_result_t by_id = oep_engine_query(runtime, &by_id_request, &by_id_result, nullptr, nullptr);
    check(by_id.success, "oep_engine_query ById succeeds");
    check(by_id_result.count == 1 && std::string(by_id_result.items[0].id) == coil_id,
          "oep_engine_query ById returns exactly the requested id");
    oep_package_id_list_release(&by_id_result);

    oep_engine_query_request_t by_type_request{};
    by_type_request.kind = OEP_ENGINE_QUERY_BY_TYPE;
    by_type_request.object_type = OEP_OBJECT_TYPE_COMPONENT;
    oep_package_id_list_t by_type_result{};
    const oep_result_t by_type = oep_engine_query(runtime, &by_type_request, &by_type_result, nullptr, nullptr);
    check(by_type.success, "oep_engine_query ByType succeeds");
    check(by_type_result.count == 1, "oep_engine_query ByType finds exactly the one Component");
    oep_package_id_list_release(&by_type_result);

    oep_runtime_destroy(runtime);
}

void test_engine_traverse_related_objects_and_dependency_graph(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "engine-traverse");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects{};
    oep_object_store_list(runtime, &objects);
    const std::string manual_id = objects.items[0].name == std::string("Manual") ? objects.items[0].object_id
                                                                                   : objects.items[1].object_id;
    oep_object_list_release(&objects);

    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");

    oep_package_id_list_t traversal_result{};
    const oep_result_t traversal =
        oep_engine_traverse(runtime, manual_id.c_str(), 0, 0, OEP_RELATIONSHIP_TYPE_REFERENCES, 0, 0, &traversal_result);
    check(traversal.success, "oep_engine_traverse succeeds");
    check(traversal_result.count == 2, "BFS traversal from Manual visits both objects (Manual and Ignition Coil)");
    oep_package_id_list_release(&traversal_result);

    const oep_result_t bad_order =
        oep_engine_traverse(runtime, manual_id.c_str(), 2, 0, OEP_RELATIONSHIP_TYPE_REFERENCES, 0, 0, nullptr);
    check(!bad_order.success && bad_order.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_engine_traverse rejects an order value other than 0 or 1");

    oep_package_id_list_t related_result{};
    const oep_result_t related = oep_engine_related_objects(runtime, manual_id.c_str(), &related_result);
    check(related.success, "oep_engine_related_objects succeeds");
    check(related_result.count == 1, "Manual has exactly one related object (Ignition Coil)");
    oep_package_id_list_release(&related_result);

    oep_package_id_list_t dep_objects{};
    oep_package_id_list_t dep_relationships{};
    const oep_result_t dependency_graph =
        oep_engine_dependency_graph(runtime, manual_id.c_str(), &dep_objects, &dep_relationships);
    check(dependency_graph.success, "oep_engine_dependency_graph succeeds");
    check(dep_objects.count == 1 && std::string(dep_objects.items[0].id) == manual_id,
          "dependency_graph with no DependsOn edges returns only the starting object");
    check(dep_relationships.count == 0, "dependency_graph with no DependsOn edges returns no relationship ids");
    oep_package_id_list_release(&dep_objects);
    oep_package_id_list_release(&dep_relationships);

    oep_runtime_destroy(runtime);
}

void test_kge_build_and_refresh_graph(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-build");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    int objects = 0;
    int relationships = 0;
    const oep_result_t build_result = oep_kge_build_graph(runtime, &objects, &relationships);
    check(build_result.success, "oep_kge_build_graph succeeds");
    check(objects == 2, "oep_kge_build_graph reports two objects");
    check(relationships == 1, "oep_kge_build_graph reports one relationship");

    int refreshed_objects = 0;
    const oep_result_t refresh_result = oep_kge_refresh_graph(runtime, &refreshed_objects, nullptr);
    check(refresh_result.success, "oep_kge_refresh_graph succeeds");
    check(refreshed_objects == 2, "oep_kge_refresh_graph reports two objects");

    oep_runtime_destroy(runtime);
}

void test_kge_build_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    const oep_result_t result = oep_kge_build_graph(runtime, nullptr, nullptr);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_kge_build_graph fails with OEP_ERROR_INVALID_STATE without an open repository");

    oep_runtime_destroy(runtime);
}

void test_kge_validate_clean_graph(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-validate-clean");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    // validate_graph before build_graph fails descriptively.
    int not_built_valid = 1;
    const oep_result_t not_built_result = oep_kge_validate_graph(runtime, &not_built_valid, nullptr);
    check(!not_built_result.success && not_built_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_kge_validate_graph fails with OEP_ERROR_INVALID_STATE before oep_kge_build_graph");

    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    int valid = 0;
    oep_graph_issue_list_t issues{};
    const oep_result_t validate_result = oep_kge_validate_graph(runtime, &valid, &issues);
    check(validate_result.success, "oep_kge_validate_graph succeeds on a clean graph");
    check(valid != 0, "oep_kge_validate_graph reports a clean graph as valid");
    check(issues.count == 0, "oep_kge_validate_graph reports no issues for a clean graph");
    oep_graph_issue_list_release(&issues);

    oep_runtime_destroy(runtime);
}

void test_kge_validate_reports_cycle(const std::filesystem::path& scratch_dir) {
    // RelationshipStore::validate_relationship (see relationship.cpp)
    // actively forbids self-loops and only ever creates relationships
    // between two objects that both exist -- so MissingEndpoint,
    // BrokenReference, and SelfReference cannot be produced through the
    // public mutation API by design (the repository layer itself
    // prevents those states). A directed CYCLE, however, is a
    // perfectly legal repository state, so it is the one GraphIssue
    // kind exercisable end-to-end here.
    const std::filesystem::path root = build_repository(scratch_dir / "kge-validate-cycle");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_info_t a{};
    oep_object_info_t b{};
    oep_object_info_t c{};
    check(oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "A", "", "", nullptr, 0, &a).success,
          "creating object A succeeds");
    check(oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "B", "", "", nullptr, 0, &b).success,
          "creating object B succeeds");
    check(oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "C", "", "", nullptr, 0, &c).success,
          "creating object C succeeds");

    check(oep_relationship_create(runtime, a.object_id, b.object_id, OEP_RELATIONSHIP_TYPE_DEPENDS_ON, "", "",
                                   nullptr)
              .success,
          "creating relationship A -> B succeeds");
    check(oep_relationship_create(runtime, b.object_id, c.object_id, OEP_RELATIONSHIP_TYPE_DEPENDS_ON, "", "",
                                   nullptr)
              .success,
          "creating relationship B -> C succeeds");
    check(oep_relationship_create(runtime, c.object_id, a.object_id, OEP_RELATIONSHIP_TYPE_DEPENDS_ON, "", "",
                                   nullptr)
              .success,
          "creating relationship C -> A succeeds (closing the cycle)");

    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds after the cycle");

    int valid = 1;
    oep_graph_issue_list_t issues{};
    const oep_result_t validate_result = oep_kge_validate_graph(runtime, &valid, &issues);
    check(validate_result.success, "oep_kge_validate_graph succeeds (as an operation) on a graph with a cycle");
    check(valid == 0, "oep_kge_validate_graph reports the graph as invalid");
    check(issues.count >= 1, "oep_kge_validate_graph reports at least one issue");
    bool found_cycle = false;
    for (int i = 0; i < issues.count; ++i) {
        if (issues.items[i].kind == OEP_GRAPH_ISSUE_CYCLE) found_cycle = true;
    }
    check(found_cycle, "oep_kge_validate_graph reports a Cycle issue");
    oep_graph_issue_list_release(&issues);

    oep_runtime_destroy(runtime);
}

void test_kge_graph_statistics(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-statistics");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_graph_statistics_t stats{};
    const oep_result_t stats_result = oep_kge_graph_statistics(runtime, &stats);
    check(stats_result.success, "oep_kge_graph_statistics succeeds");
    check(stats.object_count == 2, "oep_kge_graph_statistics reports two objects");
    check(stats.relationship_count == 1, "oep_kge_graph_statistics reports one relationship");
    check(stats.connected_component_count == 1, "oep_kge_graph_statistics reports one connected component");

    oep_runtime_destroy(runtime);
}

void test_kge_connected_components(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-components");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_component_membership_list_t components{};
    int component_count = 0;
    const oep_result_t result = oep_kge_connected_components(runtime, &components, &component_count);
    check(result.success, "oep_kge_connected_components succeeds");
    check(component_count == 1, "oep_kge_connected_components reports one component for the connected pair");
    check(components.count == 2, "oep_kge_connected_components flattens to one entry per object");
    check(components.items[0].component_index == components.items[1].component_index,
          "oep_kge_connected_components tags both objects with the same component_index");
    oep_component_membership_list_release(&components);

    oep_runtime_destroy(runtime);
}

void test_kge_shortest_path(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-shortest-path");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects{};
    oep_object_store_list(runtime, &objects);
    const std::string coil_id = objects.items[0].name == std::string("Ignition Coil") ? objects.items[0].object_id
                                                                                        : objects.items[1].object_id;
    const std::string manual_id = objects.items[0].name == std::string("Manual") ? objects.items[0].object_id
                                                                                   : objects.items[1].object_id;
    oep_object_list_release(&objects);

    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    int path_exists = 0;
    oep_package_id_list_t path{};
    const oep_result_t result =
        oep_kge_shortest_path(runtime, manual_id.c_str(), coil_id.c_str(), &path_exists, &path);
    check(result.success, "oep_kge_shortest_path succeeds");
    check(path_exists != 0, "a path exists from Manual to Coil");
    check(path.count == 2, "the shortest path from Manual to Coil has two nodes");
    oep_package_id_list_release(&path);

    // A target id that isn't even present in the graph fails outright
    // (GraphAlgorithms::shortest_path requires both endpoints to be
    // graph members) -- distinct from "no path exists between two
    // present-but-disconnected objects", which is a successful result
    // with path_exists == 0.
    const std::string bogus_id = "00000000-0000-4000-8000-000000000000";
    int no_path_exists = 1;
    const oep_result_t no_path_result =
        oep_kge_shortest_path(runtime, manual_id.c_str(), bogus_id.c_str(), &no_path_exists, nullptr);
    check(!no_path_result.success && no_path_result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_kge_shortest_path fails with OEP_ERROR_NOT_FOUND for a target not present in the graph");
    check(no_path_exists == 0, "out_path_exists is reset to 0 when the target is not present");

    oep_runtime_destroy(runtime);
}

void test_kge_subgraph(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-subgraph");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects{};
    oep_object_store_list(runtime, &objects);
    const std::string coil_id = objects.items[0].name == std::string("Ignition Coil") ? objects.items[0].object_id
                                                                                        : objects.items[1].object_id;
    const std::string manual_id = objects.items[0].name == std::string("Manual") ? objects.items[0].object_id
                                                                                   : objects.items[1].object_id;
    oep_object_list_release(&objects);

    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    const char* ids[2] = {manual_id.c_str(), coil_id.c_str()};
    oep_package_id_list_t sub_objects{};
    oep_package_id_list_t sub_relationships{};
    const oep_result_t result = oep_kge_subgraph(runtime, ids, 2, &sub_objects, &sub_relationships);
    check(result.success, "oep_kge_subgraph succeeds");
    check(sub_objects.count == 2, "oep_kge_subgraph over both objects returns both");
    check(sub_relationships.count == 1, "oep_kge_subgraph over both objects returns the connecting relationship");
    oep_package_id_list_release(&sub_objects);
    oep_package_id_list_release(&sub_relationships);

    // object_id_count == 0 with a NULL array is valid (empty subgraph),
    // not an argument error.
    oep_package_id_list_t empty_objects{};
    const oep_result_t empty_result = oep_kge_subgraph(runtime, nullptr, 0, &empty_objects, nullptr);
    check(empty_result.success, "oep_kge_subgraph with zero ids succeeds");
    check(empty_objects.count == 0, "oep_kge_subgraph with zero ids returns an empty subgraph");
    oep_package_id_list_release(&empty_objects);

    oep_runtime_destroy(runtime);
}

void test_kge_export_json_and_graphml(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-export");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    char* json_text = nullptr;
    size_t json_length = 0;
    const oep_result_t json_result = oep_kge_export_json(runtime, &json_text, &json_length);
    check(json_result.success, "oep_kge_export_json succeeds");
    check(json_text != nullptr, "oep_kge_export_json returns an owned buffer");
    check(json_length == std::strlen(json_text), "oep_kge_export_json reports the buffer's true length");
    check(std::string(json_text).find("\"objects\"") != std::string::npos,
          "oep_kge_export_json's output includes an objects array");
    oep_string_release(&json_text);
    check(json_text == nullptr, "oep_string_release nulls out the pointer");

    char* graphml_text = nullptr;
    size_t graphml_length = 0;
    const oep_result_t graphml_result = oep_kge_export_graphml_placeholder(runtime, &graphml_text, &graphml_length);
    check(graphml_result.success, "oep_kge_export_graphml_placeholder succeeds");
    check(graphml_text != nullptr, "oep_kge_export_graphml_placeholder returns an owned buffer");
    check(std::string(graphml_text).find("<graphml") != std::string::npos,
          "oep_kge_export_graphml_placeholder's output is a graphml document");
    oep_string_release(&graphml_text);

    oep_runtime_destroy(runtime);
}

void test_kge_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");

    check(!oep_kge_build_graph(nullptr, nullptr, nullptr).success, "oep_kge_build_graph rejects a NULL runtime handle");
    check(!oep_kge_refresh_graph(nullptr, nullptr, nullptr).success,
          "oep_kge_refresh_graph rejects a NULL runtime handle");
    check(!oep_kge_validate_graph(nullptr, nullptr, nullptr).success,
          "oep_kge_validate_graph rejects a NULL runtime handle");
    int valid = 0;
    check(!oep_kge_validate_graph(runtime, nullptr, nullptr).success,
          "oep_kge_validate_graph rejects a NULL out_valid");
    check(!oep_kge_graph_statistics(nullptr, nullptr).success,
          "oep_kge_graph_statistics rejects a NULL runtime handle");
    oep_graph_statistics_t stats{};
    check(!oep_kge_graph_statistics(runtime, nullptr).success, "oep_kge_graph_statistics rejects a NULL out_stats");
    check(!oep_kge_connected_components(nullptr, nullptr, nullptr).success,
          "oep_kge_connected_components rejects a NULL runtime handle");
    check(!oep_kge_shortest_path(nullptr, "a", "b", nullptr, nullptr).success,
          "oep_kge_shortest_path rejects a NULL runtime handle");
    check(!oep_kge_shortest_path(runtime, nullptr, "b", nullptr, nullptr).success,
          "oep_kge_shortest_path rejects a NULL source_id");
    check(!oep_kge_shortest_path(runtime, "a", nullptr, nullptr, nullptr).success,
          "oep_kge_shortest_path rejects a NULL target_id");
    int path_exists = 0;
    check(!oep_kge_shortest_path(runtime, "a", "b", nullptr, nullptr).success,
          "oep_kge_shortest_path rejects a NULL out_path_exists");
    check(!oep_kge_subgraph(nullptr, nullptr, 0, nullptr, nullptr).success,
          "oep_kge_subgraph rejects a NULL runtime handle");
    const char* one_id[1] = {"a"};
    check(!oep_kge_subgraph(runtime, nullptr, 1, nullptr, nullptr).success,
          "oep_kge_subgraph rejects a NULL object_ids array with a nonzero count");
    check(!oep_kge_subgraph(runtime, one_id, -1, nullptr, nullptr).success,
          "oep_kge_subgraph rejects a negative object_id_count");
    char* out_text = nullptr;
    size_t out_length = 0;
    check(!oep_kge_export_json(nullptr, &out_text, &out_length).success,
          "oep_kge_export_json rejects a NULL runtime handle");
    check(!oep_kge_export_json(runtime, nullptr, &out_length).success, "oep_kge_export_json rejects a NULL out_text");
    check(!oep_kge_export_json(runtime, &out_text, nullptr).success, "oep_kge_export_json rejects a NULL out_length");
    check(!oep_kge_export_graphml_placeholder(nullptr, &out_text, &out_length).success,
          "oep_kge_export_graphml_placeholder rejects a NULL runtime handle");
    (void)valid;
    (void)stats;
    (void)path_exists;

    // oep_string_release/oep_graph_issue_list_release/
    // oep_component_membership_list_release are all NULL-safe.
    oep_string_release(nullptr);
    oep_graph_issue_list_release(nullptr);
    oep_component_membership_list_release(nullptr);

    oep_runtime_destroy(runtime);
}

void test_kge_operations_require_graph_built(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "kge-not-built");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_graph_statistics_t stats{};
    check(!oep_kge_graph_statistics(runtime, &stats).success && stats.object_count == 0,
          "oep_kge_graph_statistics fails with a zeroed struct before oep_kge_build_graph");

    oep_component_membership_list_t components{};
    check(!oep_kge_connected_components(runtime, &components, nullptr).success,
          "oep_kge_connected_components fails before oep_kge_build_graph");

    int path_exists = 1;
    check(!oep_kge_shortest_path(runtime, "a", "b", &path_exists, nullptr).success && path_exists == 0,
          "oep_kge_shortest_path fails with path_exists reset to 0 before oep_kge_build_graph");

    char* out_text = nullptr;
    size_t out_length = 0;
    check(!oep_kge_export_json(runtime, &out_text, &out_length).success && out_text == nullptr,
          "oep_kge_export_json fails with a NULL out_text before oep_kge_build_graph");

    oep_runtime_destroy(runtime);
}

void test_eqe_plan_and_execute_query(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "eqe-plan-execute");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_object_list_t objects{};
    oep_object_store_list(runtime, &objects);
    const std::string manual_id = objects.items[0].name == std::string("Manual") ? objects.items[0].object_id
                                                                                   : objects.items[1].object_id;
    oep_object_list_release(&objects);

    // OEP_QUERY_CATEGORY_OBJECT: primary_object_id lookup.
    oep_query_request_t object_request{};
    object_request.category = OEP_QUERY_CATEGORY_OBJECT;
    std::snprintf(object_request.primary_object_id, sizeof(object_request.primary_object_id), "%s", manual_id.c_str());

    oep_query_plan_t plan{};
    oep_package_id_list_t indexes_used{};
    oep_package_id_list_t execution_order{};
    const oep_result_t plan_result = oep_eqe_plan_query(runtime, &object_request, &plan, &indexes_used, &execution_order);
    check(plan_result.success, "oep_eqe_plan_query succeeds for an Object query");
    check(plan.category == OEP_QUERY_CATEGORY_OBJECT, "planned query category is Object");
    oep_package_id_list_release(&indexes_used);
    oep_package_id_list_release(&execution_order);

    oep_query_result_summary_t summary{};
    oep_package_id_list_t result_objects{};
    oep_package_id_list_t result_relationships{};
    const oep_result_t exec_result =
        oep_eqe_execute_query(runtime, &object_request, &summary, &result_objects, &result_relationships);
    check(exec_result.success, "oep_eqe_execute_query succeeds for an Object query");
    check(summary.result_count == 1, "Object query for a known id returns exactly one result");
    check(result_objects.count == 1 && std::string(result_objects.items[0].id) == manual_id,
          "Object query returns the requested object id");
    oep_package_id_list_release(&result_objects);
    oep_package_id_list_release(&result_relationships);

    // OEP_QUERY_CATEGORY_TYPE: filter by object_type.
    oep_query_request_t type_request{};
    type_request.category = OEP_QUERY_CATEGORY_TYPE;
    type_request.filter.has_object_type = 1;
    type_request.filter.object_type = OEP_OBJECT_TYPE_DOCUMENT;

    oep_query_result_summary_t type_summary{};
    oep_package_id_list_t type_objects{};
    const oep_result_t type_exec = oep_eqe_execute_query(runtime, &type_request, &type_summary, &type_objects, nullptr);
    check(type_exec.success, "oep_eqe_execute_query succeeds for a Type query");
    check(type_objects.count == 1, "Type query for Document returns exactly one object (the Manual)");
    oep_package_id_list_release(&type_objects);

    // OEP_QUERY_CATEGORY_NEIGHBORHOOD: primary_object_id neighbors.
    oep_query_request_t neighborhood_request{};
    neighborhood_request.category = OEP_QUERY_CATEGORY_NEIGHBORHOOD;
    std::snprintf(neighborhood_request.primary_object_id, sizeof(neighborhood_request.primary_object_id), "%s",
                   manual_id.c_str());

    oep_query_result_summary_t neighborhood_summary{};
    oep_package_id_list_t neighborhood_objects{};
    const oep_result_t neighborhood_exec =
        oep_eqe_execute_query(runtime, &neighborhood_request, &neighborhood_summary, &neighborhood_objects, nullptr);
    check(neighborhood_exec.success, "oep_eqe_execute_query succeeds for a Neighborhood query");
    check(neighborhood_objects.count == 1, "Neighborhood query for the Manual returns its one connected object");
    oep_package_id_list_release(&neighborhood_objects);

    // oep_eqe_query_statistics reflects the most recently executed query.
    oep_query_result_summary_t stats_summary{};
    const oep_result_t stats_result = oep_eqe_query_statistics(runtime, &stats_summary);
    check(stats_result.success, "oep_eqe_query_statistics succeeds");
    check(stats_summary.result_count == neighborhood_summary.result_count,
          "oep_eqe_query_statistics matches the most recently executed query's result_count");

    int plan_count = 0;
    int result_count = 0;
    const oep_result_t cache_info = oep_eqe_query_cache_info(runtime, &plan_count, &result_count);
    check(cache_info.success, "oep_eqe_query_cache_info succeeds");
    check(plan_count > 0, "oep_eqe_query_cache_info reports at least one cached plan after executing queries");

    const oep_result_t clear_result = oep_eqe_clear_query_cache(runtime);
    check(clear_result.success, "oep_eqe_clear_query_cache succeeds");
    int plan_count_after_clear = -1;
    int result_count_after_clear = -1;
    oep_eqe_query_cache_info(runtime, &plan_count_after_clear, &result_count_after_clear);
    check(plan_count_after_clear == 0 && result_count_after_clear == 0,
          "oep_eqe_clear_query_cache empties the plan/result cache");

    oep_runtime_destroy(runtime);
}

void test_eqe_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");

    check(!oep_eqe_plan_query(nullptr, nullptr, nullptr, nullptr, nullptr).success,
          "oep_eqe_plan_query rejects a NULL runtime handle");
    check(!oep_eqe_plan_query(runtime, nullptr, nullptr, nullptr, nullptr).success,
          "oep_eqe_plan_query rejects a NULL request");
    check(!oep_eqe_execute_query(nullptr, nullptr, nullptr, nullptr, nullptr).success,
          "oep_eqe_execute_query rejects a NULL runtime handle");
    oep_query_request_t request{};
    request.category = OEP_QUERY_CATEGORY_OBJECT;
    check(!oep_eqe_execute_query(runtime, nullptr, nullptr, nullptr, nullptr).success,
          "oep_eqe_execute_query rejects a NULL request");
    check(!oep_eqe_query_statistics(nullptr, nullptr).success,
          "oep_eqe_query_statistics rejects a NULL runtime handle");
    check(!oep_eqe_query_statistics(runtime, nullptr).success, "oep_eqe_query_statistics rejects a NULL out_stats");
    check(!oep_eqe_clear_query_cache(nullptr).success, "oep_eqe_clear_query_cache rejects a NULL runtime handle");

    check(std::string(oep_query_category_to_string(OEP_QUERY_CATEGORY_DEPENDENCY)) == "Dependency",
          "oep_query_category_to_string returns the expected name");

    oep_runtime_destroy(runtime);
}

void test_eqe_operations_require_graph_built(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "eqe-not-built");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_query_request_t request{};
    request.category = OEP_QUERY_CATEGORY_OBJECT;
    std::snprintf(request.primary_object_id, sizeof(request.primary_object_id), "%s", "does-not-matter");

    oep_query_plan_t plan{};
    check(!oep_eqe_plan_query(runtime, &request, &plan, nullptr, nullptr).success && plan.estimated_cost == 0.0,
          "oep_eqe_plan_query fails with a zeroed plan before oep_kge_build_graph");

    oep_query_result_summary_t summary{};
    check(!oep_eqe_execute_query(runtime, &request, &summary, nullptr, nullptr).success && summary.result_count == 0,
          "oep_eqe_execute_query fails with a zeroed summary before oep_kge_build_graph");

    check(!oep_eqe_query_statistics(runtime, &summary).success,
          "oep_eqe_query_statistics fails before oep_kge_build_graph");

    // oep_eqe_clear_query_cache does not itself touch the Knowledge
    // Graph (it only clears the EQE's own plan/result cache), so it
    // succeeds even before oep_kge_build_graph -- unlike every other
    // oep_eqe_* function above.
    check(oep_eqe_clear_query_cache(runtime).success,
          "oep_eqe_clear_query_cache succeeds even before oep_kge_build_graph");

    oep_runtime_destroy(runtime);
}

// Builds a minimal, valid single-condition oep_engineering_rule_t --
// AllObjects scope, one HasDescription condition -- reused by several
// rules tests below. `condition` must outlive the returned struct (it
// only stores a pointer, exactly like oep_query_filter_t::tags).
oep_engineering_rule_t build_has_description_rule(const char* rule_id, const oep_rule_condition_t* condition) {
    oep_engineering_rule_t rule{};
    std::snprintf(rule.rule_id, sizeof(rule.rule_id), "%s", rule_id);
    std::snprintf(rule.name, sizeof(rule.name), "%s", "Every object needs a description");
    std::snprintf(rule.description, sizeof(rule.description), "%s", "Structural completeness rule");
    rule.category = OEP_RULE_CATEGORY_DOCUMENTATION;
    rule.severity = OEP_RULE_SEVERITY_WARNING;
    rule.scope.kind = OEP_RULE_SCOPE_ALL_OBJECTS;
    rule.conditions = condition;
    rule.condition_count = 1;
    std::snprintf(rule.message, sizeof(rule.message), "%s", "Object is missing a description");
    std::snprintf(rule.recommendation, sizeof(rule.recommendation), "%s", "Add a description");
    return rule;
}

void test_rules_register_list_and_get(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "rules-register-list-get");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_rule_condition_t condition{};
    condition.kind = OEP_RULE_CONDITION_HAS_DESCRIPTION;
    const oep_engineering_rule_t rule = build_has_description_rule("rule-1", &condition);

    check(oep_rules_register(runtime, &rule).success, "oep_rules_register succeeds for a new rule");
    check(!oep_rules_register(runtime, &rule).success, "oep_rules_register refuses a duplicate rule_id");

    oep_rule_condition_t tag_condition{};
    tag_condition.kind = OEP_RULE_CONDITION_REQUIRES_TAG;
    tag_condition.has_tag = 1;
    std::snprintf(tag_condition.tag, sizeof(tag_condition.tag), "%s", "electrical");
    oep_engineering_rule_t rule_two = build_has_description_rule("rule-2", &tag_condition);
    check(oep_rules_register(runtime, &rule_two).success, "oep_rules_register succeeds for a second rule");

    oep_package_id_list_t all_ids{};
    check(oep_rules_list_all(runtime, &all_ids).success, "oep_rules_list_all succeeds");
    check(all_ids.count == 2, "oep_rules_list_all reports both registered rules");
    oep_package_id_list_release(&all_ids);

    oep_package_id_list_t enabled_ids{};
    check(oep_rules_list_enabled(runtime, &enabled_ids).success, "oep_rules_list_enabled succeeds");
    check(enabled_ids.count == 2, "oep_rules_list_enabled reports both rules enabled by default");
    oep_package_id_list_release(&enabled_ids);

    oep_package_id_list_t disabled_ids{};
    check(oep_rules_list_disabled(runtime, &disabled_ids).success, "oep_rules_list_disabled succeeds");
    check(disabled_ids.count == 0, "oep_rules_list_disabled reports no rules initially");
    oep_package_id_list_release(&disabled_ids);

    oep_engineering_rule_t fetched{};
    oep_rule_condition_list_t fetched_conditions{};
    int found = 0;
    check(oep_rules_get(runtime, "rule-1", &fetched, &fetched_conditions, &found).success, "oep_rules_get succeeds");
    check(found != 0, "oep_rules_get finds a registered rule");
    check(std::string(fetched.rule_id) == "rule-1", "oep_rules_get returns the correct rule_id");
    check(fetched.category == OEP_RULE_CATEGORY_DOCUMENTATION, "oep_rules_get returns the correct category");
    check(fetched.conditions == nullptr && fetched.condition_count == 0,
          "oep_rules_get leaves the scalar struct's conditions/condition_count NULL/0 (see out_conditions)");
    check(fetched_conditions.count == 1 && fetched_conditions.items[0].kind == OEP_RULE_CONDITION_HAS_DESCRIPTION,
          "oep_rules_get returns the rule's one condition via out_conditions");
    oep_rule_condition_list_release(&fetched_conditions);

    oep_engineering_rule_t missing{};
    int missing_found = 1;
    check(oep_rules_get(runtime, "no-such-rule", &missing, nullptr, &missing_found).success,
          "oep_rules_get succeeds (as an operation) for an unregistered rule_id");
    check(missing_found == 0, "oep_rules_get reports not-found for an unregistered rule_id");

    check(oep_rules_remove(runtime, "rule-2").success, "oep_rules_remove succeeds for a registered rule");
    check(!oep_rules_remove(runtime, "rule-2").success, "oep_rules_remove fails for an already-removed rule_id");

    oep_package_id_list_t after_remove{};
    oep_rules_list_all(runtime, &after_remove);
    check(after_remove.count == 1, "oep_rules_list_all reflects the removal");
    oep_package_id_list_release(&after_remove);

    oep_runtime_destroy(runtime);
}

void test_rules_enable_disable(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "rules-enable-disable");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_rule_condition_t condition{};
    condition.kind = OEP_RULE_CONDITION_HAS_DESCRIPTION;
    const oep_engineering_rule_t rule = build_has_description_rule("rule-toggle", &condition);
    check(oep_rules_register(runtime, &rule).success, "oep_rules_register succeeds");

    check(oep_rules_disable(runtime, "rule-toggle").success, "oep_rules_disable succeeds for a registered rule");
    oep_package_id_list_t enabled_after_disable{};
    oep_rules_list_enabled(runtime, &enabled_after_disable);
    check(enabled_after_disable.count == 0, "the rule no longer appears in oep_rules_list_enabled after disabling");
    oep_package_id_list_release(&enabled_after_disable);

    check(oep_rules_enable(runtime, "rule-toggle").success, "oep_rules_enable succeeds for a registered rule");
    oep_package_id_list_t enabled_after_enable{};
    oep_rules_list_enabled(runtime, &enabled_after_enable);
    check(enabled_after_enable.count == 1, "the rule reappears in oep_rules_list_enabled after re-enabling");
    oep_package_id_list_release(&enabled_after_enable);

    check(!oep_rules_enable(runtime, "no-such-rule").success,
          "oep_rules_enable fails for an unregistered rule_id");
    check(!oep_rules_disable(runtime, "no-such-rule").success,
          "oep_rules_disable fails for an unregistered rule_id");

    oep_runtime_destroy(runtime);
}

void test_rules_evaluate_and_evaluate_all(const std::filesystem::path& scratch_dir) {
    // build_populated_repository creates two objects: "Ignition Coil"
    // (Component, has a description) and "Manual" (Document, no
    // description) -- exactly one HasDescription violation.
    const std::filesystem::path root = build_populated_repository(scratch_dir / "rules-evaluate");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_rule_condition_t condition{};
    condition.kind = OEP_RULE_CONDITION_HAS_DESCRIPTION;
    const oep_engineering_rule_t rule = build_has_description_rule("rule-eval", &condition);
    check(oep_rules_register(runtime, &rule).success, "oep_rules_register succeeds");

    // Evaluating before the graph is ready fails descriptively.
    oep_rule_evaluation_result_t not_ready_result{};
    check(!oep_rules_evaluate(runtime, "rule-eval", &not_ready_result, nullptr, nullptr).success &&
              not_ready_result.status == OEP_RULE_EVAL_ERROR,
          "oep_rules_evaluate fails with a zeroed result before the graph is built");

    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_rule_evaluation_result_t result{};
    oep_package_id_list_t affected_objects{};
    oep_rule_diagnostic_list_t diagnostics{};
    const oep_result_t eval_result = oep_rules_evaluate(runtime, "rule-eval", &result, &affected_objects, &diagnostics);
    check(eval_result.success, "oep_rules_evaluate succeeds once the graph is ready");
    check(result.status == OEP_RULE_EVAL_FAILED, "the HasDescription rule fails (the Manual has no description)");
    check(affected_objects.count == 1, "exactly one object is affected (the Manual)");
    check(diagnostics.count >= 1, "at least one diagnostic is reported");
    oep_package_id_list_release(&affected_objects);
    oep_rule_diagnostic_list_release(&diagnostics);

    check(!oep_rules_evaluate(runtime, "no-such-rule", nullptr, nullptr, nullptr).success,
          "oep_rules_evaluate fails for an unregistered rule_id");

    // evaluate_rule works regardless of enabled/disabled state; disable
    // the rule and confirm evaluate_all (which only evaluates ENABLED
    // rules) then omits it while evaluate_rule still reports it.
    check(oep_rules_disable(runtime, "rule-eval").success, "oep_rules_disable succeeds");

    oep_rule_evaluation_result_t result_while_disabled{};
    check(oep_rules_evaluate(runtime, "rule-eval", &result_while_disabled, nullptr, nullptr).success &&
              result_while_disabled.status == OEP_RULE_EVAL_FAILED,
          "oep_rules_evaluate still evaluates a disabled rule when asked for it explicitly by id");

    oep_rule_evaluation_summary_list_t summaries_disabled{};
    check(oep_rules_evaluate_all(runtime, &summaries_disabled).success, "oep_rules_evaluate_all succeeds");
    check(summaries_disabled.count == 0, "oep_rules_evaluate_all omits a disabled rule");
    oep_rule_evaluation_summary_list_release(&summaries_disabled);

    check(oep_rules_enable(runtime, "rule-eval").success, "oep_rules_enable succeeds");
    oep_rule_evaluation_summary_list_t summaries_enabled{};
    check(oep_rules_evaluate_all(runtime, &summaries_enabled).success, "oep_rules_evaluate_all succeeds again");
    check(summaries_enabled.count == 1, "oep_rules_evaluate_all reports the re-enabled rule");
    check(std::string(summaries_enabled.items[0].rule_id) == "rule-eval",
          "oep_rules_evaluate_all reports the correct rule_id");
    check(summaries_enabled.items[0].status == OEP_RULE_EVAL_FAILED,
          "oep_rules_evaluate_all reports the correct status");
    check(summaries_enabled.items[0].affected_object_count == 1,
          "oep_rules_evaluate_all reports the correct affected_object_count");
    oep_rule_evaluation_summary_list_release(&summaries_enabled);

    oep_runtime_destroy(runtime);
}

void test_rules_require_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_rule_condition_t condition{};
    condition.kind = OEP_RULE_CONDITION_HAS_DESCRIPTION;
    const oep_engineering_rule_t rule = build_has_description_rule("rule-x", &condition);

    check(!oep_rules_register(runtime, &rule).success,
          "oep_rules_register fails with OEP_ERROR_INVALID_STATE without an open repository");
    check(!oep_rules_remove(runtime, "rule-x").success, "oep_rules_remove fails without an open repository");
    check(!oep_rules_enable(runtime, "rule-x").success, "oep_rules_enable fails without an open repository");
    check(!oep_rules_disable(runtime, "rule-x").success, "oep_rules_disable fails without an open repository");
    oep_package_id_list_t ids{};
    check(!oep_rules_list_all(runtime, &ids).success, "oep_rules_list_all fails without an open repository");
    oep_engineering_rule_t out_rule{};
    int found = 1;
    check(!oep_rules_get(runtime, "rule-x", &out_rule, nullptr, &found).success,
          "oep_rules_get fails without an open repository");
    check(!oep_rules_evaluate(runtime, "rule-x", nullptr, nullptr, nullptr).success,
          "oep_rules_evaluate fails without an open repository");
    oep_rule_evaluation_summary_list_t summaries{};
    check(!oep_rules_evaluate_all(runtime, &summaries).success,
          "oep_rules_evaluate_all fails without an open repository");

    oep_runtime_destroy(runtime);
}

void test_rules_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");

    check(!oep_rules_register(nullptr, nullptr).success, "oep_rules_register rejects a NULL runtime handle");
    oep_engineering_rule_t rule{};
    check(!oep_rules_register(runtime, nullptr).success, "oep_rules_register rejects a NULL rule");
    check(!oep_rules_remove(nullptr, "id").success, "oep_rules_remove rejects a NULL runtime handle");
    check(!oep_rules_remove(runtime, nullptr).success, "oep_rules_remove rejects a NULL rule_id");
    check(!oep_rules_enable(nullptr, "id").success, "oep_rules_enable rejects a NULL runtime handle");
    check(!oep_rules_enable(runtime, nullptr).success, "oep_rules_enable rejects a NULL rule_id");
    check(!oep_rules_disable(nullptr, "id").success, "oep_rules_disable rejects a NULL runtime handle");
    check(!oep_rules_disable(runtime, nullptr).success, "oep_rules_disable rejects a NULL rule_id");
    check(!oep_rules_list_all(nullptr, nullptr).success, "oep_rules_list_all rejects a NULL runtime handle");
    oep_package_id_list_t ids{};
    check(!oep_rules_list_all(runtime, nullptr).success, "oep_rules_list_all rejects a NULL out_rule_ids");
    check(!oep_rules_get(nullptr, "id", nullptr, nullptr, nullptr).success,
          "oep_rules_get rejects a NULL runtime handle");
    oep_engineering_rule_t out_rule{};
    int found = 0;
    check(!oep_rules_get(runtime, nullptr, &out_rule, nullptr, &found).success, "oep_rules_get rejects a NULL rule_id");
    check(!oep_rules_get(runtime, "id", nullptr, nullptr, &found).success, "oep_rules_get rejects a NULL out_rule");
    check(!oep_rules_get(runtime, "id", &out_rule, nullptr, nullptr).success, "oep_rules_get rejects a NULL out_found");
    check(!oep_rules_evaluate(nullptr, "id", nullptr, nullptr, nullptr).success,
          "oep_rules_evaluate rejects a NULL runtime handle");
    check(!oep_rules_evaluate(runtime, nullptr, nullptr, nullptr, nullptr).success,
          "oep_rules_evaluate rejects a NULL rule_id");
    check(!oep_rules_evaluate_all(nullptr, nullptr).success, "oep_rules_evaluate_all rejects a NULL runtime handle");
    check(!oep_rules_evaluate_all(runtime, nullptr).success, "oep_rules_evaluate_all rejects a NULL out_summaries");

    check(std::string(oep_rule_category_to_string(OEP_RULE_CATEGORY_STRUCTURAL)) == "Structural",
          "oep_rule_category_to_string returns the expected name");
    check(std::string(oep_rule_severity_to_string(OEP_RULE_SEVERITY_CRITICAL)) == "Critical",
          "oep_rule_severity_to_string returns the expected name");
    check(std::string(oep_rule_scope_kind_to_string(OEP_RULE_SCOPE_BY_DOMAIN)) == "ByDomain",
          "oep_rule_scope_kind_to_string returns the expected name");
    check(std::string(oep_rule_condition_kind_to_string(OEP_RULE_CONDITION_NO_CYCLES)) == "NoCycles",
          "oep_rule_condition_kind_to_string returns the expected name");
    check(std::string(oep_rule_evaluation_status_to_string(OEP_RULE_EVAL_NOT_APPLICABLE)) == "NotApplicable",
          "oep_rule_evaluation_status_to_string returns the expected name");

    oep_runtime_destroy(runtime);
}

void test_validation_create_session_and_validate_object(const std::filesystem::path& scratch_dir) {
    // build_populated_repository creates two objects: "Ignition Coil"
    // (Component, has a description) and "Manual" (Document, no
    // description) -- exactly one HasDescription violation.
    const std::filesystem::path root = build_populated_repository(scratch_dir / "validation-object");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_rule_condition_t condition{};
    condition.kind = OEP_RULE_CONDITION_HAS_DESCRIPTION;
    const oep_engineering_rule_t rule = build_has_description_rule("validation-rule", &condition);
    check(oep_rules_register(runtime, &rule).success, "oep_rules_register succeeds");

    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_COMPLETE, session_id, sizeof(session_id))
              .success,
          "oep_validation_create_session succeeds");
    check(std::string(session_id).size() > 0, "oep_validation_create_session returns a non-empty session_id");

    // Find the "Manual" object's id via search (its name is stable
    // across build_populated_repository's construction).
    oep_object_search_result_list_t object_results{};
    check(oep_search_objects(runtime, "Manual", &object_results).success, "oep_search_objects finds the Manual object");
    check(object_results.count >= 1, "at least one search result is returned for 'Manual'");
    const std::string manual_id = object_results.count >= 1 ? std::string(object_results.items[0].object_id) : "";
    oep_object_search_result_list_release(&object_results);

    oep_validation_report_summary_t summary{};
    oep_validation_finding_list_t findings{};
    const oep_result_t validated =
        oep_validation_validate_object(runtime, session_id, manual_id.c_str(), &summary, &findings);
    check(validated.success, "oep_validation_validate_object succeeds");
    check(summary.target_kind == OEP_VALIDATION_TARGET_SINGLE_OBJECT,
          "oep_validation_validate_object reports SingleObject target_kind");
    check(summary.error_count == 0 && summary.critical_count == 0,
          "a Warning-severity finding does not count as error/critical");
    check(summary.warning_count == 1, "the HasDescription violation is reported as exactly one warning");
    check(findings.count == 1, "oep_validation_validate_object returns exactly one finding");
    if (findings.count == 1) {
        check(std::string(findings.items[0].rule_id) == "validation-rule",
              "the finding names the violated rule_id");
        check(findings.items[0].severity == OEP_RULE_SEVERITY_WARNING, "the finding carries the rule's severity");
        check(std::string(findings.items[0].finding_id).size() > 0, "the finding has a non-empty finding_id");
    }
    oep_validation_finding_list_release(&findings);

    // oep_validation_report / oep_validation_statistics return the same
    // report for this session without re-running validation.
    oep_validation_report_summary_t report_summary{};
    oep_validation_finding_list_t report_findings{};
    check(oep_validation_report(runtime, session_id, &report_summary, &report_findings).success,
          "oep_validation_report succeeds for a validated session");
    check(report_findings.count == 1, "oep_validation_report returns the same findings as the validate_* call");
    oep_validation_finding_list_release(&report_findings);

    oep_validation_statistics_t statistics{};
    check(oep_validation_statistics(runtime, session_id, &statistics).success,
          "oep_validation_statistics succeeds for a validated session");
    check(statistics.rules_evaluated >= 1, "oep_validation_statistics reports at least one rule evaluated");

    oep_runtime_destroy(runtime);
}

void test_validation_validate_objects_context_and_package(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "validation-multi");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_rule_condition_t condition{};
    condition.kind = OEP_RULE_CONDITION_HAS_DESCRIPTION;
    const oep_engineering_rule_t rule = build_has_description_rule("validation-rule-multi", &condition);
    check(oep_rules_register(runtime, &rule).success, "oep_rules_register succeeds");
    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    char objects_session[OEP_MAX_SESSION_ID] = {0};
    check(oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_DOCUMENTATION, objects_session,
                                         sizeof(objects_session))
              .success,
          "oep_validation_create_session succeeds for validate_objects");

    oep_object_search_result_list_t object_results{};
    oep_search_objects(runtime, "Manual", &object_results);
    const std::string manual_id = object_results.count >= 1 ? std::string(object_results.items[0].object_id) : "";
    oep_object_search_result_list_release(&object_results);
    const char* ids[] = {manual_id.c_str()};

    oep_validation_report_summary_t objects_summary{};
    oep_validation_finding_list_t objects_findings{};
    check(oep_validation_validate_objects(runtime, objects_session, ids, 1, &objects_summary, &objects_findings)
              .success,
          "oep_validation_validate_objects succeeds");
    check(objects_summary.target_kind == OEP_VALIDATION_TARGET_MULTIPLE_OBJECTS,
          "oep_validation_validate_objects reports MultipleObjects target_kind");
    oep_validation_finding_list_release(&objects_findings);

    char context_session[OEP_MAX_SESSION_ID] = {0};
    oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_DOCUMENTATION, context_session,
                                   sizeof(context_session));
    oep_validation_report_summary_t context_summary{};
    oep_validation_finding_list_t context_findings{};
    check(oep_validation_validate_context(runtime, context_session, &context_summary, &context_findings).success,
          "oep_validation_validate_context succeeds");
    check(context_summary.target_kind == OEP_VALIDATION_TARGET_ENGINEERING_CONTEXT,
          "oep_validation_validate_context reports EngineeringContext target_kind");
    check(context_findings.count >= 1, "validating the whole context still finds the Manual's violation");
    oep_validation_finding_list_release(&context_findings);

    char package_session[OEP_MAX_SESSION_ID] = {0};
    oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_STRUCTURAL, package_session,
                                   sizeof(package_session));
    oep_validation_report_summary_t package_summary{};
    oep_validation_finding_list_t package_findings{};
    check(oep_validation_validate_package(runtime, package_session, "no-such-package", &package_summary,
                                           &package_findings)
              .success,
          "oep_validation_validate_package succeeds (as an operation) for a package with no members");
    check(package_summary.target_kind == OEP_VALIDATION_TARGET_PACKAGE,
          "oep_validation_validate_package reports Package target_kind");
    oep_validation_finding_list_release(&package_findings);

    oep_runtime_destroy(runtime);
}

void test_validation_requires_open_repository_and_graph_ready(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "validation-not-ready");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(!oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_COMPLETE, session_id, sizeof(session_id))
               .success,
          "oep_validation_create_session fails without an open repository");

    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_COMPLETE, session_id, sizeof(session_id))
              .success,
          "oep_validation_create_session succeeds once a repository is open (graph need not be built yet)");

    // The graph has not been loaded/built yet -- every validate_* call
    // must fail descriptively rather than silently validating nothing.
    oep_validation_report_summary_t summary{};
    oep_validation_finding_list_t findings{};
    check(!oep_validation_validate_object(runtime, session_id, "some-object", &summary, &findings).success,
          "oep_validation_validate_object fails before the graph is built");
    check(!oep_validation_validate_context(runtime, session_id, &summary, &findings).success,
          "oep_validation_validate_context fails before the graph is built");

    oep_runtime_destroy(runtime);
}

void test_validation_unknown_session_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "validation-unknown-session");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    oep_engine_load_graph(runtime, nullptr, nullptr);
    oep_kge_build_graph(runtime, nullptr, nullptr);

    oep_validation_report_summary_t summary{};
    oep_validation_finding_list_t findings{};
    check(!oep_validation_validate_context(runtime, "no-such-session", &summary, &findings).success,
          "oep_validation_validate_context fails for a session_id never created on this handle");
    check(summary.pass_count == 0 && findings.count == 0,
          "a failed validate_context call zeroes out_summary/out_findings");

    oep_validation_statistics_t statistics{};
    check(!oep_validation_statistics(runtime, "no-such-session", &statistics).success,
          "oep_validation_statistics fails for an unknown session_id");
    check(!oep_validation_report(runtime, "no-such-session", &summary, &findings).success,
          "oep_validation_report fails for an unknown session_id");

    oep_runtime_destroy(runtime);
}

void test_validation_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(!oep_validation_create_session(nullptr, OEP_VALIDATION_PROFILE_COMPLETE, session_id, sizeof(session_id))
               .success,
          "oep_validation_create_session rejects a NULL runtime handle");
    check(!oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_COMPLETE, nullptr, sizeof(session_id))
               .success,
          "oep_validation_create_session rejects a NULL out_session_id");
    check(!oep_validation_create_session(runtime, OEP_VALIDATION_PROFILE_COMPLETE, session_id, 0).success,
          "oep_validation_create_session rejects a zero buffer size");

    oep_validation_report_summary_t summary{};
    oep_validation_finding_list_t findings{};
    check(!oep_validation_validate_object(nullptr, "s", "o", &summary, &findings).success,
          "oep_validation_validate_object rejects a NULL runtime handle");
    check(!oep_validation_validate_object(runtime, nullptr, "o", &summary, &findings).success,
          "oep_validation_validate_object rejects a NULL session_id");
    check(!oep_validation_validate_object(runtime, "s", nullptr, &summary, &findings).success,
          "oep_validation_validate_object rejects a NULL object_id");

    check(!oep_validation_validate_objects(nullptr, "s", nullptr, 0, &summary, &findings).success,
          "oep_validation_validate_objects rejects a NULL runtime handle");
    check(!oep_validation_validate_objects(runtime, "s", nullptr, 1, &summary, &findings).success,
          "oep_validation_validate_objects rejects a NULL object_ids with a nonzero count");
    check(!oep_validation_validate_objects(runtime, "s", nullptr, -1, &summary, &findings).success,
          "oep_validation_validate_objects rejects a negative object_id_count");

    check(!oep_validation_validate_context(nullptr, "s", &summary, &findings).success,
          "oep_validation_validate_context rejects a NULL runtime handle");
    check(!oep_validation_validate_context(runtime, nullptr, &summary, &findings).success,
          "oep_validation_validate_context rejects a NULL session_id");

    check(!oep_validation_validate_package(nullptr, "s", "p", &summary, &findings).success,
          "oep_validation_validate_package rejects a NULL runtime handle");
    check(!oep_validation_validate_package(runtime, "s", nullptr, &summary, &findings).success,
          "oep_validation_validate_package rejects a NULL package_id");

    check(!oep_validation_report(nullptr, "s", &summary, &findings).success,
          "oep_validation_report rejects a NULL runtime handle");
    check(!oep_validation_report(runtime, nullptr, &summary, &findings).success,
          "oep_validation_report rejects a NULL session_id");

    oep_validation_statistics_t statistics{};
    check(!oep_validation_statistics(nullptr, "s", &statistics).success,
          "oep_validation_statistics rejects a NULL runtime handle");
    check(!oep_validation_statistics(runtime, nullptr, &statistics).success,
          "oep_validation_statistics rejects a NULL session_id");
    check(!oep_validation_statistics(runtime, "s", nullptr).success,
          "oep_validation_statistics rejects a NULL out_stats");

    check(std::string(oep_validation_profile_to_string(OEP_VALIDATION_PROFILE_CONNECTIVITY)) == "Connectivity",
          "oep_validation_profile_to_string returns the expected name");

    oep_runtime_destroy(runtime);
}

void test_analysis_dependencies_and_impact(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "analysis-dep-impact");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_object_search_result_list_t object_results{};
    oep_search_objects(runtime, "Manual", &object_results);
    const std::string manual_id = object_results.count >= 1 ? std::string(object_results.items[0].object_id) : "";
    oep_object_search_result_list_release(&object_results);

    int max_depth = -1;
    oep_package_id_list_t dep_objects{};
    oep_package_id_list_t dep_rels{};
    char evidence[OEP_MAX_EVIDENCE_TEXT] = {0};
    check(oep_analysis_dependencies(runtime, manual_id.c_str(), &max_depth, &dep_objects, &dep_rels, evidence).success,
          "oep_analysis_dependencies succeeds");
    check(max_depth >= 0, "oep_analysis_dependencies reports a non-negative max_depth");
    check(std::string(evidence).size() > 0, "oep_analysis_dependencies writes non-empty evidence text");
    oep_package_id_list_release(&dep_objects);
    oep_package_id_list_release(&dep_rels);

    int impact_depth = -1;
    oep_package_id_list_t affected_objects{};
    oep_package_id_list_t affected_rels{};
    check(oep_analysis_impact(runtime, manual_id.c_str(), &impact_depth, &affected_objects, &affected_rels, nullptr)
              .success,
          "oep_analysis_impact succeeds");
    oep_package_id_list_release(&affected_objects);
    oep_package_id_list_release(&affected_rels);

    oep_runtime_destroy(runtime);
}

void test_analysis_reachability_and_root_cause(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "analysis-reach-root");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_object_search_result_list_t object_results{};
    oep_search_objects(runtime, "Manual", &object_results);
    const std::string manual_id = object_results.count >= 1 ? std::string(object_results.items[0].object_id) : "";
    oep_object_search_result_list_release(&object_results);

    int reachable = -1;
    oep_package_id_list_t path{};
    check(oep_analysis_reachability(runtime, manual_id.c_str(), manual_id.c_str(), &reachable, &path, nullptr).success,
          "oep_analysis_reachability succeeds for an object reachable from itself");
    check(reachable == 1, "an object is reachable from itself");
    oep_package_id_list_release(&path);

    oep_package_id_list_t candidates{};
    oep_package_id_list_t chain{};
    check(oep_analysis_root_cause(runtime, manual_id.c_str(), &candidates, &chain, nullptr).success,
          "oep_analysis_root_cause succeeds");
    oep_package_id_list_release(&candidates);
    oep_package_id_list_release(&chain);

    oep_runtime_destroy(runtime);
}

void test_analysis_requires_open_repository_and_graph_ready(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "analysis-not-ready");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    int max_depth = -1;
    check(!oep_analysis_dependencies(runtime, "some-object", &max_depth, nullptr, nullptr, nullptr).success,
          "oep_analysis_dependencies fails without an open repository");

    oep_runtime_open_repository(runtime, root.string().c_str());
    check(!oep_analysis_dependencies(runtime, "some-object", &max_depth, nullptr, nullptr, nullptr).success,
          "oep_analysis_dependencies fails before the graph is built");
    check(max_depth == 0, "a failed oep_analysis_dependencies call zeroes out_max_depth");

    oep_runtime_destroy(runtime);
}

void test_reasoning_create_session_execute_and_report(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "reasoning-execute");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_object_search_result_list_t object_results{};
    oep_search_objects(runtime, "Manual", &object_results);
    const std::string manual_id = object_results.count >= 1 ? std::string(object_results.items[0].object_id) : "";
    oep_object_search_result_list_release(&object_results);

    char session_id[OEP_MAX_SESSION_ID] = {0};
    const char* starting_objects[] = {manual_id.c_str()};
    check(oep_reasoning_create_session(runtime, "test objective", starting_objects, 1, session_id, sizeof(session_id))
              .success,
          "oep_reasoning_create_session succeeds");
    check(std::string(session_id).size() > 0, "oep_reasoning_create_session returns a non-empty session_id");

    oep_reasoning_summary_t summary{};
    oep_package_id_list_t conclusion_ids{};
    oep_package_id_list_t recommendation_ids{};
    check(oep_reasoning_execute(runtime, session_id, &summary, &conclusion_ids, &recommendation_ids).success,
          "oep_reasoning_execute succeeds");
    check(summary.conclusion_count == conclusion_ids.count,
          "oep_reasoning_execute's summary conclusion_count matches the conclusion_ids list length");
    check(summary.recommendation_count == recommendation_ids.count,
          "oep_reasoning_execute's summary recommendation_count matches the recommendation_ids list length");

    if (conclusion_ids.count > 0) {
        oep_conclusion_t conclusion{};
        oep_package_id_list_t supporting_evidence{};
        oep_package_id_list_t referenced_objects{};
        oep_package_id_list_t referenced_rules{};
        oep_package_id_list_t referenced_findings{};
        check(oep_reasoning_get_conclusion(runtime, session_id, conclusion_ids.items[0].id, &conclusion,
                                            &supporting_evidence, &referenced_objects, &referenced_rules,
                                            &referenced_findings)
                  .success,
              "oep_reasoning_get_conclusion succeeds for a conclusion_id from the just-executed session");
        check(std::string(conclusion.conclusion_id) == conclusion_ids.items[0].id,
              "oep_reasoning_get_conclusion returns the requested conclusion_id");
        check(supporting_evidence.count > 0, "a conclusion's supporting_evidence_ids is never empty");
        oep_package_id_list_release(&supporting_evidence);
        oep_package_id_list_release(&referenced_objects);
        oep_package_id_list_release(&referenced_rules);
        oep_package_id_list_release(&referenced_findings);
    }

    if (recommendation_ids.count > 0) {
        oep_recommendation_t recommendation{};
        oep_package_id_list_t evidence_ids{};
        check(oep_reasoning_get_recommendation(runtime, session_id, recommendation_ids.items[0].id, &recommendation,
                                                &evidence_ids)
                  .success,
              "oep_reasoning_get_recommendation succeeds for a recommendation_id from the just-executed session");
        check(std::string(recommendation.recommendation_id) == recommendation_ids.items[0].id,
              "oep_reasoning_get_recommendation returns the requested recommendation_id");
        oep_package_id_list_release(&evidence_ids);
    }

    oep_reasoning_summary_t report_summary{};
    oep_package_id_list_t report_conclusion_ids{};
    oep_package_id_list_t report_recommendation_ids{};
    check(oep_reasoning_report(runtime, session_id, &report_summary, &report_conclusion_ids, &report_recommendation_ids)
              .success,
          "oep_reasoning_report succeeds for an executed session");
    check(report_conclusion_ids.count == conclusion_ids.count,
          "oep_reasoning_report returns the same conclusion_ids as oep_reasoning_execute");
    oep_package_id_list_release(&report_conclusion_ids);
    oep_package_id_list_release(&report_recommendation_ids);

    oep_package_id_list_t rec_ids_only{};
    check(oep_reasoning_recommendations(runtime, session_id, &rec_ids_only).success,
          "oep_reasoning_recommendations succeeds for an executed session");
    check(rec_ids_only.count == recommendation_ids.count,
          "oep_reasoning_recommendations returns the same count as oep_reasoning_execute's recommendation_ids");
    oep_package_id_list_release(&rec_ids_only);

    oep_package_id_list_release(&conclusion_ids);
    oep_package_id_list_release(&recommendation_ids);

    oep_runtime_destroy(runtime);
}

void test_reasoning_unknown_session_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "reasoning-unknown-session");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    oep_engine_load_graph(runtime, nullptr, nullptr);
    oep_kge_build_graph(runtime, nullptr, nullptr);

    oep_reasoning_summary_t summary{};
    oep_package_id_list_t conclusion_ids{};
    oep_package_id_list_t recommendation_ids{};
    check(!oep_reasoning_execute(runtime, "no-such-session", &summary, &conclusion_ids, &recommendation_ids).success,
          "oep_reasoning_execute fails for a session_id never created on this handle");
    check(summary.conclusion_count == 0 && conclusion_ids.count == 0,
          "a failed oep_reasoning_execute call zeroes out_summary/out_conclusion_ids");
    check(!oep_reasoning_report(runtime, "no-such-session", &summary, &conclusion_ids, &recommendation_ids).success,
          "oep_reasoning_report fails for an unknown session_id");
    check(!oep_reasoning_recommendations(runtime, "no-such-session", &recommendation_ids).success,
          "oep_reasoning_recommendations fails for an unknown session_id");

    oep_conclusion_t conclusion{};
    check(!oep_reasoning_get_conclusion(runtime, "no-such-session", "no-such-conclusion", &conclusion, nullptr,
                                         nullptr, nullptr, nullptr)
               .success,
          "oep_reasoning_get_conclusion fails for an unknown session_id");

    oep_evidence_node_t node{};
    check(!oep_reasoning_get_evidence_node(runtime, "no-such-session", "no-such-evidence", &node).success,
          "oep_reasoning_get_evidence_node fails for an unknown session_id");

    oep_runtime_destroy(runtime);
}

void test_reasoning_and_analysis_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");

    check(!oep_analysis_dependencies(nullptr, "o", nullptr, nullptr, nullptr, nullptr).success,
          "oep_analysis_dependencies rejects a NULL runtime handle");
    check(!oep_analysis_dependencies(runtime, nullptr, nullptr, nullptr, nullptr, nullptr).success,
          "oep_analysis_dependencies rejects a NULL object_id");
    check(!oep_analysis_impact(nullptr, "o", nullptr, nullptr, nullptr, nullptr).success,
          "oep_analysis_impact rejects a NULL runtime handle");
    check(!oep_analysis_reachability(runtime, nullptr, "t", nullptr, nullptr, nullptr).success,
          "oep_analysis_reachability rejects a NULL source_id");
    check(!oep_analysis_reachability(runtime, "s", nullptr, nullptr, nullptr, nullptr).success,
          "oep_analysis_reachability rejects a NULL target_id");
    check(!oep_analysis_root_cause(runtime, nullptr, nullptr, nullptr, nullptr).success,
          "oep_analysis_root_cause rejects a NULL symptom_object_id");

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(!oep_reasoning_create_session(nullptr, "obj", nullptr, 0, session_id, sizeof(session_id)).success,
          "oep_reasoning_create_session rejects a NULL runtime handle");
    check(!oep_reasoning_create_session(runtime, nullptr, nullptr, 0, session_id, sizeof(session_id)).success,
          "oep_reasoning_create_session rejects a NULL objective");
    check(!oep_reasoning_create_session(runtime, "obj", nullptr, 0, nullptr, sizeof(session_id)).success,
          "oep_reasoning_create_session rejects a NULL out_session_id");
    check(!oep_reasoning_create_session(runtime, "obj", nullptr, 1, session_id, sizeof(session_id)).success,
          "oep_reasoning_create_session rejects a NULL starting_object_ids with a nonzero count");
    check(!oep_reasoning_create_session(runtime, "obj", nullptr, -1, session_id, sizeof(session_id)).success,
          "oep_reasoning_create_session rejects a negative starting_object_id_count");

    oep_reasoning_summary_t summary{};
    check(!oep_reasoning_execute(nullptr, "s", &summary, nullptr, nullptr).success,
          "oep_reasoning_execute rejects a NULL runtime handle");
    check(!oep_reasoning_execute(runtime, nullptr, &summary, nullptr, nullptr).success,
          "oep_reasoning_execute rejects a NULL session_id");
    check(!oep_reasoning_report(nullptr, "s", &summary, nullptr, nullptr).success,
          "oep_reasoning_report rejects a NULL runtime handle");
    check(!oep_reasoning_recommendations(nullptr, "s", nullptr).success,
          "oep_reasoning_recommendations rejects a NULL runtime handle");

    check(std::string(oep_recommendation_kind_to_string(OEP_RECOMMENDATION_SIMILAR_COMPONENT)) == "SimilarComponent",
          "oep_recommendation_kind_to_string returns the expected name");

    oep_runtime_destroy(runtime);
}

void test_eip_session_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "eip-session-lifecycle");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(oep_eip_create_session(runtime, session_id, sizeof(session_id)).success,
          "oep_eip_create_session succeeds without a built graph");
    check(std::string(session_id).size() > 0, "oep_eip_create_session returns a non-empty session_id");

    check(oep_eip_resume_session(runtime, session_id).success, "oep_eip_resume_session succeeds for a known session_id");
    check(oep_eip_switch_session(runtime, session_id).success, "oep_eip_switch_session succeeds for a known session_id");

    char cloned_session_id[OEP_MAX_SESSION_ID] = {0};
    check(oep_eip_clone_session(runtime, session_id, cloned_session_id, sizeof(cloned_session_id)).success,
          "oep_eip_clone_session succeeds for a known session_id");
    check(std::string(cloned_session_id).size() > 0, "oep_eip_clone_session returns a non-empty session_id");
    check(std::string(cloned_session_id) != std::string(session_id),
          "oep_eip_clone_session returns a session_id different from the source");

    oep_knowledge_session_summary_t summary{};
    check(oep_eip_get_session(runtime, session_id, &summary).success,
          "oep_eip_get_session succeeds for a known session_id");
    check(std::string(summary.session_id) == session_id, "oep_eip_get_session returns the requested session_id");
    check(summary.closed == 0, "a freshly created session is not closed");

    char* exported_summary = nullptr;
    std::size_t exported_length = 0;
    check(oep_eip_export_session_summary(runtime, session_id, &exported_summary, &exported_length).success,
          "oep_eip_export_session_summary succeeds for a known session_id");
    check(exported_summary != nullptr && exported_length > 0,
          "oep_eip_export_session_summary writes a non-empty summary");
    oep_string_release(&exported_summary);

    oep_package_id_list_t sessions{};
    check(oep_eip_list_sessions(runtime, &sessions).success, "oep_eip_list_sessions succeeds");
    check(sessions.count >= 2, "oep_eip_list_sessions reports at least the original and cloned sessions");
    oep_package_id_list_release(&sessions);

    check(oep_eip_close_session(runtime, session_id).success, "oep_eip_close_session succeeds for a known session_id");

    oep_knowledge_session_summary_t closed_summary{};
    check(oep_eip_get_session(runtime, session_id, &closed_summary).success,
          "oep_eip_get_session still succeeds for a closed session_id");
    check(closed_summary.closed != 0, "a closed session's summary reports closed");

    oep_runtime_destroy(runtime);
}

void test_eip_unknown_session_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "eip-unknown-session");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    oep_engine_load_graph(runtime, nullptr, nullptr);
    oep_kge_build_graph(runtime, nullptr, nullptr);

    check(!oep_eip_resume_session(runtime, "no-such-session").success,
          "oep_eip_resume_session fails for a session_id never created on this handle");
    check(!oep_eip_switch_session(runtime, "no-such-session").success,
          "oep_eip_switch_session fails for an unknown session_id");

    char cloned_session_id[OEP_MAX_SESSION_ID] = {0};
    check(!oep_eip_clone_session(runtime, "no-such-session", cloned_session_id, sizeof(cloned_session_id)).success,
          "oep_eip_clone_session fails for an unknown session_id");
    check(!oep_eip_close_session(runtime, "no-such-session").success,
          "oep_eip_close_session fails for an unknown session_id");

    oep_knowledge_session_summary_t summary{};
    check(!oep_eip_get_session(runtime, "no-such-session", &summary).success,
          "oep_eip_get_session fails for an unknown session_id");

    char* exported_summary = nullptr;
    std::size_t exported_length = 0;
    check(!oep_eip_export_session_summary(runtime, "no-such-session", &exported_summary, &exported_length).success,
          "oep_eip_export_session_summary fails for an unknown session_id");
    check(exported_summary == nullptr, "a failed oep_eip_export_session_summary leaves out_summary NULL");

    oep_workflow_result_t workflow_result{};
    oep_package_id_list_t object_ids{};
    check(!oep_eip_query(runtime, "no-such-session", OEP_QUERY_CATEGORY_OBJECT, "", &workflow_result, &object_ids)
               .success,
          "oep_eip_query fails for a session_id never created on this handle");
    check(!oep_eip_inspect(runtime, "no-such-session", OEP_INSPECTION_TARGET_CONTEXT, "", &workflow_result,
                            &object_ids)
               .success,
          "oep_eip_inspect fails for an unknown session_id");
    check(!oep_eip_validate(runtime, "no-such-session", "some-object", OEP_VALIDATION_PROFILE_COMPLETE,
                             &workflow_result, &object_ids)
               .success,
          "oep_eip_validate fails for an unknown session_id");
    check(!oep_eip_analyze(runtime, "no-such-session", "some-object", &workflow_result, &object_ids).success,
          "oep_eip_analyze fails for an unknown session_id");
    check(!oep_eip_reason(runtime, "no-such-session", "objective", nullptr, 0, &workflow_result, &object_ids).success,
          "oep_eip_reason fails for an unknown session_id");
    check(!oep_eip_recommend(runtime, "no-such-session", "some-object", &workflow_result, &object_ids).success,
          "oep_eip_recommend fails for an unknown session_id");

    oep_runtime_destroy(runtime);
}

void test_eip_workflows_require_open_repository_and_graph_ready(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "eip-not-ready");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(!oep_eip_create_session(runtime, session_id, sizeof(session_id)).success,
          "oep_eip_create_session fails without an open repository");

    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_eip_create_session(runtime, session_id, sizeof(session_id)).success,
          "oep_eip_create_session succeeds once a repository is open (graph need not be built yet)");

    // The graph has not been loaded/built yet -- every Workflow function
    // must fail descriptively rather than silently running against
    // nothing.
    oep_workflow_result_t workflow_result{};
    oep_package_id_list_t object_ids{};
    check(!oep_eip_query(runtime, session_id, OEP_QUERY_CATEGORY_OBJECT, "", &workflow_result, &object_ids).success,
          "oep_eip_query fails before the graph is built");
    check(!oep_eip_inspect(runtime, session_id, OEP_INSPECTION_TARGET_CONTEXT, "", &workflow_result, &object_ids)
               .success,
          "oep_eip_inspect fails before the graph is built");
    check(!oep_eip_validate(runtime, session_id, "some-object", OEP_VALIDATION_PROFILE_COMPLETE, &workflow_result,
                             &object_ids)
               .success,
          "oep_eip_validate fails before the graph is built");
    check(!oep_eip_analyze(runtime, session_id, "some-object", &workflow_result, &object_ids).success,
          "oep_eip_analyze fails before the graph is built");
    check(!oep_eip_reason(runtime, session_id, "objective", nullptr, 0, &workflow_result, &object_ids).success,
          "oep_eip_reason fails before the graph is built");
    check(!oep_eip_recommend(runtime, session_id, "some-object", &workflow_result, &object_ids).success,
          "oep_eip_recommend fails before the graph is built");

    // The three stateless Service Orchestrator calls have the same
    // graph-readiness precondition.
    oep_engineering_summary_report_t summary_report{};
    check(!oep_eip_engineering_summary(runtime, &summary_report).success,
          "oep_eip_engineering_summary fails before the graph is built");
    oep_engineering_health_report_t health_report{};
    check(!oep_eip_engineering_health(runtime, &health_report).success,
          "oep_eip_engineering_health fails before the graph is built");
    oep_package_id_list_t recommendation_messages{};
    check(!oep_eip_engineering_recommendations(runtime, "some-object", &recommendation_messages).success,
          "oep_eip_engineering_recommendations fails before the graph is built");

    oep_runtime_destroy(runtime);
}

void test_eip_workflows_and_service_orchestrator_succeed(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "eip-workflows-succeed");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());
    check(oep_engine_load_graph(runtime, nullptr, nullptr).success, "oep_engine_load_graph succeeds");
    check(oep_kge_build_graph(runtime, nullptr, nullptr).success, "oep_kge_build_graph succeeds");

    oep_object_search_result_list_t object_results{};
    oep_search_objects(runtime, "Manual", &object_results);
    const std::string manual_id = object_results.count >= 1 ? std::string(object_results.items[0].object_id) : "";
    oep_object_search_result_list_release(&object_results);

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(oep_eip_create_session(runtime, session_id, sizeof(session_id)).success, "oep_eip_create_session succeeds");

    oep_workflow_result_t query_result{};
    oep_package_id_list_t query_object_ids{};
    check(oep_eip_query(runtime, session_id, OEP_QUERY_CATEGORY_OBJECT, manual_id.c_str(), &query_result,
                        &query_object_ids)
              .success,
          "oep_eip_query succeeds for an executed session");
    check(query_result.kind == OEP_WORKFLOW_QUERY, "oep_eip_query's result kind is OEP_WORKFLOW_QUERY");
    check(query_result.success != 0, "oep_eip_query's workflow result reports success");
    oep_package_id_list_release(&query_object_ids);

    oep_workflow_result_t inspect_result{};
    oep_package_id_list_t inspect_object_ids{};
    check(oep_eip_inspect(runtime, session_id, OEP_INSPECTION_TARGET_CONTEXT, "", &inspect_result,
                          &inspect_object_ids)
              .success,
          "oep_eip_inspect succeeds for OEP_INSPECTION_TARGET_CONTEXT with an empty target_id");
    check(inspect_result.kind == OEP_WORKFLOW_INSPECT, "oep_eip_inspect's result kind is OEP_WORKFLOW_INSPECT");
    oep_package_id_list_release(&inspect_object_ids);

    oep_workflow_result_t validate_result{};
    oep_package_id_list_t validate_object_ids{};
    check(oep_eip_validate(runtime, session_id, manual_id.c_str(), OEP_VALIDATION_PROFILE_COMPLETE, &validate_result,
                           &validate_object_ids)
              .success,
          "oep_eip_validate succeeds for an executed session");
    check(validate_result.kind == OEP_WORKFLOW_VALIDATE, "oep_eip_validate's result kind is OEP_WORKFLOW_VALIDATE");
    oep_package_id_list_release(&validate_object_ids);

    oep_workflow_result_t analyze_result{};
    oep_package_id_list_t analyze_object_ids{};
    check(oep_eip_analyze(runtime, session_id, manual_id.c_str(), &analyze_result, &analyze_object_ids).success,
          "oep_eip_analyze succeeds for an executed session");
    check(analyze_result.kind == OEP_WORKFLOW_ANALYZE, "oep_eip_analyze's result kind is OEP_WORKFLOW_ANALYZE");
    oep_package_id_list_release(&analyze_object_ids);

    const char* starting_objects[] = {manual_id.c_str()};
    oep_workflow_result_t reason_result{};
    oep_package_id_list_t reason_object_ids{};
    check(oep_eip_reason(runtime, session_id, "investigate", starting_objects, 1, &reason_result, &reason_object_ids)
              .success,
          "oep_eip_reason succeeds for an executed session");
    check(reason_result.kind == OEP_WORKFLOW_REASON, "oep_eip_reason's result kind is OEP_WORKFLOW_REASON");
    oep_package_id_list_release(&reason_object_ids);

    oep_workflow_result_t recommend_result{};
    oep_package_id_list_t recommend_object_ids{};
    check(oep_eip_recommend(runtime, session_id, manual_id.c_str(), &recommend_result, &recommend_object_ids)
              .success,
          "oep_eip_recommend succeeds for an executed session");
    check(recommend_result.kind == OEP_WORKFLOW_RECOMMEND, "oep_eip_recommend's result kind is OEP_WORKFLOW_RECOMMEND");
    oep_package_id_list_release(&recommend_object_ids);

    // The session's history/active-set counts should now reflect the
    // five workflows just executed against it.
    oep_knowledge_session_summary_t session_summary{};
    check(oep_eip_get_session(runtime, session_id, &session_summary).success,
          "oep_eip_get_session succeeds after running every workflow");
    check(session_summary.query_history_count >= 1, "oep_eip_get_session reports at least one query in history");
    check(session_summary.validation_history_count >= 1,
          "oep_eip_get_session reports at least one validation in history");
    check(session_summary.analysis_history_count >= 1,
          "oep_eip_get_session reports at least one analysis in history");
    check(session_summary.reasoning_history_count >= 1,
          "oep_eip_get_session reports at least one reasoning run in history");

    // Stateless Service Orchestrator calls.
    oep_engineering_summary_report_t summary_report{};
    check(oep_eip_engineering_summary(runtime, &summary_report).success, "oep_eip_engineering_summary succeeds");
    check(summary_report.object_count >= 2, "oep_eip_engineering_summary reports at least the two seeded objects");
    check(std::string(summary_report.summary).size() > 0, "oep_eip_engineering_summary writes a non-empty summary");

    oep_engineering_health_report_t health_report{};
    check(oep_eip_engineering_health(runtime, &health_report).success, "oep_eip_engineering_health succeeds");
    check(std::string(health_report.summary).size() > 0, "oep_eip_engineering_health writes a non-empty summary");

    oep_package_id_list_t recommendation_messages{};
    check(oep_eip_engineering_recommendations(runtime, manual_id.c_str(), &recommendation_messages).success,
          "oep_eip_engineering_recommendations succeeds");
    oep_package_id_list_release(&recommendation_messages);

    // Runtime Metrics should now reflect this handle's activity.
    oep_runtime_metrics_t metrics{};
    check(oep_eip_runtime_metrics(runtime, &metrics).success, "oep_eip_runtime_metrics succeeds");
    check(metrics.query_count >= 1, "oep_eip_runtime_metrics reports at least one query");
    check(metrics.validation_count >= 1, "oep_eip_runtime_metrics reports at least one validation");
    check(metrics.analysis_count >= 1, "oep_eip_runtime_metrics reports at least one analysis");
    check(metrics.reasoning_count >= 1, "oep_eip_runtime_metrics reports at least one reasoning run");
    check(metrics.total_session_count >= 1, "oep_eip_runtime_metrics reports at least one total session");

    check(oep_eip_invalidate_caches(runtime).success, "oep_eip_invalidate_caches succeeds");

    check(oep_eip_cleanup(runtime).success, "oep_eip_cleanup succeeds");
    oep_package_id_list_t sessions_after_cleanup{};
    check(oep_eip_list_sessions(runtime, &sessions_after_cleanup).success,
          "oep_eip_list_sessions still succeeds after oep_eip_cleanup");
    oep_package_id_list_release(&sessions_after_cleanup);

    oep_runtime_destroy(runtime);
}

void test_eip_runtime_metrics_fresh_handle_and_invalidate_caches(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "eip-metrics-fresh-handle");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_runtime_metrics_t metrics_before_open{};
    check(!oep_eip_runtime_metrics(runtime, &metrics_before_open).success,
          "oep_eip_runtime_metrics fails without an open repository (Engineering Intelligence Platform section: "
          "\"Only valid from RepositoryOpen\")");
    check(!oep_eip_invalidate_caches(runtime).success, "oep_eip_invalidate_caches fails without an open repository");
    check(!oep_eip_cleanup(runtime).success, "oep_eip_cleanup fails without an open repository");

    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_runtime_metrics_t metrics{};
    check(oep_eip_runtime_metrics(runtime, &metrics).success,
          "oep_eip_runtime_metrics succeeds once a repository is open, even without a built graph");
    check(metrics.query_count == 0 && metrics.total_session_count == 0,
          "a freshly opened handle's Runtime Metrics are all zero");

    check(oep_eip_invalidate_caches(runtime).success,
          "oep_eip_invalidate_caches succeeds once a repository is open, even without a built graph");
    check(oep_eip_cleanup(runtime).success,
          "oep_eip_cleanup succeeds once a repository is open, even without a built graph");

    oep_runtime_destroy(runtime);
}

void test_eip_null_argument_handling() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");

    char session_id[OEP_MAX_SESSION_ID] = {0};
    check(!oep_eip_create_session(nullptr, session_id, sizeof(session_id)).success,
          "oep_eip_create_session rejects a NULL runtime handle");
    check(!oep_eip_create_session(runtime, nullptr, sizeof(session_id)).success,
          "oep_eip_create_session rejects a NULL out_session_id");
    check(!oep_eip_create_session(runtime, session_id, 0).success,
          "oep_eip_create_session rejects a zero buffer size");

    check(!oep_eip_resume_session(nullptr, "s").success, "oep_eip_resume_session rejects a NULL runtime handle");
    check(!oep_eip_resume_session(runtime, nullptr).success, "oep_eip_resume_session rejects a NULL session_id");

    check(!oep_eip_clone_session(nullptr, "s", session_id, sizeof(session_id)).success,
          "oep_eip_clone_session rejects a NULL runtime handle");
    check(!oep_eip_clone_session(runtime, nullptr, session_id, sizeof(session_id)).success,
          "oep_eip_clone_session rejects a NULL session_id");
    check(!oep_eip_clone_session(runtime, "s", nullptr, sizeof(session_id)).success,
          "oep_eip_clone_session rejects a NULL out_session_id");

    check(!oep_eip_close_session(nullptr, "s").success, "oep_eip_close_session rejects a NULL runtime handle");
    check(!oep_eip_close_session(runtime, nullptr).success, "oep_eip_close_session rejects a NULL session_id");

    check(!oep_eip_switch_session(nullptr, "s").success, "oep_eip_switch_session rejects a NULL runtime handle");
    check(!oep_eip_switch_session(runtime, nullptr).success, "oep_eip_switch_session rejects a NULL session_id");

    oep_package_id_list_t sessions{};
    check(!oep_eip_list_sessions(nullptr, &sessions).success, "oep_eip_list_sessions rejects a NULL runtime handle");
    check(!oep_eip_list_sessions(runtime, nullptr).success, "oep_eip_list_sessions rejects a NULL out_session_ids");

    oep_knowledge_session_summary_t summary{};
    check(!oep_eip_get_session(nullptr, "s", &summary).success, "oep_eip_get_session rejects a NULL runtime handle");
    check(!oep_eip_get_session(runtime, nullptr, &summary).success, "oep_eip_get_session rejects a NULL session_id");
    check(!oep_eip_get_session(runtime, "s", nullptr).success, "oep_eip_get_session rejects a NULL out_session");

    char* exported_summary = nullptr;
    std::size_t exported_length = 0;
    check(!oep_eip_export_session_summary(nullptr, "s", &exported_summary, &exported_length).success,
          "oep_eip_export_session_summary rejects a NULL runtime handle");
    check(!oep_eip_export_session_summary(runtime, nullptr, &exported_summary, &exported_length).success,
          "oep_eip_export_session_summary rejects a NULL session_id");
    check(!oep_eip_export_session_summary(runtime, "s", nullptr, &exported_length).success,
          "oep_eip_export_session_summary rejects a NULL out_summary");
    check(!oep_eip_export_session_summary(runtime, "s", &exported_summary, nullptr).success,
          "oep_eip_export_session_summary rejects a NULL out_length");

    oep_workflow_result_t workflow_result{};
    oep_package_id_list_t object_ids{};
    check(!oep_eip_query(nullptr, "s", OEP_QUERY_CATEGORY_OBJECT, "o", &workflow_result, &object_ids).success,
          "oep_eip_query rejects a NULL runtime handle");
    check(!oep_eip_query(runtime, nullptr, OEP_QUERY_CATEGORY_OBJECT, "o", &workflow_result, &object_ids).success,
          "oep_eip_query rejects a NULL session_id");
    check(!oep_eip_query(runtime, "s", OEP_QUERY_CATEGORY_OBJECT, nullptr, &workflow_result, &object_ids).success,
          "oep_eip_query rejects a NULL primary_object_id");

    check(!oep_eip_inspect(nullptr, "s", OEP_INSPECTION_TARGET_OBJECT, "o", &workflow_result, &object_ids).success,
          "oep_eip_inspect rejects a NULL runtime handle");
    check(!oep_eip_inspect(runtime, nullptr, OEP_INSPECTION_TARGET_OBJECT, "o", &workflow_result, &object_ids)
               .success,
          "oep_eip_inspect rejects a NULL session_id");
    check(!oep_eip_inspect(runtime, "s", OEP_INSPECTION_TARGET_OBJECT, nullptr, &workflow_result, &object_ids)
               .success,
          "oep_eip_inspect rejects a NULL target_id");

    check(!oep_eip_validate(nullptr, "s", "o", OEP_VALIDATION_PROFILE_COMPLETE, &workflow_result, &object_ids)
               .success,
          "oep_eip_validate rejects a NULL runtime handle");
    check(!oep_eip_validate(runtime, nullptr, "o", OEP_VALIDATION_PROFILE_COMPLETE, &workflow_result, &object_ids)
               .success,
          "oep_eip_validate rejects a NULL session_id");
    check(!oep_eip_validate(runtime, "s", nullptr, OEP_VALIDATION_PROFILE_COMPLETE, &workflow_result, &object_ids)
               .success,
          "oep_eip_validate rejects a NULL object_id");

    check(!oep_eip_analyze(nullptr, "s", "o", &workflow_result, &object_ids).success,
          "oep_eip_analyze rejects a NULL runtime handle");
    check(!oep_eip_analyze(runtime, nullptr, "o", &workflow_result, &object_ids).success,
          "oep_eip_analyze rejects a NULL session_id");
    check(!oep_eip_analyze(runtime, "s", nullptr, &workflow_result, &object_ids).success,
          "oep_eip_analyze rejects a NULL object_id");

    check(!oep_eip_reason(nullptr, "s", "obj", nullptr, 0, &workflow_result, &object_ids).success,
          "oep_eip_reason rejects a NULL runtime handle");
    check(!oep_eip_reason(runtime, nullptr, "obj", nullptr, 0, &workflow_result, &object_ids).success,
          "oep_eip_reason rejects a NULL session_id");
    check(!oep_eip_reason(runtime, "s", nullptr, nullptr, 0, &workflow_result, &object_ids).success,
          "oep_eip_reason rejects a NULL objective");
    check(!oep_eip_reason(runtime, "s", "obj", nullptr, 1, &workflow_result, &object_ids).success,
          "oep_eip_reason rejects a NULL starting_object_ids with a nonzero count");

    check(!oep_eip_recommend(nullptr, "s", "o", &workflow_result, &object_ids).success,
          "oep_eip_recommend rejects a NULL runtime handle");
    check(!oep_eip_recommend(runtime, nullptr, "o", &workflow_result, &object_ids).success,
          "oep_eip_recommend rejects a NULL session_id");
    check(!oep_eip_recommend(runtime, "s", nullptr, &workflow_result, &object_ids).success,
          "oep_eip_recommend rejects a NULL object_id");

    oep_engineering_summary_report_t summary_report{};
    check(!oep_eip_engineering_summary(nullptr, &summary_report).success,
          "oep_eip_engineering_summary rejects a NULL runtime handle");
    check(!oep_eip_engineering_summary(runtime, nullptr).success,
          "oep_eip_engineering_summary rejects a NULL out_summary");

    oep_engineering_health_report_t health_report{};
    check(!oep_eip_engineering_health(nullptr, &health_report).success,
          "oep_eip_engineering_health rejects a NULL runtime handle");
    check(!oep_eip_engineering_health(runtime, nullptr).success,
          "oep_eip_engineering_health rejects a NULL out_health");

    oep_package_id_list_t recommendation_messages{};
    check(!oep_eip_engineering_recommendations(nullptr, "o", &recommendation_messages).success,
          "oep_eip_engineering_recommendations rejects a NULL runtime handle");
    check(!oep_eip_engineering_recommendations(runtime, nullptr, &recommendation_messages).success,
          "oep_eip_engineering_recommendations rejects a NULL object_id");
    check(!oep_eip_engineering_recommendations(runtime, "o", nullptr).success,
          "oep_eip_engineering_recommendations rejects a NULL out_recommendation_messages");

    oep_runtime_metrics_t metrics{};
    check(!oep_eip_runtime_metrics(nullptr, &metrics).success, "oep_eip_runtime_metrics rejects a NULL runtime handle");
    check(!oep_eip_runtime_metrics(runtime, nullptr).success, "oep_eip_runtime_metrics rejects a NULL out_metrics");

    check(!oep_eip_invalidate_caches(nullptr).success, "oep_eip_invalidate_caches rejects a NULL runtime handle");
    check(!oep_eip_cleanup(nullptr).success, "oep_eip_cleanup rejects a NULL runtime handle");

    check(std::string(oep_workflow_kind_to_string(OEP_WORKFLOW_QUERY)) == "Query",
          "oep_workflow_kind_to_string returns the expected name");
    check(std::string(oep_inspection_target_kind_to_string(OEP_INSPECTION_TARGET_PACKAGE)) == "Package",
          "oep_inspection_target_kind_to_string returns the expected name");

    oep_runtime_destroy(runtime);
}

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_api_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_version_reporting();
    test_state_to_string_is_deterministic();
    test_error_code_and_category_strings();
    test_create_rejects_null_version();
    test_destroy_is_null_safe();
    test_null_handle_calls_return_invalid_argument();
    test_full_lifecycle(scratch_dir);
    test_open_repository_reports_not_found(scratch_dir);
    test_open_repository_rejects_null_path();
    test_repository_status_fails_without_open_repository();
    test_object_enumeration(scratch_dir);
    test_object_lookup_by_id(scratch_dir);
    test_object_enumeration_requires_open_repository();
    test_repository_statistics(scratch_dir);
    test_repository_statistics_requires_open_repository();
    test_object_type_to_string();
    test_relationship_enumeration(scratch_dir);
    test_relationship_lookup_by_id(scratch_dir);
    test_relationship_enumeration_requires_open_repository();
    test_relationship_type_to_string();
    test_match_location_to_string();
    test_search_objects(scratch_dir);
    test_search_relationships(scratch_dir);
    test_search_repository(scratch_dir);
    test_search_requires_open_repository();
    test_object_create_update_delete(scratch_dir);
    test_object_content_update_and_get(scratch_dir);
    test_object_mutation_requires_open_repository();
    test_relationship_create_update_delete(scratch_dir);
    test_transaction_commit(scratch_dir);
    test_transaction_rollback(scratch_dir);
    test_transaction_automatic_rollback_on_failure(scratch_dir);
    test_transaction_requires_open_repository();
    test_batch_create_objects(scratch_dir);
    test_batch_create_objects_rolls_back_on_failure(scratch_dir);
    test_batch_create_relationships(scratch_dir);
    test_batch_participates_in_caller_transaction(scratch_dir);
    test_destroy_closes_an_open_repository(scratch_dir);
    test_package_install_and_lifecycle_queries(scratch_dir);
    test_package_queries_require_open_repository();
    test_transaction_engine_info_and_history(scratch_dir);
    test_transaction_engine_requires_open_repository();
    test_trust_store_certificate_lifecycle(scratch_dir);
    test_package_trust_status_and_unsigned_install(scratch_dir);
    test_trust_functions_require_open_repository();
    test_resolve_dependencies_reports_missing_and_rejects_install(scratch_dir);
    test_resolve_dependencies_reports_satisfied(scratch_dir);
    test_resolve_dependencies_requires_open_repository();
    test_dependency_state_to_string_is_deterministic();
    test_uninstall_impact_and_uninstall_success(scratch_dir);
    test_uninstall_impact_blocked_by_dependent(scratch_dir);
    test_uninstall_impact_not_found(scratch_dir);
    test_update_impact_and_update_success(scratch_dir);
    test_update_impact_not_installed(scratch_dir);
    test_update_impact_breaks_dependent(scratch_dir);
    test_uninstall_and_update_require_open_repository();
    test_uninstall_and_update_null_argument_handling();
    test_event_type_includes_uninstall_and_update();
    test_merge_plan_and_execute_clean_success(scratch_dir);
    test_merge_plan_reports_conflict_and_refuses_execute(scratch_dir);
    test_merge_already_registered_refusal(scratch_dir);
    test_merge_requires_open_repository();
    test_merge_null_argument_handling();
    test_event_type_includes_merge();
    test_recent_events_reports_object_and_relationship_mutations(scratch_dir);
    test_recent_events_reports_package_install(scratch_dir);
    test_recent_events_limit_truncates(scratch_dir);
    test_recent_events_null_argument_handling();
    test_engine_load_object_and_load_graph(scratch_dir);
    test_engine_load_object_requires_open_repository();
    test_engine_null_argument_handling();
    test_engine_query_by_id_and_by_type(scratch_dir);
    test_engine_traverse_related_objects_and_dependency_graph(scratch_dir);
    test_kge_build_and_refresh_graph(scratch_dir);
    test_kge_build_requires_open_repository();
    test_kge_validate_clean_graph(scratch_dir);
    test_kge_validate_reports_cycle(scratch_dir);
    test_kge_graph_statistics(scratch_dir);
    test_kge_connected_components(scratch_dir);
    test_kge_shortest_path(scratch_dir);
    test_kge_subgraph(scratch_dir);
    test_kge_export_json_and_graphml(scratch_dir);
    test_kge_null_argument_handling();
    test_kge_operations_require_graph_built(scratch_dir);
    test_eqe_plan_and_execute_query(scratch_dir);
    test_eqe_null_argument_handling();
    test_eqe_operations_require_graph_built(scratch_dir);
    test_rules_register_list_and_get(scratch_dir);
    test_rules_enable_disable(scratch_dir);
    test_rules_evaluate_and_evaluate_all(scratch_dir);
    test_rules_require_open_repository();
    test_rules_null_argument_handling();
    test_validation_create_session_and_validate_object(scratch_dir);
    test_validation_validate_objects_context_and_package(scratch_dir);
    test_validation_requires_open_repository_and_graph_ready(scratch_dir);
    test_validation_unknown_session_id(scratch_dir);
    test_validation_null_argument_handling();
    test_analysis_dependencies_and_impact(scratch_dir);
    test_analysis_reachability_and_root_cause(scratch_dir);
    test_analysis_requires_open_repository_and_graph_ready(scratch_dir);
    test_reasoning_create_session_execute_and_report(scratch_dir);
    test_reasoning_unknown_session_id(scratch_dir);
    test_reasoning_and_analysis_null_argument_handling();
    test_eip_session_lifecycle(scratch_dir);
    test_eip_unknown_session_id(scratch_dir);
    test_eip_workflows_require_open_repository_and_graph_ready(scratch_dir);
    test_eip_workflows_and_service_orchestrator_succeed(scratch_dir);
    test_eip_runtime_metrics_fresh_handle_and_invalidate_caches(scratch_dir);
    test_eip_null_argument_handling();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All Public C API tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " Public C API test(s) failed.\n";
    return 1;
}
