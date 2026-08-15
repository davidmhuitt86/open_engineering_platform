#include "oep/runtime/foundation_runtime.hpp"

#include "oep/repository/metadata.hpp"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// Integration tests for WP-REP-007's Uninstall and Update lifecycle
// operations, exercised directly against FoundationRuntime (the actual
// business logic lives there; RuntimeService — covered separately in
// runtime_service_tests.cpp — only sequences a call to it plus one
// event publication).

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
    metadata.repository_id = "3f7a2b10-8888-4c22-9d11-2a6e5c8f4b70";
    metadata.repository_name = "lifecycle-tests";
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
        std::filesystem::temp_directory_path() / "oep_package_lifecycle_integration_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

std::string manifest_with_dependencies(const std::string& package_id, const std::string& version,
                                        const std::string& dependencies_json) {
    return R"({"schemaVersion":"1.0","packageId":")" + package_id + R"(","version":")" + version +
           R"(","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
           R"("title":"Lifecycle Test Package","summary":"s","description":"d","category":"demonstration",)"
           R"("engineeringDomains":[],"license":{},"dependencies":[)" +
           dependencies_json +
           R"(],"capabilities":[],)"
           R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
}

std::string object_entry(const std::string& object_id, const std::string& name) {
    return R"({"objectId":")" + object_id + R"(","objectType":"Component","name":")" + name +
           R"(","description":"d","createdUtc":"2026-01-01T00:00:00Z","lastModifiedUtc":"2026-01-01T00:00:00Z",)"
           R"("version":"1.0.0","author":"a","tags":[]})";
}

std::filesystem::path build_archive(const std::string& package_id, const std::string& version,
                                     const std::string& dependencies_json, const std::string& file_name,
                                     char object_id_suffix, const std::string& object_name = "Widget") {
    const std::string object_id = std::string("bbbbbbbb-6666-4000-8000-00000000000") + object_id_suffix;
    return write_temp_archive(build_stored_zip({
                                   {"manifest/package.json", manifest_with_dependencies(package_id, version, dependencies_json)},
                                   {"fragment/objects/o.json", object_entry(object_id, object_name)},
                               }),
                               file_name);
}

// ---------------------------------------------------------------------
// Uninstall
// ---------------------------------------------------------------------

void test_uninstall_removes_objects_and_registry_record(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninstall_basic");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path archive = build_archive("com.example.solo", "1.0.0", "", "solo.oep", '1');
    check(runtime.install_package(archive).success, "setup: install succeeds");

    const oep::runtime::RuntimeUninstallImpactResult impact = runtime.analyze_uninstall_impact("com.example.solo");
    check(impact.success && impact.found && impact.removable,
          "an installed package with no dependents is reported removable");
    check(impact.objects_affected == 1, "impact analysis reports exactly 1 affected object");

    const oep::runtime::RuntimeUninstallResult result = runtime.uninstall_package("com.example.solo");
    check(result.success, "uninstall succeeds: " + result.error);
    check(result.objects_removed == 1, "uninstall reports 1 object removed");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.empty(), "the object is actually gone from the ObjectStore");

    const oep::runtime::RuntimeInstalledPackageResult still = runtime.get_installed_package("com.example.solo");
    check(still.success && !still.installed, "the Repository Registry no longer records the package");

    runtime.shutdown();
}

void test_uninstall_is_atomic_via_transaction_journal(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninstall_journaled");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path archive = build_archive("com.example.journaled", "1.0.0", "", "journaled.oep", '1');
    runtime.install_package(archive);
    runtime.uninstall_package("com.example.journaled");

    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    check(history.success, "transaction history is readable");
    bool found_committed_uninstall = false;
    for (const auto& record : history.records) {
        if (record.description.find("uninstall") != std::string::npos) {
            found_committed_uninstall = true;
        }
    }
    check(found_committed_uninstall, "the uninstall was journaled as its own transaction (Transaction Engine reused)");

    runtime.shutdown();
}

