#include "oep/runtime/foundation_runtime.hpp"

#include "oep/repository/metadata.hpp"

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
        std::filesystem::temp_directory_path() / "oep_dependency_resolution_integration_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

// A minimal, unsigned, PKG-002-valid manifest for `package_id`/`version`
// with the given raw `dependencies_json` array body (e.g.
// `{"packageId":"com.example.b","version":">=1.0.0"}`).
std::string manifest_with_dependencies(const std::string& package_id, const std::string& version,
                                        const std::string& dependencies_json) {
    return R"({"schemaVersion":"1.0","packageId":")" + package_id + R"(","version":")" + version +
           R"(","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
           R"("title":"Dependency Test Package","summary":"s","description":"d","category":"demonstration",)"
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

// `object_id_suffix` (a single hex digit) keeps every archive's
// Engineering Object ID distinct, since several archives may be
// installed into the same repository within one test.
std::filesystem::path build_archive_with_dependencies(const std::string& package_id, const std::string& version,
                                                        const std::string& dependencies_json,
                                                        const std::string& file_name, char object_id_suffix = '1') {
    const std::string object_id = std::string("aaaaaaaa-5555-4000-8000-00000000000") + object_id_suffix;
    return write_temp_archive(build_stored_zip({
                                   {"manifest/package.json", manifest_with_dependencies(package_id, version, dependencies_json)},
                                   {"fragment/objects/o.json", object_entry(object_id, "Widget")},
                               }),
                               file_name);
}

void test_package_with_no_dependencies_installs_normally(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "no_deps");
    const std::filesystem::path archive = build_archive_with_dependencies("com.example.a", "1.0.0", "", "a.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(result.success, "a package declaring no dependencies installs normally: " + result.error);

    runtime.shutdown();
}

void test_missing_required_dependency_blocks_install_before_any_transaction(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "missing_dep");
    const std::string dependencies = R"({"packageId":"com.example.missing","version":">=1.0.0"})";
    const std::filesystem::path archive =
        build_archive_with_dependencies("com.example.a", "1.0.0", dependencies, "missing-dep.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(!result.success, "an install with a missing required dependency is rejected");
    check(result.error.find("dependency resolution failed") != std::string::npos,
          "the rejection names dependency resolution as the cause");

    // Resolution runs after trust but before ANY Repository Transaction
    // begins (this Work Package's explicit requirement): nothing should
    // have been journaled.
    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    check(history.success && history.records.empty(),
          "no transaction is journaled when dependency resolution rejects an install");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.empty(), "nothing was created for a dependency-rejected install");

    const oep::runtime::RuntimeInstalledPackagesResult installed = runtime.list_installed_packages();
    check(installed.success && installed.packages.empty(), "no Repository Registry record is written");

    runtime.shutdown();
}

void test_satisfied_dependency_allows_install(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "satisfied_dep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    // Install the dependency first.
    const std::filesystem::path base =
        build_archive_with_dependencies("com.example.base", "2.0.0", "", "base.oep", '1');
    check(runtime.install_package(base).success, "installing the base dependency succeeds");

    // Now install a package that requires it, with a satisfied constraint.
    const std::string dependencies = R"({"packageId":"com.example.base","version":">=1.0.0"})";
    const std::filesystem::path dependent =
        build_archive_with_dependencies("com.example.dependent", "1.0.0", dependencies, "dependent.oep", '2');
    const oep::runtime::RuntimeInstallResult result = runtime.install_package(dependent);
    check(result.success, "a package whose dependency is already installed and satisfied installs successfully: " +
                               result.error);

    runtime.shutdown();
}

void test_version_conflict_blocks_install(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "conflict_dep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const std::filesystem::path base =
        build_archive_with_dependencies("com.example.old", "1.0.0", "", "old.oep", '1');
    check(runtime.install_package(base).success, "installing the outdated base package succeeds");

    const std::string dependencies = R"({"packageId":"com.example.old","version":">=2.0.0"})";
    const std::filesystem::path dependent =
        build_archive_with_dependencies("com.example.needsnew", "1.0.0", dependencies, "needsnew.oep", '2');
    const oep::runtime::RuntimeInstallResult result = runtime.install_package(dependent);
    check(!result.success, "an unsatisfied version constraint blocks the install");
    check(result.error.find("dependency resolution failed") != std::string::npos,
          "the rejection names dependency resolution as the cause");

    runtime.shutdown();
}

