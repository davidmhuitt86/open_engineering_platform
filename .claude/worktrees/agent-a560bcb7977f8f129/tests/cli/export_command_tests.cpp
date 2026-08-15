#include "commands/export_command.hpp"
#include "commands/object_command.hpp"
#include "generator/repository_generator.hpp"

#include <filesystem>
#include <fstream>
#include <functional>
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
    check(result.success, "generating a sample repository for export command tests succeeds");
    return parent / name;
}

std::string read_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    std::ostringstream stream;
    stream << file.rdbuf();
    return stream.str();
}

void test_export_produces_archive_with_manifest(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "export-basic");

    oep::cli::commands::ObjectCommand object_command;
    capture_stdout([&] {
        object_command.execute({"create", "--type", "Component", "--name", "Coil", "--repository", repo.string()});
    });

    const std::filesystem::path archive_path = scratch_dir / "export-basic.json";
    oep::cli::commands::ExportCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({archive_path.string(), "--repository", repo.string()});
    });

    check(exit_code == 0, "export succeeds");
    check(contains(output, "Objects:       1"), "export reports the object count");
    check(std::filesystem::exists(archive_path), "export creates the archive file");
    check(contains(read_file(archive_path), "\"exportVersion\""), "the archive contains an export manifest");
}

void test_export_empty_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "export-empty");
    const std::filesystem::path archive_path = scratch_dir / "export-empty.json";

    oep::cli::commands::ExportCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({archive_path.string(), "--repository", repo.string()}); });

    check(exit_code == 0, "exporting an empty repository succeeds");
    check(contains(output, "Objects:       0"), "an empty repository's export reports zero objects");
}

void test_export_requires_output_file() {
    oep::cli::commands::ExportCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({}); });

    check(exit_code != 0, "export fails when no output file is given");
    check(!error_output.empty(), "export reports a descriptive error when no output file is given");
}

void test_export_fails_for_missing_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path archive_path = scratch_dir / "export-missing-repo.json";
    oep::cli::commands::ExportCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code = command.execute(
            {archive_path.string(), "--repository", (scratch_dir / "does-not-exist").string()});
    });

    check(exit_code != 0, "export fails when the repository does not exist");
    check(!error_output.empty(), "export reports a descriptive error for a missing repository");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_export_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_export_produces_archive_with_manifest(scratch_dir);
    test_export_empty_repository(scratch_dir);
    test_export_requires_output_file();
    test_export_fails_for_missing_repository(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All export command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " export command test(s) failed.\n";
    return 1;
}