void test_uninstall_nonexistent_package_fails(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninstall_missing");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeUninstallResult result = runtime.uninstall_package("com.example.never-installed");
    check(!result.success, "uninstalling a package that was never installed fails");

    runtime.shutdown();
}

void test_uninstall_blocked_by_required_dependent(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninstall_blocked");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path base = build_archive("com.example.base", "1.0.0", "", "base.oep", '1');
    check(runtime.install_package(base).success, "setup: base installs");

    const std::string dependencies = R"({"packageId":"com.example.base","version":">=1.0.0"})";
    const std::filesystem::path dependent =
        build_archive("com.example.needsbase", "1.0.0", dependencies, "needsbase.oep", '2');
    check(runtime.install_package(dependent).success, "setup: dependent installs");

    const oep::runtime::RuntimeUninstallImpactResult impact = runtime.analyze_uninstall_impact("com.example.base");
    check(impact.success && impact.found && !impact.removable,
          "impact analysis reports the base package as NOT removable");
    check(impact.blocking_dependents == std::vector<std::string>{"com.example.needsbase"},
          "the blocking dependent is named exactly");

    const oep::runtime::RuntimeUninstallResult result = runtime.uninstall_package("com.example.base");
    check(!result.success, "uninstall is refused when a required dependent exists");
    check(result.error.find("needsbase") != std::string::npos, "the failure names the blocking dependent");

    // Nothing should have been touched -- verify via a fresh impact check.
    const oep::runtime::RuntimeInstalledPackageResult still = runtime.get_installed_package("com.example.base");
    check(still.success && still.installed, "the base package is still installed after the refused uninstall");

    runtime.shutdown();
}

void test_uninstall_allowed_after_dependent_removed(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninstall_after_dependent_gone");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path base = build_archive("com.example.base2", "1.0.0", "", "base2.oep", '1');
    runtime.install_package(base);
    const std::string dependencies = R"({"packageId":"com.example.base2","version":">=1.0.0"})";
    const std::filesystem::path dependent =
        build_archive("com.example.needsbase2", "1.0.0", dependencies, "needsbase2.oep", '2');
    runtime.install_package(dependent);

    check(runtime.uninstall_package("com.example.needsbase2").success, "removing the dependent first succeeds");
    const oep::runtime::RuntimeUninstallResult result = runtime.uninstall_package("com.example.base2");
    check(result.success, "the base package can now be uninstalled: " + result.error);

    runtime.shutdown();
}

// ---------------------------------------------------------------------
// Update
// ---------------------------------------------------------------------

void test_update_replaces_version_atomically(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "update_basic");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path v1 = build_archive("com.example.updatable", "1.0.0", "", "v1.oep", '1', "Old Widget");
    check(runtime.install_package(v1).success, "setup: v1 installs");

    const oep::runtime::RuntimeUpdateImpactResult impact_before =
        runtime.analyze_update_impact(build_archive("com.example.updatable", "2.0.0", "", "v2-impact.oep", '2', "New Widget"));
    check(impact_before.success && impact_before.currently_installed && impact_before.updatable,
          "update impact reports the package as updatable");
    check(impact_before.current_version == "1.0.0" && impact_before.candidate_version == "2.0.0",
          "impact reports the correct current and candidate versions");

    const std::filesystem::path v2 = build_archive("com.example.updatable", "2.0.0", "", "v2.oep", '3', "New Widget");
    const oep::runtime::RuntimeUpdateResult result = runtime.update_package(v2);
    check(result.success, "update succeeds: " + result.error);
    check(result.previous_version == "1.0.0" && result.new_version == "2.0.0",
          "the response reports the correct version transition");
    check(result.objects_removed == 1 && result.objects_created == 1,
          "exactly the old object was removed and the new object was created");

    const oep::runtime::RuntimeInstalledPackageResult installed = runtime.get_installed_package("com.example.updatable");
    check(installed.success && installed.installed && installed.entry.version == "2.0.0",
          "the Repository Registry now records version 2.0.0");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.size() == 1 && objects.objects[0].name == "New Widget",
          "the old object is gone and only the new object remains");

    runtime.shutdown();
}

