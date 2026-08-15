#include "oep/cli/command_registry.hpp"
#include "commands/help_command.hpp"
#include "commands/init_command.hpp"
#include "commands/open_command.hpp"
#include "commands/packages_command.hpp"
#include "commands/status_command.hpp"
#include "commands/validate_command.hpp"
#include "commands/version_command.hpp"
#include "generator/repository_generator.hpp"

#include <filesystem>
#include <functional>
#include <iostream>
#include <memory>
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

// Runs `action`, capturing anything it writes to std::cout, and returns
// that captured text. Used so command output can be asserted on
// directly, without spawning the built executable as a subprocess.
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
    check(result.success, "generating a sample repository for CLI tests succeeds");
    return parent / name;
}

void test_open_command_succeeds_for_a_valid_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "open-valid");
    oep::cli::commands::OpenCommand command;

    int exit_code = 0;
    const std::string output = capture_stdout([&] { exit_code = command.execute({repo.string()}); });

    check(exit_code == 0, "open succeeds for a valid repository");
    check(contains(output, "Opened repository"), "open reports the opened repository");
}

void test_open_command_requires_an_argument() {
    oep::cli::commands::OpenCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({}); });

    check(exit_code != 0, "open fails when no repository path is given");
    check(contains(error_output, "Usage:"), "open reports usage information when no argument is given");
}

void test_open_command_reports_a_descriptive_error_for_an_invalid_repository(
    const std::filesystem::path& scratch_dir) {
    oep::cli::commands::OpenCommand command;

    int exit_code = 0;
    const std::string error_output =
        capture_stderr([&] { exit_code = command.execute({(scratch_dir / "does-not-exist").string()}); });

    check(exit_code != 0, "open fails for a nonexistent repository");
    check(!error_output.empty(), "open reports a descriptive error");
    check(!contains(error_output, "terminate") && !contains(error_output, "what()"),
          "open's error message does not look like an unhandled exception or stack trace");
}

void test_validate_command_reports_healthy_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "validate-healthy");
    oep::cli::commands::ValidateCommand command;

    int exit_code = 0;
    const std::string output = capture_stdout([&] { exit_code = command.execute({repo.string()}); });

    check(exit_code == 0, "validate succeeds for a healthy repository");
    check(contains(output, "Healthy"), "validate reports a Healthy status");
    check(contains(output, "Errors: 0"), "validate reports zero errors for a healthy repository");
}

void test_validate_command_fails_for_a_missing_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path missing = scratch_dir / "validate-missing";
    oep::cli::commands::ValidateCommand command;

    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({missing.string()}); });

    check(exit_code != 0, "validate fails for a repository that does not exist");
}

void test_packages_command_reports_no_packages(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "packages-empty");
    oep::cli::commands::PackagesCommand command;

    int exit_code = 0;
    const std::string output = capture_stdout([&] { exit_code = command.execute({repo.string()}); });

    check(exit_code == 0, "packages succeeds for a repository with no packages");
    check(contains(output, "No packages discovered"), "packages reports that none were discovered");
}

void test_status_command_reports_open_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "status-open");
    oep::cli::commands::StatusCommand command;

    int exit_code = 0;
    const std::string output = capture_stdout([&] { exit_code = command.execute({repo.string()}); });

    check(exit_code == 0, "status succeeds for a valid repository");
    check(contains(output, "Foundation version:"), "status reports the Foundation version");
    check(contains(output, "Runtime state: RepositoryOpen"), "status reports RepositoryOpen while the command runs");
    check(contains(output, "Repository ID:"), "status reports the repository ID");
    check(contains(output, "Loaded packages: 0"), "status reports the loaded package count");
}

void test_status_command_reports_no_repository_gracefully(const std::filesystem::path& scratch_dir) {
    oep::cli::commands::StatusCommand command;

    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({(scratch_dir / "status-missing").string()}); });

    check(exit_code == 0, "status still succeeds as an operation when no repository can be opened");
    check(contains(output, "Repository: none"), "status reports that no repository is open");
}

void test_help_lists_every_registered_command_with_syntax_and_description() {
    oep::cli::CommandRegistry registry;
    registry.register_command(std::make_unique<oep::cli::commands::VersionCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::InitCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::OpenCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::ValidateCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::PackagesCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::StatusCommand>());
    registry.register_command(std::make_unique<oep::cli::commands::HelpCommand>(registry));

    const oep::cli::commands::HelpCommand help(registry);

    int exit_code = 0;
    const std::string output = capture_stdout([&] { exit_code = help.execute({}); });

    check(exit_code == 0, "help succeeds");
    for (const std::string& expected_name :
         {"version", "init", "open", "validate", "packages", "status", "help"}) {
        check(contains(output, expected_name), "help lists the '" + expected_name + "' command");
    }
    check(contains(output, "Syntax:"), "help includes syntax for each command");
    check(contains(output, "Description:"), "help includes a description for each command");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_cli_commands_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_open_command_succeeds_for_a_valid_repository(scratch_dir);
    test_open_command_requires_an_argument();
    test_open_command_reports_a_descriptive_error_for_an_invalid_repository(scratch_dir);
    test_validate_command_reports_healthy_repository(scratch_dir);
    test_validate_command_fails_for_a_missing_repository(scratch_dir);
    test_packages_command_reports_no_packages(scratch_dir);
    test_status_command_reports_open_repository(scratch_dir);
    test_status_command_reports_no_repository_gracefully(scratch_dir);
    test_help_lists_every_registered_command_with_syntax_and_description();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All CLI command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " CLI command test(s) failed.\n";
    return 1;
}
