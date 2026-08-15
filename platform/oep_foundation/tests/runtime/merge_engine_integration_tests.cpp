#include "oep/runtime/foundation_runtime.hpp"

#include "oep/repository/metadata.hpp"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// Integration tests for WP-REP-008's Merge Engine, exercised directly
// against FoundationRuntime::plan_merge/execute_merge.

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
    metadata.repository_id = "4a1c9e20-7777-4d33-8e22-3b7f6d9a5c81";
    metadata.repository_name = "merge-tests";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);
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
    const std::filesystem::path path =
        std::filesystem::temp_directory_path() / "oep_merge_engine_integration_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

std::string manifest_json(const std::string& package_id, const std::string& version) {
    return R"({"schemaVersion":"1.0","packageId":")" + package_id + R"(","version":")" + version +
           R"(","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
           R"("title":"Merge Test Package","summary":"s","description":"d","category":"demonstration",)"
           R"("engineeringDomains":[],"license":{},"dependencies":[],"capabilities":[],)"
           R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
}

std::string object_entry(const std::string& object_id, const std::string& name) {
    return R"({"objectId":")" + object_id + R"(","objectType":"Component","name":")" + name +
           R"(","description":"d","createdUtc":"2026-01-01T00:00:00Z","lastModifiedUtc":"2026-01-01T00:00:00Z",)"
           R"("version":"1.0.0","author":"a","tags":[]})";
}

std::filesystem::path build_archive(const std::string& package_id, const std::string& version,
                                     const std::string& object_id, const std::string& object_name,
                                     const std::string& file_name) {
    return write_temp_archive(build_stored_zip({
                                   {"manifest/package.json", manifest_json(package_id, version)},
                                   {"fragment/objects/o.json", object_entry(object_id, object_name)},
                               }),
                               file_name);
}

const std::string kSharedObjectId = "cccccccc-7777-4000-8000-000000000001";

void test_plan_merge_is_side_effect_free(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "plan_side_effect_free");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path archive = build_archive("com.example.planned", "1.0.0", kSharedObjectId, "Widget", "planned.oep");
    const oep::runtime::RuntimeMergePlanResult plan = runtime.plan_merge(archive);
    check(plan.success && plan.mergeable, "a clean merge plan succeeds and is mergeable");
    check(plan.plan.change_set.object_changes().size() == 1, "the plan proposes creating exactly 1 object");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.empty(), "planning a merge creates nothing (side-effect free)");
    const oep::runtime::RuntimeInstalledPackagesResult installed = runtime.list_installed_packages();
    check(installed.success && installed.packages.empty(), "planning a merge records nothing in the Repository Registry");

    runtime.shutdown();
}

void test_execute_merge_applies_the_plan_atomically(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "execute_basic");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path archive = build_archive("com.example.merged", "1.0.0", kSharedObjectId, "Widget", "merged.oep");
    const oep::runtime::RuntimeMergeResult result = runtime.execute_merge(archive);
    check(result.success, "execute_merge succeeds: " + result.error);
    check(result.objects_created == 1, "1 object was created");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.size() == 1 && objects.objects[0].name == "Widget",
          "the object actually exists after merge");

    const oep::runtime::RuntimeInstalledPackageResult installed = runtime.get_installed_package("com.example.merged");
    check(installed.success && installed.installed, "the package is now recorded in the Repository Registry");
    check(installed.entry.source == "merge", "the registry entry records its source as 'merge'");

    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    bool found_merge_transaction = false;
    for (const auto& record : history.records) {
        if (record.description.find("merge") != std::string::npos) found_merge_transaction = true;
    }
    check(found_merge_transaction, "the merge was journaled as its own transaction (Transaction Engine reused)");

    runtime.shutdown();
}