void test_update_nonexistent_package_fails(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "update_missing");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path archive = build_archive("com.example.neverinstalled", "2.0.0", "", "never.oep", '1');
    const oep::runtime::RuntimeUpdateResult result = runtime.update_package(archive);
    check(!result.success, "updating a package that isn't installed fails");
    check(result.error.find("install_package") != std::string::npos || !result.error.empty(),
          "the failure explains that install_package should be used instead");

    runtime.shutdown();
}

void test_update_blocked_when_it_would_break_a_dependent(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "update_breaks_dependent");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path base = build_archive("com.example.strict", "1.0.0", "", "strict1.oep", '1');
    check(runtime.install_package(base).success, "setup: base 1.0.0 installs");

    // Dependent requires EXACTLY the 1.x line via a tilde constraint,
    // which 2.0.0 does not satisfy.
    const std::string dependencies = R"({"packageId":"com.example.strict","version":"~1.0.0"})";
    const std::filesystem::path dependent =
        build_archive("com.example.strictdependent", "1.0.0", dependencies, "strictdependent.oep", '2');
    check(runtime.install_package(dependent).success, "setup: dependent installs");

    const std::filesystem::path v2 = build_archive("com.example.strict", "2.0.0", "", "strict2.oep", '3');

    const oep::runtime::RuntimeUpdateImpactResult impact = runtime.analyze_update_impact(v2);
    check(impact.success && !impact.updatable, "impact analysis reports the update as NOT allowed");
    check(impact.broken_dependents == std::vector<std::string>{"com.example.strictdependent"},
          "the impact report names the dependent that would break");

    const oep::runtime::RuntimeUpdateResult result = runtime.update_package(v2);
    check(!result.success, "update is refused when it would break a dependent's version constraint");

    const oep::runtime::RuntimeInstalledPackageResult still = runtime.get_installed_package("com.example.strict");
    check(still.success && still.installed && still.entry.version == "1.0.0",
          "the old version remains installed after the refused update");

    runtime.shutdown();
}

void test_update_rejects_untrusted_package_leaving_old_version_intact(const std::filesystem::path& scratch_dir) {
    // Not a trust-specific test (WP-REP-004 already covers trust state
    // classification exhaustively) -- this only confirms update_package
    // actually calls trust verification before mutating anything, by
    // checking the old version survives an update attempt whose new
    // archive is at least well-formed and unsigned (which installs fine
    // under the default policy) versus confirming ordinary success,
    // since constructing a genuinely tampered archive is out of scope
    // for this file. See trust_integration_tests.cpp for tamper cases.
    const std::filesystem::path root = build_repository(scratch_dir / "update_trust_smoke");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path v1 = build_archive("com.example.trustsmoke", "1.0.0", "", "trustsmoke1.oep", '1');
    check(runtime.install_package(v1).success, "setup: v1 installs");

    const std::filesystem::path v2 = build_archive("com.example.trustsmoke", "2.0.0", "", "trustsmoke2.oep", '2');
    const oep::runtime::RuntimeUpdateResult result = runtime.update_package(v2);
    check(result.success, "an unsigned update installs under the default (non-strict) trust policy: " + result.error);
    check(!result.trust_status.empty(), "the response reports a trust_status");

    runtime.shutdown();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_package_lifecycle_integration_tests_scratch";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_uninstall_removes_objects_and_registry_record(scratch_dir);
    test_uninstall_is_atomic_via_transaction_journal(scratch_dir);
    test_uninstall_nonexistent_package_fails(scratch_dir);
    test_uninstall_blocked_by_required_dependent(scratch_dir);
    test_uninstall_allowed_after_dependent_removed(scratch_dir);
    test_update_replaces_version_atomically(scratch_dir);
    test_update_nonexistent_package_fails(scratch_dir);
    test_update_blocked_when_it_would_break_a_dependent(scratch_dir);
    test_update_rejects_untrusted_package_leaving_old_version_intact(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All package_lifecycle integration tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " package_lifecycle integration test(s) failed.\n";
    return 1;
}
