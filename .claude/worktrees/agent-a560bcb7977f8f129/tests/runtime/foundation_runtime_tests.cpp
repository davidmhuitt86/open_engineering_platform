#include "oep/runtime/foundation_runtime.hpp"

#include "oep/repository/metadata.hpp"

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

void test_initialize_requires_uninitialized_state() {
    oep::runtime::FoundationRuntime runtime("0.1.0");
    check(runtime.state() == oep::runtime::RuntimeState::Uninitialized, "a fresh Runtime starts Uninitialized");

    check(runtime.initialize().success, "initialize succeeds from Uninitialized");
    check(runtime.state() == oep::runtime::RuntimeState::Initialized, "initialize transitions to Initialized");
    check(!runtime.initialize().success, "initializing an already-initialized Runtime fails");
}

void test_open_repository_requires_initialization(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninitialized_open");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    const oep::runtime::RuntimeResult result = runtime.open_repository(root);
    check(!result.success, "open_repository fails before initialize() has been called");
    check(!result.error.empty(), "the failure includes a descriptive error");
}

void test_open_and_close_repository_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "lifecycle");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    check(runtime.initialize().success, "initialize succeeds");

    const oep::runtime::RuntimeResult opened = runtime.open_repository(root);
    check(opened.success, "open_repository succeeds for a well-formed repository");
    check(runtime.state() == oep::runtime::RuntimeState::RepositoryOpen,
          "open_repository transitions to RepositoryOpen");

    const oep::runtime::RuntimeResult closed = runtime.close_repository();
    check(closed.success, "close_repository succeeds while a repository is open");
    check(runtime.state() == oep::runtime::RuntimeState::RepositoryClosed,
          "close_repository transitions to RepositoryClosed");
}

void test_open_repository_rejects_missing_metadata(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "no_metadata";
    std::filesystem::create_directories(root);

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();

    const oep::runtime::RuntimeResult result = runtime.open_repository(root);
    check(!result.success, "open_repository fails when repository.json is missing");
    check(runtime.state() == oep::runtime::RuntimeState::Initialized,
          "a failed open_repository leaves the Runtime's state unchanged");
}

void test_cannot_open_two_repositories_simultaneously(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path first = build_repository(scratch_dir / "concurrent_first");
    const std::filesystem::path second = build_repository(scratch_dir / "concurrent_second");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    check(runtime.open_repository(first).success, "opening the first repository succeeds");

    const oep::runtime::RuntimeResult second_open = runtime.open_repository(second);
    check(!second_open.success, "opening a second repository while one is open fails");
    check(runtime.current_repository().success && runtime.current_repository().path == first,
          "the originally opened repository remains current after the rejected second open");
}

void test_reopening_after_close_succeeds(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path first = build_repository(scratch_dir / "reopen_first");
    const std::filesystem::path second = build_repository(scratch_dir / "reopen_second");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    check(runtime.open_repository(first).success, "opening the first repository succeeds");
    check(runtime.close_repository().success, "closing the first repository succeeds");
    check(runtime.open_repository(second).success, "opening a second repository after closing the first succeeds");
    check(runtime.current_repository().path == second, "the newly opened repository is now current");
}

void test_services_and_context_available_only_while_open(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "services");

    oep::runtime::FoundationRuntime runtime("0.1.0");

    check(runtime.object_store() == nullptr, "object_store is null before initialization");
    check(!runtime.current_metadata().success, "current_metadata fails before initialization");

    runtime.initialize();
    check(runtime.object_store() == nullptr, "object_store is still null after initialize but before open");

    runtime.open_repository(root);
    check(runtime.object_store() != nullptr, "object_store is available once a repository is open");
    check(runtime.relationship_store() != nullptr, "relationship_store is available once a repository is open");
    check(runtime.audit_store() != nullptr, "audit_store is available once a repository is open");
    check(runtime.search_engine() != nullptr, "search_engine is available once a repository is open");
    check(runtime.graph_engine() != nullptr, "graph_engine is available once a repository is open");
    check(runtime.validator() != nullptr, "validator is available once a repository is open");
    check(runtime.package_manager() != nullptr, "package_manager is available once a repository is open");

    const oep::runtime::RuntimeMetadataResult metadata = runtime.current_metadata();
    check(metadata.success && metadata.metadata.repository_name == "my-workshop",
          "current_metadata reports the opened repository's metadata");

    const oep::runtime::RuntimePackageSetResult packages = runtime.current_package_set();
    check(packages.success, "current_package_set succeeds for a repository with no packages installed");
    check(packages.packages.empty(), "current_package_set is empty for a repository with no packages installed");

    runtime.close_repository();
    check(runtime.object_store() == nullptr, "object_store is null again after closing the repository");
    check(!runtime.current_metadata().success, "current_metadata fails after closing the repository");
}

void test_shutdown_is_idempotent_and_closes_open_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "shutdown");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    check(runtime.shutdown().success, "shutdown succeeds while a repository is open");
    check(runtime.state() == oep::runtime::RuntimeState::Shutdown, "shutdown transitions to Shutdown");
    check(runtime.object_store() == nullptr, "services are unavailable after shutdown");

    const oep::runtime::RuntimeResult second_shutdown = runtime.shutdown();
    check(!second_shutdown.success, "shutting down an already-shut-down Runtime fails");

    const oep::runtime::RuntimeResult open_after_shutdown = runtime.open_repository(root);
    check(!open_after_shutdown.success, "opening a repository after shutdown fails");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_foundation_runtime_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_initialize_requires_uninitialized_state();
    test_open_repository_requires_initialization(scratch_dir);
    test_open_and_close_repository_lifecycle(scratch_dir);
    test_open_repository_rejects_missing_metadata(scratch_dir);
    test_cannot_open_two_repositories_simultaneously(scratch_dir);
    test_reopening_after_close_succeeds(scratch_dir);
    test_services_and_context_available_only_while_open(scratch_dir);
    test_shutdown_is_idempotent_and_closes_open_repository(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All foundation runtime tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " foundation runtime test(s) failed.\n";
    return 1;
}
