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

    // uninstall
    output = capture_stdout(
        [&] { exit_code = command.execute({"uninstall", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code == 0, "package uninstall succeeds");
    check(contains(output, "com.oep.demo.cli"), "uninstall output names the uninstalled package");

    // the package is gone afterward
    std::string error_output = capture_stderr(
        [&] { exit_code = command.execute({"info", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code != 0 && contains(error_output, "not installed"),
          "package info fails for the just-uninstalled package");

    output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0 && contains(output, "No packages installed"),
          "package list no longer shows the uninstalled package");

    // uninstalling again fails
    error_output = capture_stderr(
        [&] { exit_code = command.execute({"uninstall", "com.oep.demo.cli", "--repository", repo_arg}); });
    check(exit_code != 0, "a repeat package uninstall fails");
    check(contains(error_output, "not installed"), "the repeat uninstall failure names the reason");
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
    capture_stderr([&] { exit_code = command.execute({"uninstall"}); });
    check(exit_code != 0, "package uninstall with no package id is rejected");
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
