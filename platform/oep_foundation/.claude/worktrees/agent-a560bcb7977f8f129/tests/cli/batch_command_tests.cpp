#include "commands/batch_command.hpp"
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
    check(result.success, "generating a sample repository for batch command tests succeeds");
    return parent / name;
}

void write_file(const std::filesystem::path& path, const std::string& contents) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file << contents;
}

void test_batch_create_with_in_batch_relationship(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "create-success");
    const std::filesystem::path input_file = scratch_dir / "create-success.json";
    write_file(input_file, R"({
      "objects": [
        {"ref": "manual", "type": "Document", "name": "Manual", "author": "Jane"},
        {"ref": "coil", "type": "Component", "name": "Ignition Coil", "tags": ["electrical"]}
      ],
      "relationships": [
        {"source": "manual", "target": "coil", "type": "Documents", "description": "docs the coil"}
      ]
    })");

    oep::cli::commands::BatchCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"create", input_file.string(), "--repository", repo.string()}); });

    check(exit_code == 0, "batch create succeeds for a well-formed input file");
    check(contains(output, "Objects created:       2"), "batch create reports the objects created");
    check(contains(output, "Relationships created: 1"), "batch create reports the relationships created");

    oep::cli::commands::ObjectCommand list_command;
    const std::string list_output =
        capture_stdout([&] { list_command.execute({"list", "--repository", repo.string()}); });
    check(contains(list_output, "Manual") && contains(list_output, "Ignition Coil"),
          "the repository contains both batch-created objects");
}

void test_batch_validate_reports_findings_without_executing(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "validate-findings");
    const std::filesystem::path input_file = scratch_dir / "validate-findings.json";
    write_file(input_file, R"({
      "objects": [
        {"ref": "x", "type": "Component", "name": "A"},
        {"ref": "x", "type": "Component", "name": "B"}
      ]
    })");

    oep::cli::commands::BatchCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"validate", input_file.string(), "--repository", repo.string()}); });

    check(exit_code != 0, "batch validate exits non-zero when the batch has findings");
    check(contains(output, "duplicate ref"), "batch validate reports the duplicate ref finding");

    oep::cli::commands::ObjectCommand list_command;
    const std::string list_output =
        capture_stdout([&] { list_command.execute({"list", "--repository", repo.string()}); });
    check(contains(list_output, "No objects found"), "batch validate does not create anything");
}

void test_batch_validate_passes_for_valid_input(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "validate-valid");
    const std::filesystem::path input_file = scratch_dir / "validate-valid.json";
    write_file(input_file, R"({"objects": [{"ref": "a", "type": "Component", "name": "A"}]})");

    oep::cli::commands::BatchCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"validate", input_file.string(), "--repository", repo.string()}); });

    check(exit_code == 0, "batch validate succeeds for a valid batch");
    check(contains(output, "Batch is valid"), "batch validate reports validity");
}

void test_batch_delete(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "delete-success");

    oep::cli::commands::ObjectCommand object_command;
    const std::string create_output = capture_stdout([&] {
        object_command.execute({"create", "--type", "Component", "--name", "Widget", "--repository", repo.string()});
    });
    const std::size_t first_quote = create_output.find('\'');
    const std::size_t second_quote = create_output.find('\'', first_quote + 1);
    const std::string object_id = create_output.substr(first_quote + 1, second_quote - first_quote - 1);

    const std::filesystem::path input_file = scratch_dir / "delete.json";
    write_file(input_file, R"({"objectIds": [")" + object_id + R"("]})");

    oep::cli::commands::BatchCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"delete", input_file.string(), "--repository", repo.string()}); });

    check(exit_code == 0, "batch delete succeeds");
    check(contains(output, "Objects deleted:       1"), "batch delete reports the deleted object count");

    const std::string list_output =
        capture_stdout([&] { object_command.execute({"list", "--repository", repo.string()}); });
    check(contains(list_output, "No objects found"), "the object no longer exists after batch delete");
}

void test_batch_create_rejects_malformed_input(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "malformed");
    const std::filesystem::path input_file = scratch_dir / "malformed.json";
    write_file(input_file, "not json at all");

    oep::cli::commands::BatchCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr(
        [&] { exit_code = command.execute({"create", input_file.string(), "--repository", repo.string()}); });

    check(exit_code != 0, "batch create fails for malformed input");
    check(!error_output.empty(), "batch create reports a descriptive error for malformed input");
}

void test_batch_requires_subcommand() {
    oep::cli::commands::BatchCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({}); });

    check(exit_code != 0, "batch fails when no subcommand is given");
    check(!error_output.empty(), "batch reports a descriptive error when no subcommand is given");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_batch_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_batch_create_with_in_batch_relationship(scratch_dir);
    test_batch_validate_reports_findings_without_executing(scratch_dir);
    test_batch_validate_passes_for_valid_input(scratch_dir);
    test_batch_delete(scratch_dir);
    test_batch_create_rejects_malformed_input(scratch_dir);
    test_batch_requires_subcommand();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All batch command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " batch command test(s) failed.\n";
    return 1;
}
