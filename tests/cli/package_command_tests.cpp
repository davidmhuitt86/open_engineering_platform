#include "commands/package_command.hpp"
#include "generator/repository_generator.hpp"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <sstream>
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

std::string capture_stdout(const std::function<void()>& action) {
    std::ostringstream buffer;
    std::streambuf* original = std::cout.rdbuf(buffer.rdbuf());
    action();
    std::cout.rdbuf(original);
    return buffer.str();
}

std::string capture_stderr(const std::function<void()>& action) {
    std::ostringstream buffer;
    std::streambuf* original = std::cerr.rdbuf(buffer.rdbuf());
    action();
    std::cerr.rdbuf(original);
    return buffer.str();
}

bool contains(const std::string& haystack, const std::string& needle) {
    return haystack.find(needle) != std::string::npos;
}

std::filesystem::path build_repository(const std::filesystem::path& parent, const std::string& name) {
    const oep::cli::generator::GenerationResult result =
        oep::cli::generator::generate_foundation_repository(parent / name, name);
    check(result.success, "generating a sample repository for package command tests succeeds");
    return parent / name;
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

std::filesystem::path write_demo_archive(const std::filesystem::path& scratch_dir) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":"com.oep.demo.cli","version":"1.0.0",)"
        R"("publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"CLI Demo Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":["Automotive"],"license":{},"dependencies":[],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":"aaaaaaaa-2222-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"CLI Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";

    const std::filesystem::path path = scratch_dir / "cli-demo.oep";
    const std::vector<std::uint8_t> bytes = build_stored_zip({
        {"manifest/package.json", manifest},
        {"fragment/objects/a.json", object_a},
    });
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

// A minimal archive declaring exactly one dependency (WP-REP-005).
std::filesystem::path write_archive_with_dependency(const std::filesystem::path& scratch_dir,
                                                      const std::string& package_id,
                                                      const std::string& dependency_package_id,
                                                      const std::string& dependency_constraint,
                                                      const std::string& file_name) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":")" + package_id +
        R"(","version":"1.0.0","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"CLI Dependency Test Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":[],"license":{},"dependencies":[{"packageId":")" +
        dependency_package_id + R"(","version":")" + dependency_constraint +
        R"("}],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":"aaaaaaaa-7777-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"CLI Dependency Widget","description":"d",)"
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

void test_resolve_reports_missing_dependency_and_blocks_install(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "resolve-missing");
    const std::string repo_arg = repo.string();
    const std::filesystem::path archive = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.cli-needs-missing", "com.oep.demo.cli-does-not-exist", ">=1.0.0",
        "cli-needs-missing.oep");
    oep::cli::commands::PackageCommand command;

    int exit_code = 0;
    std::string output =
        capture_stdout([&] { exit_code = command.execute({"resolve", archive.string(), "--repository", repo_arg}); });
    check(exit_code != 0, "package resolve exits nonzero when a required dependency is missing");
    check(contains(output, "Failed") && contains(output, "com.oep.demo.cli-does-not-exist") &&
              contains(output, "Missing"),
          "package resolve reports the failed result and names the missing dependency");

    capture_stderr([&] { exit_code = command.execute({"install", archive.string(), "--repository", repo_arg}); });
    check(exit_code != 0, "package install independently rejects the same package for the same reason");
}

