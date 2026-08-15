#include "commands/evalidate_command.hpp"
#include "commands/rules_command.hpp"
#include "generator/repository_generator.hpp"

#include <filesystem>
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
    check(result.success, "generating a sample repository for evalidate command tests succeeds");
    return parent / name;
}

void test_profiles_lists_all_five_without_repository() {
    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] { exit_code = command.execute({"profiles"}); });

    check(exit_code == 0, "evalidate profiles succeeds without a repository");
    check(contains(output, "Structural"), "evalidate profiles lists Structural");
    check(contains(output, "Connectivity"), "evalidate profiles lists Connectivity");
    check(contains(output, "Documentation"), "evalidate profiles lists Documentation");
    check(contains(output, "Metadata"), "evalidate profiles lists Metadata");
    check(contains(output, "Complete"), "evalidate profiles lists Complete");
}

// Process-local, empty registry (see evalidate_command.hpp): with no
// rules registered in this same invocation, validating any object
// always reports zero rules evaluated and thus trivially passes.
void test_object_against_empty_registry_trivially_passes(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "object-empty-registry");

    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"object", "any-object-id", "--profile", "Complete", "--repository", repo.string()});
    });

    check(exit_code == 0, "evalidate object exits 0 against an empty (process-local) rule registry");
    check(contains(output, "Profile-selected rules evaluated: 0"),
          "evalidate object reports zero rules evaluated with no rules registered");
    check(contains(output, "Findings (0):"), "evalidate object reports zero findings with no rules registered");
}

void test_context_against_empty_registry_trivially_passes(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "context-empty-registry");

    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"context", "--profile", "Structural", "--repository", repo.string()});
    });

    check(exit_code == 0, "evalidate context exits 0 against an empty (process-local) rule registry");
    check(contains(output, "Pass: 0"), "evalidate context's report shows zero passes (nothing was evaluated)");
}

void test_package_against_empty_registry_trivially_passes(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "package-empty-registry");

    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    capture_stdout([&] {
        exit_code =
            command.execute({"package", "no-such-package", "--profile", "Complete", "--repository", repo.string()});
    });

    check(exit_code == 0, "evalidate package exits 0 against an empty (process-local) rule registry");
}

void test_object_rejects_unrecognized_profile(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "object-bad-profile");

    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] {
        exit_code =
            command.execute({"object", "any-id", "--profile", "NotAProfile", "--repository", repo.string()});
    });

    check(exit_code != 0, "evalidate object fails for an unrecognized --profile value");
    check(contains(error, "unrecognized --profile"), "evalidate object explains the unrecognized profile");
}

void test_object_requires_object_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "object-missing-id");

    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string error =
        capture_stderr([&] { exit_code = command.execute({"object", "--repository", repo.string()}); });

    check(exit_code != 0, "evalidate object fails without an object-id argument");
    check(contains(error, "requires an object ID"), "evalidate object explains an object ID is required");
}

void test_package_requires_package_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "package-missing-id");

    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string error =
        capture_stderr([&] { exit_code = command.execute({"package", "--repository", repo.string()}); });

    check(exit_code != 0, "evalidate package fails without a package-id argument");
    check(contains(error, "requires a package ID"), "evalidate package explains a package ID is required");
}

// Documents the honest process-local limitation: a session_id can
// never be resolved by a separate CLI invocation than the one that
// created it, because each invocation constructs a fresh
// ValidationEngine (see evalidate_command.hpp's header doc comment).
void test_report_fails_for_any_session_id_in_a_fresh_invocation(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "report-fresh-process");

    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr(
        [&] { exit_code = command.execute({"report", "some-session-id", "--repository", repo.string()}); });

    check(exit_code != 0, "evalidate report fails for any session_id in a fresh process");
    check(contains(error, "process-local"), "evalidate report documents the process-local limitation");
}

void test_report_requires_session_id() {
    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"report"}); });

    check(exit_code != 0, "evalidate report fails without a session-id argument");
    check(contains(error, "requires a session ID"), "evalidate report explains a session ID is required");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"not-a-subcommand"}); });
    check(exit_code != 0, "an unknown evalidate subcommand fails");
    check(contains(error, "unknown 'evalidate' subcommand"), "the error names the unknown subcommand");
}

void test_missing_subcommand_is_rejected() {
    oep::cli::commands::EValidateCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "a bare 'oep evalidate' with no subcommand fails");
    check(contains(error, "requires a subcommand"), "the error explains a subcommand is required");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_evalidate_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_profiles_lists_all_five_without_repository();
    test_object_against_empty_registry_trivially_passes(scratch_dir);
    test_context_against_empty_registry_trivially_passes(scratch_dir);
    test_package_against_empty_registry_trivially_passes(scratch_dir);
    test_object_rejects_unrecognized_profile(scratch_dir);
    test_object_requires_object_id(scratch_dir);
    test_package_requires_package_id(scratch_dir);
    test_report_fails_for_any_session_id_in_a_fresh_invocation(scratch_dir);
    test_report_requires_session_id();
    test_unknown_subcommand_is_rejected();
    test_missing_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All evalidate command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " evalidate command test(s) failed.\n";
    return 1;
}