void test_identical_preexisting_content_is_a_benign_no_op(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "idempotent_merge");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path first = build_archive("com.example.first", "1.0.0", kSharedObjectId, "Widget", "first.oep");
    check(runtime.execute_merge(first).success, "setup: first merge succeeds");

    // A second, DIFFERENT package that happens to declare an object with
    // the exact same id AND identical content -- this must plan cleanly
    // (no conflict), even though object_ids overlap, because content is
    // identical.
    const std::filesystem::path second = build_archive("com.example.second", "1.0.0", kSharedObjectId, "Widget", "second.oep");
    const oep::runtime::RuntimeMergePlanResult plan = runtime.plan_merge(second);
    check(plan.success && plan.mergeable, "a plan whose only overlapping object is identical in content is mergeable");
    check(plan.plan.change_set.object_changes().empty(),
          "the identical pre-existing object is treated as a no-op, not included as a Create");
    check(plan.plan.conflicts.empty(), "no conflict is reported for identical content");

    const oep::runtime::RuntimeMergeResult result = runtime.execute_merge(second);
    check(result.success, "executing the idempotent merge succeeds: " + result.error);
    check(result.objects_created == 0, "no NEW object was created, since it already existed identically");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.size() == 1, "the object store still has exactly 1 object, not 2");

    runtime.shutdown();
}

void test_conflicting_content_blocks_merge_deterministically(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "conflicting_merge");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path first = build_archive("com.example.conflictbase", "1.0.0", kSharedObjectId, "Widget A", "conflictbase.oep");
    check(runtime.execute_merge(first).success, "setup: base merge succeeds");

    // Same object id, DIFFERENT name -> content conflict.
    const std::filesystem::path conflicting =
        build_archive("com.example.conflicting", "1.0.0", kSharedObjectId, "Widget B (different!)", "conflicting.oep");

    const oep::runtime::RuntimeMergePlanResult plan1 = runtime.plan_merge(conflicting);
    const oep::runtime::RuntimeMergePlanResult plan2 = runtime.plan_merge(conflicting);
    check(plan1.success && !plan1.mergeable, "a content conflict makes the plan not mergeable");
    check(plan1.plan.conflicts.size() == 1, "exactly 1 conflict is reported");
    check(plan1.plan.conflicts[0].kind == oep::installer::MergeConflictKind::ObjectContentConflict,
          "the conflict is classified as an ObjectContentConflict");
    check(plan1.plan.conflicts[0].entity_id == plan2.plan.conflicts[0].entity_id &&
              plan1.plan.conflicts[0].kind == plan2.plan.conflicts[0].kind,
          "conflict detection is deterministic: replanning the identical input reports the identical conflict");

    const oep::runtime::RuntimeMergeResult result = runtime.execute_merge(conflicting);
    check(!result.success, "execute_merge refuses to apply a plan with unresolved conflicts");
    check(result.error.find("conflict") != std::string::npos, "the failure names conflicts as the cause");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.size() == 1 && objects.objects[0].name == "Widget A",
          "nothing changed: the original object's content is untouched after the refused merge");
    const oep::runtime::RuntimeInstalledPackageResult installed = runtime.get_installed_package("com.example.conflicting");
    check(installed.success && !installed.installed, "the conflicting package was never registered");

    runtime.shutdown();
}

void test_merge_refuses_an_already_registered_package(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "already_registered");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path archive =
        build_archive("com.example.dup", "1.0.0", "dddddddd-8888-4000-8000-000000000001", "Widget", "dup.oep");
    check(runtime.execute_merge(archive).success, "setup: first merge succeeds");

    const oep::runtime::RuntimeMergePlanResult plan = runtime.plan_merge(archive);
    check(plan.success && plan.already_registered && !plan.mergeable,
          "re-merging the same package reports already_registered and is not mergeable");

    const oep::runtime::RuntimeMergeResult result = runtime.execute_merge(archive);
    check(!result.success, "execute_merge refuses an already-registered package");
    check(result.error.find("already registered") != std::string::npos,
          "the failure explains the package is already registered");

    runtime.shutdown();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_merge_engine_integration_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_plan_merge_is_side_effect_free(scratch_dir);
    test_execute_merge_applies_the_plan_atomically(scratch_dir);
    test_identical_preexisting_content_is_a_benign_no_op(scratch_dir);
    test_conflicting_content_blocks_merge_deterministically(scratch_dir);
    test_merge_refuses_an_already_registered_package(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All merge_engine integration tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " merge_engine integration test(s) failed.\n";
    return 1;
}