void test_missing_optional_dependency_does_not_block_install(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "optional_dep");
    const std::string dependencies = R"({"packageId":"com.example.optional-thing","optional":true})";
    const std::filesystem::path archive =
        build_archive_with_dependencies("com.example.a", "1.0.0", dependencies, "optional-dep.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(result.success, "a missing OPTIONAL dependency does not block installation: " + result.error);

    runtime.shutdown();
}

void test_circular_dependency_blocks_install(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "cycle_dep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    // Install B, which (already, per its own manifest at install time)
    // depends on A -- but A doesn't exist yet, so B's own required
    // dependency is missing at ITS install time. To construct a real
    // cycle reachable from a NEW candidate without needing multi-package
    // installation, install B with an OPTIONAL dependency on A (so B
    // installs despite A not existing yet), then attempt to install A
    // with a required dependency on B -- completing the cycle A -> B -> A.
    const std::string b_dependencies = R"({"packageId":"com.example.a","optional":true})";
    const std::filesystem::path archive_b =
        build_archive_with_dependencies("com.example.b", "1.0.0", b_dependencies, "b.oep", '1');
    check(runtime.install_package(archive_b).success, "installing B (with an optional forward reference) succeeds");

    const std::string a_dependencies = R"({"packageId":"com.example.b"})";
    const std::filesystem::path archive_a =
        build_archive_with_dependencies("com.example.a", "1.0.0", a_dependencies, "a.oep", '2');
    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive_a);
    check(!result.success, "a circular dependency (A -> B -> A) blocks installation");
    check(result.error.find("circular dependency") != std::string::npos ||
              result.error.find("dependency resolution failed") != std::string::npos,
          "the rejection mentions the circular dependency");

    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    // One transaction from installing B; none from the rejected A.
    check(history.success && history.records.size() == 1,
          "the cyclic install added no new transaction (only B's own earlier install is journaled)");

    runtime.shutdown();
}

void test_resolve_package_dependencies_is_a_dry_run(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "dry_run");
    const std::string dependencies = R"({"packageId":"com.example.missing","version":">=1.0.0"})";
    const std::filesystem::path archive =
        build_archive_with_dependencies("com.example.a", "1.0.0", dependencies, "dry-run.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeDependencyResolutionResult resolved = runtime.resolve_package_dependencies(archive);
    check(resolved.success, "resolve_package_dependencies succeeds as an operational call: " + resolved.error);
    check(resolved.report.result == oep::installer::DependencyResolutionResult::Failed,
          "the report itself reports Failed for a missing required dependency");
    check(resolved.report.missing_required == std::vector<std::string>{"com.example.missing"},
          "the report names the missing package");

    // Side-effect free: nothing was installed, and the package can still
    // legitimately fail to install afterward for the same reason.
    const oep::runtime::RuntimeInstalledPackagesResult installed = runtime.list_installed_packages();
    check(installed.success && installed.packages.empty(),
          "resolve_package_dependencies installs nothing (side-effect free, per PKG-004 §2)");

    runtime.shutdown();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_dependency_resolution_integration_runtime_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_package_with_no_dependencies_installs_normally(scratch_dir);
    test_missing_required_dependency_blocks_install_before_any_transaction(scratch_dir);
    test_satisfied_dependency_allows_install(scratch_dir);
    test_version_conflict_blocks_install(scratch_dir);
    test_missing_optional_dependency_does_not_block_install(scratch_dir);
    test_circular_dependency_blocks_install(scratch_dir);
    test_resolve_package_dependencies_is_a_dry_run(scratch_dir);

    std::filesystem::remove_all(scratch_dir);
    std::filesystem::remove_all(std::filesystem::temp_directory_path() / "oep_dependency_resolution_integration_tests");

    if (g_failures == 0) {
        std::cout << "All dependency resolution integration (FoundationRuntime) tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " dependency resolution integration test(s) failed.\n";
    return 1;
}
