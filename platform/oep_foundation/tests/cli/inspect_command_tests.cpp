#include "commands/inspect_command.hpp"
#include "commands/metrics_command.hpp"
#include "commands/summary_command.hpp"
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
    check(result.success, "generating a sample repository for inspect/summary/metrics command tests succeeds");
    return parent / name;
}

// -- inspect ---------------------------------------------------------

void test_inspect_object_defaults_to_object_type(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "inspect-object");

    oep::cli::commands::InspectCommand command;
    int exit_code = -1;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"any-object-id", "--repository", repo.string()}); });

    check(exit_code == 0, "inspect succeeds against a fresh repository with the default --type object");
    check(contains(output, "Target kind: Object"), "inspect defaults to target kind Object");
    check(contains(output, "Object IDs ("), "inspect prints an Object IDs section");
    check(contains(output, "Summary:"), "inspect prints a Summary line");
}

void test_inspect_context_ignores_target_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "inspect-context");

    oep::cli::commands::InspectCommand command;
    int exit_code = -1;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"--type", "context", "--repository", repo.string()}); });

    check(exit_code == 0, "inspect --type context succeeds without a target id");
    check(contains(output, "Target kind: Context"), "inspect --type context reports target kind Context");
}

void test_inspect_package_uses_package_target_kind(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "inspect-package");

    oep::cli::commands::InspectCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"any-package-id", "--type", "package", "--repository", repo.string()}); });

    check(exit_code == 0, "inspect --type package succeeds against a fresh repository");
    check(contains(output, "Target kind: Package"), "inspect --type package reports target kind Package");
}

void test_inspect_requires_target_id_unless_context(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "inspect-missing-target");

    oep::cli::commands::InspectCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"--repository", repo.string()}); });

    check(exit_code != 0, "inspect fails without a target id and without --type context");
    check(contains(error, "requires a target ID"), "inspect explains a target ID is required");
}

// -- summary -----------------------------------------------------------

void test_summary_prints_summary_and_health(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "summary-full");

    oep::cli::commands::SummaryCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] { exit_code = command.execute({"--repository", repo.string()}); });

    check(exit_code == 0, "summary succeeds against a fresh repository");
    check(contains(output, "Objects:"), "summary prints an Objects line");
    check(contains(output, "Health score:"), "summary prints a Health score line");
}

void test_summary_health_only_omits_summary_section(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "summary-health-only");

    oep::cli::commands::SummaryCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"--health-only", "--repository", repo.string()}); });

    check(exit_code == 0, "summary --health-only succeeds against a fresh repository");
    check(!contains(output, "Objects:"), "summary --health-only omits the engineering_summary section");
    check(contains(output, "Health score:"), "summary --health-only still prints a Health score line");
}

// -- metrics -------------------------------------------------------------

void test_metrics_prints_zeroed_counters_for_a_fresh_invocation(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "metrics-fresh");

    oep::cli::commands::MetricsCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] { exit_code = command.execute({"--repository", repo.string()}); });

    check(exit_code == 0, "metrics succeeds against a fresh repository");
    check(contains(output, "Query count: 0"), "metrics reports a zero query count in a fresh invocation");
    check(contains(output, "process-local"), "metrics documents the process-local limitation");
}

void test_metrics_rejects_unrecognized_argument(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "metrics-unrecognized-arg");

    oep::cli::commands::MetricsCommand command;
    int exit_code = -1;
    const std::string error =
        capture_stderr([&] { exit_code = command.execute({"bogus", "--repository", repo.string()}); });

    check(exit_code != 0, "metrics fails on an unrecognized positional argument");
    check(contains(error, "unrecognized argument"), "metrics explains the argument was unrecognized");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_inspect_summary_metrics_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_inspect_object_defaults_to_object_type(scratch_dir);
    test_inspect_context_ignores_target_id(scratch_dir);
    test_inspect_package_uses_package_target_kind(scratch_dir);
    test_inspect_requires_target_id_unless_context(scratch_dir);
    test_summary_prints_summary_and_health(scratch_dir);
    test_summary_health_only_omits_summary_section(scratch_dir);
    test_metrics_prints_zeroed_counters_for_a_fresh_invocation(scratch_dir);
    test_metrics_rejects_unrecognized_argument(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All inspect/summary/metrics command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " inspect/summary/metrics command test(s) failed.\n";
    return 1;
}