void test_resolve_reports_satisfied_dependency(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "resolve-satisfied");
    const std::string repo_arg = repo.string();
    oep::cli::commands::PackageCommand command;

    const std::filesystem::path base = write_demo_archive(scratch_dir);
    int exit_code = 1;
    capture_stdout([&] { exit_code = command.execute({"install", base.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the base package succeeds");

    const std::filesystem::path dependent = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.cli-dependent", "com.oep.demo.cli", ">=1.0.0", "cli-dependent.oep");
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"resolve", dependent.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "package resolve succeeds when the dependency is already installed and satisfied");
    check(contains(output, "Resolved") && contains(output, "Satisfied") && contains(output, "Install order"),
          "package resolve reports Resolved, Satisfied, and an install order");
}

void test_resolve_requires_an_archive_argument(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "resolve-missing-arg");
    oep::cli::commands::PackageCommand command;

    int exit_code = 0;
    const std::string error_output =
        capture_stderr([&] { exit_code = command.execute({"resolve", "--repository", repo.string()}); });
    check(exit_code != 0, "package resolve with no archive argument is rejected");
    check(contains(error_output, "requires a package archive"), "the rejection names the missing argument");
}

void test_full_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "package-lifecycle");
    const std::filesystem::path archive = write_demo_archive(scratch_dir);
    oep::cli::commands::PackageCommand command;
    const std::string repo_arg = repo.string();

    // install
    int exit_code = 1;
    std::string output = capture_stdout(
        [&] { exit_code = command.execute({"install", archive.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "package install succeeds");
    check(contains(output, "com.oep.demo.cli"), "install output names the installed package");

    // list
    output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0, "package list succeeds");
    check(contains(output, "com.oep.demo.cli") && contains(output, "OEP Demo Publisher") &&
              contains(output, "Installed"),
          "package list shows id, publisher, and runtime state from the Repository Registry");

    // info
    output = capture_stdout([&] { exit_code = command.execute({"info", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code == 0, "package info succeeds");
    check(contains(output, "CLI Demo Package") && contains(output, "Package Hash") &&
              contains(output, "Installation Path") && contains(output, "Automotive"),
          "package info shows title, hash, path, and engineering domains");

    // contents
    output = capture_stdout(
        [&] { exit_code = command.execute({"contents", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code == 0, "package contents succeeds");
    check(contains(output, "CLI Harness"), "package contents shows the installed object's live name");

    // verify
    output = capture_stdout([&] { exit_code = command.execute({"verify", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code == 0, "package verify succeeds and reports OK");
    check(contains(output, "Verification: OK"), "package verify reports OK for an intact install");

    // locate
    output = capture_stdout([&] {
        exit_code = command.execute({"locate", "aaaaaaaa-2222-4000-8000-000000000001", "--repository", repo_arg});
    });
    check(exit_code == 0, "package locate succeeds");
    check(contains(output, "com.oep.demo.cli"), "package locate resolves an object id to its package");

    // search — by object name (registry metadata does not contain it)
    output = capture_stdout([&] { exit_code = command.execute({"search", "CLI Harness", "--repository", repo_arg}); });
    check(exit_code == 0, "package search succeeds");
    check(contains(output, "com.oep.demo.cli"), "package search matches by installed object name");

    // search — no match
    output = capture_stdout([&] { exit_code = command.execute({"search", "zzz-nothing", "--repository", repo_arg}); });
    check(exit_code == 0, "a non-matching search still exits 0");
    check(contains(output, "No installed packages match"), "a non-matching search says so");
}

std::filesystem::path write_versioned_archive(const std::filesystem::path& scratch_dir, const std::string& package_id,
                                                const std::string& version, const std::string& file_name) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":")" + package_id + R"(","version":")" + version +
        R"(","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"CLI Versioned Test Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":[],"license":{},"dependencies":[],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":"aaaaaaaa-8888-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"CLI Versioned Widget","description":"d",)"
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
// name, for the Merge Engine (WP-REP-008) tests, where two archives
// declaring the SAME object_id with DIFFERENT content are needed to
// provoke an ObjectContentConflict.
std::filesystem::path write_merge_archive(const std::filesystem::path& scratch_dir, const std::string& package_id,
                                            const std::string& object_id, const std::string& object_name,
                                            const std::string& file_name) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":")" + package_id +
        R"(","version":"1.0.0","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"CLI Merge Test Package","summary":"s","description":"d","category":"demonstration",)"
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

void test_uninstall_impact_and_uninstall_succeed(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "uninstall-ok");
    const std::string repo_arg = repo.string();
    const std::filesystem::path archive = write_demo_archive(scratch_dir);
    oep::cli::commands::PackageCommand command;

    int exit_code = 1;
    capture_stdout([&] { exit_code = command.execute({"install", archive.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the package for uninstall-impact/uninstall succeeds");

    std::string output = capture_stdout([&] {
        exit_code = command.execute({"uninstall-impact", "com.oep.demo.cli", "--repository", repo_arg});
    });
    check(exit_code == 0, "package uninstall-impact exits 0 when removable");
    check(contains(output, "Found:                 yes") && contains(output, "Removable:             yes"),
          "package uninstall-impact reports found and removable");

    output = capture_stdout(
        [&] { exit_code = command.execute({"uninstall", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code == 0, "package uninstall succeeds");
    check(contains(output, "com.oep.demo.cli"), "package uninstall output names the package");

    // list should no longer show the package.
    output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0, "package list still succeeds after uninstall");
    check(!contains(output, "com.oep.demo.cli"), "the uninstalled package is no longer listed");
}

void test_uninstall_impact_blocked_by_dependent(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "uninstall-blocked");
    const std::string repo_arg = repo.string();
    oep::cli::commands::PackageCommand command;

    const std::filesystem::path base = write_demo_archive(scratch_dir);
    int exit_code = 1;
    capture_stdout([&] { exit_code = command.execute({"install", base.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the base package succeeds");

    const std::filesystem::path dependent = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.cli-uninstall-dependent", "com.oep.demo.cli", ">=1.0.0",
        "cli-uninstall-dependent.oep");
    capture_stdout([&] { exit_code = command.execute({"install", dependent.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the dependent package succeeds");

    std::string output = capture_stdout([&] {
        exit_code = command.execute({"uninstall-impact", "com.oep.demo.cli", "--repository", repo_arg});
    });
    check(exit_code != 0, "package uninstall-impact exits nonzero when blocked by a dependent");
    check(contains(output, "Removable:             no") && contains(output, "com.oep.demo.cli-uninstall-dependent"),
          "package uninstall-impact names the blocking dependent");

    capture_stderr(
        [&] { exit_code = command.execute({"uninstall", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code != 0, "package uninstall refuses when a dependent would break");
}

void test_uninstall_impact_requires_a_package_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "uninstall-missing-arg");
    oep::cli::commands::PackageCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr(
        [&] { exit_code = command.execute({"uninstall-impact", "--repository", repo.string()}); });
    check(exit_code != 0, "package uninstall-impact with no package id is rejected");
    check(contains(error_output, "requires a package id"), "the rejection names the missing argument");
}

void test_update_impact_and_update_succeed(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "update-ok");
    const std::string repo_arg = repo.string();
    oep::cli::commands::PackageCommand command;

    const std::filesystem::path v1 =
        write_versioned_archive(scratch_dir, "com.oep.demo.cli-updatable", "1.0.0", "cli-updatable-v1.oep");
    int exit_code = 1;
    capture_stdout([&] { exit_code = command.execute({"install", v1.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the base package succeeds");

    const std::filesystem::path v2 =
        write_versioned_archive(scratch_dir, "com.oep.demo.cli-updatable", "2.0.0", "cli-updatable-v2.oep");

    std::string output = capture_stdout(
        [&] { exit_code = command.execute({"update-impact", v2.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "package update-impact exits 0 when updatable");
    check(contains(output, "Current version:     1.0.0") && contains(output, "Candidate version:   2.0.0") &&
              contains(output, "Updatable:           yes"),
          "package update-impact reports the version transition and updatable verdict");

    output = capture_stdout([&] { exit_code = command.execute({"update", v2.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "package update succeeds");
    check(contains(output, "1.0.0") && contains(output, "2.0.0"), "package update output names both versions");

    output = capture_stdout(
        [&] { exit_code = command.execute({"info", "com.oep.demo.cli-updatable", "--repository", repo_arg}); });
    check(exit_code == 0, "package info succeeds after update");
    check(contains(output, "2.0.0"), "the installed version reflects the update");
}

void test_update_impact_breaks_dependent(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "update-breaks-dependent");
    const std::string repo_arg = repo.string();
    oep::cli::commands::PackageCommand command;

    const std::filesystem::path v1 =
        write_versioned_archive(scratch_dir, "com.oep.demo.cli-constrained", "1.0.0", "cli-constrained-v1.oep");
    int exit_code = 1;
    capture_stdout([&] { exit_code = command.execute({"install", v1.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the base package succeeds");

    const std::filesystem::path dependent = write_archive_with_dependency(
        scratch_dir, "com.oep.demo.cli-update-dependent", "com.oep.demo.cli-constrained", "<2.0.0",
        "cli-update-dependent.oep");
    capture_stdout([&] { exit_code = command.execute({"install", dependent.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the constrained dependent succeeds");

    const std::filesystem::path v2 =
        write_versioned_archive(scratch_dir, "com.oep.demo.cli-constrained", "2.0.0", "cli-constrained-v2.oep");

    std::string output = capture_stdout(
        [&] { exit_code = command.execute({"update-impact", v2.string(), "--repository", repo_arg}); });
    check(exit_code != 0, "package update-impact exits nonzero when it would break a dependent");
    check(contains(output, "Updatable:           no") && contains(output, "com.oep.demo.cli-update-dependent"),
          "package update-impact names the broken dependent");

    capture_stderr([&] { exit_code = command.execute({"update", v2.string(), "--repository", repo_arg}); });
    check(exit_code != 0, "package update refuses when it would break a dependent's required constraint");
}

void test_merge_plan_and_merge_succeed(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "merge-ok");
    const std::string repo_arg = repo.string();
    oep::cli::commands::PackageCommand command;

    const std::filesystem::path archive =
        write_merge_archive(scratch_dir, "com.oep.demo.cli-merge-clean", "aaaaaaaa-a111-4000-8000-000000000001",
                             "CLI Merge Widget", "cli-merge-clean.oep");

    int exit_code = 1;
    std::string output = capture_stdout(
        [&] { exit_code = command.execute({"merge-plan", archive.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "package merge-plan exits 0 when mergeable");
    check(contains(output, "com.oep.demo.cli-merge-clean") && contains(output, "Objects to create:      1") &&
              contains(output, "Conflicts:              (none)") && contains(output, "Mergeable:              yes"),
          "package merge-plan reports package id, object count, no conflicts, and mergeable verdict");

    output = capture_stdout([&] { exit_code = command.execute({"merge", archive.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "package merge succeeds");
    check(contains(output, "com.oep.demo.cli-merge-clean") && contains(output, "Objects created:       1"),
          "package merge output names the package and object count");

    output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0, "package list still succeeds after merge");
    check(contains(output, "com.oep.demo.cli-merge-clean"), "the merged package is now listed");
}

void test_merge_plan_reports_conflict_and_merge_refuses(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "merge-conflict");
    const std::string repo_arg = repo.string();
    oep::cli::commands::PackageCommand command;

    const std::filesystem::path first =
        write_merge_archive(scratch_dir, "com.oep.demo.cli-merge-first", "aaaaaaaa-a222-4000-8000-000000000001",
                             "Original Name", "cli-merge-first.oep");
    int exit_code = 1;
    capture_stdout([&] { exit_code = command.execute({"install", first.string(), "--repository", repo_arg}); });
    check(exit_code == 0, "installing the first package succeeds");

    const std::filesystem::path second =
        write_merge_archive(scratch_dir, "com.oep.demo.cli-merge-second", "aaaaaaaa-a222-4000-8000-000000000001",
                             "Conflicting Name", "cli-merge-second.oep");

    std::string output = capture_stdout(
        [&] { exit_code = command.execute({"merge-plan", second.string(), "--repository", repo_arg}); });
    check(exit_code != 0, "package merge-plan exits nonzero when a conflict is detected");
    check(contains(output, "ObjectContentConflict") && contains(output, "aaaaaaaa-a222-4000-8000-000000000001") &&
              contains(output, "Mergeable:              no"),
          "package merge-plan names the conflicting object and reports not mergeable");

    capture_stderr([&] { exit_code = command.execute({"merge", second.string(), "--repository", repo_arg}); });
    check(exit_code != 0, "package merge refuses when the plan has a conflict");
}

void test_merge_requires_an_archive_argument(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "merge-missing-arg");
    oep::cli::commands::PackageCommand command;

    int exit_code = 0;
    const std::string error_output =
        capture_stderr([&] { exit_code = command.execute({"merge", "--repository", repo.string()}); });
    check(exit_code != 0, "package merge with no archive is rejected");
    check(contains(error_output, "requires a package archive"), "the rejection names the missing argument");
}

void test_update_requires_an_archive_argument(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "update-missing-arg");
    oep::cli::commands::PackageCommand command;

    int exit_code = 0;
    const std::string error_output =
        capture_stderr([&] { exit_code = command.execute({"update", "--repository", repo.string()}); });
    check(exit_code != 0, "package update with no archive is rejected");
    check(contains(error_output, "requires a package archive"), "the rejection names the missing argument");
}

void test_info_fails_for_an_unknown_package(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "package-unknown");
    oep::cli::commands::PackageCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr(
        [&] { exit_code = command.execute({"info", "com.oep.no-such", "--repository", repo.string()}); });
    check(exit_code != 0, "package info fails for a package that is not installed");
    check(contains(error_output, "not installed"), "the failure says the package is not installed");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::PackageCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });
    check(exit_code != 0, "an unknown package subcommand is rejected");
    check(contains(error_output, "unknown"), "the rejection names the problem");
}

void test_missing_arguments_are_rejected() {
    oep::cli::commands::PackageCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "package with no subcommand is rejected");
    capture_stderr([&] { exit_code = command.execute({"install"}); });
    check(exit_code != 0, "package install with no archive is rejected");
    capture_stderr([&] { exit_code = command.execute({"info"}); });
    check(exit_code != 0, "package info with no package id is rejected");
    capture_stderr([&] { exit_code = command.execute({"locate"}); });
    check(exit_code != 0, "package locate with no entity id is rejected");
    capture_stderr([&] { exit_code = command.execute({"search"}); });
    check(exit_code != 0, "package search with no query is rejected");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_package_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_full_lifecycle(scratch_dir);
    test_resolve_reports_missing_dependency_and_blocks_install(scratch_dir);
    test_resolve_reports_satisfied_dependency(scratch_dir);
    test_resolve_requires_an_archive_argument(scratch_dir);
    test_uninstall_impact_and_uninstall_succeed(scratch_dir);
    test_uninstall_impact_blocked_by_dependent(scratch_dir);
    test_uninstall_impact_requires_a_package_id(scratch_dir);
    test_update_impact_and_update_succeed(scratch_dir);
    test_update_impact_breaks_dependent(scratch_dir);
    test_update_requires_an_archive_argument(scratch_dir);
    test_merge_plan_and_merge_succeed(scratch_dir);
    test_merge_plan_reports_conflict_and_merge_refuses(scratch_dir);
    test_merge_requires_an_archive_argument(scratch_dir);
    test_info_fails_for_an_unknown_package(scratch_dir);
    test_unknown_subcommand_is_rejected();
    test_missing_arguments_are_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All package command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " package command test(s) failed.\n";
    return 1;
}
