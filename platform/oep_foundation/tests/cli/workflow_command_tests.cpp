#include "commands/workflow_command.hpp"
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
    check(result.success, "generating a sample repository for workflow command tests succeeds");
    return parent / name;
}

void test_inspect_context_runs_without_target(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-inspect-context");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"inspect", "--type", "context", "--repository", repo.string()}); });

    check(exit_code == 0, "workflow inspect --type context succeeds against a fresh repository");
    check(contains(output, "Workflow: Inspect"), "workflow inspect prints the workflow kind Inspect");
    check(contains(output, "Session:"), "workflow inspect prints the process-local session id");
}

void test_query_runs_with_target(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-query");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code =
            command.execute({"query", "--target", "any-object-id", "--category", "object", "--repository", repo.string()});
    });

    check(exit_code == 0, "workflow query succeeds against a fresh repository");
    check(contains(output, "Workflow: Query"), "workflow query prints the workflow kind Query");
    check(contains(output, "Object IDs ("), "workflow query prints an Object IDs section");
}

void test_validate_runs_with_target_and_profile(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-validate");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute(
            {"validate", "--target", "any-object-id", "--profile", "Complete", "--repository", repo.string()});
    });

    check(exit_code == 0, "workflow validate succeeds against a fresh repository");
    check(contains(output, "Workflow: Validate"), "workflow validate prints the workflow kind Validate");
}

void test_analyze_runs_with_target(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-analyze");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"analyze", "--target", "any-object-id", "--repository", repo.string()}); });

    check(exit_code == 0, "workflow analyze succeeds against a fresh repository");
    check(contains(output, "Workflow: Analyze"), "workflow analyze prints the workflow kind Analyze");
}

void test_reason_runs_with_starting_objects_and_objective(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-reason");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute(
            {"reason", "--objective", "investigate", "any-object-id", "--repository", repo.string()});
    });

    check(exit_code == 0, "workflow reason succeeds against a fresh repository");
    check(contains(output, "Workflow: Reason"), "workflow reason prints the workflow kind Reason");
}

void test_reason_requires_at_least_one_starting_object(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-reason-missing-object");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] {
        exit_code = command.execute({"reason", "--objective", "investigate", "--repository", repo.string()});
    });

    check(exit_code != 0, "workflow reason fails without at least one starting object id");
    check(contains(error, "at least one starting object ID"),
          "workflow reason explains a starting object ID is required");
}

void test_recommend_runs_with_target(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-recommend");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"recommend", "--target", "any-object-id", "--repository", repo.string()});
    });

    check(exit_code == 0, "workflow recommend succeeds against a fresh repository");
    check(contains(output, "Workflow: Recommend"), "workflow recommend prints the workflow kind Recommend");
}

void test_non_reason_subcommand_requires_target(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-missing-target");

    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string error =
        capture_stderr([&] { exit_code = command.execute({"analyze", "--repository", repo.string()}); });

    check(exit_code != 0, "workflow analyze fails without --target");
    check(contains(error, "requires --target"), "workflow analyze explains --target is required");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"not-a-subcommand"}); });
    check(exit_code != 0, "an unknown workflow subcommand fails");
    check(contains(error, "unknown 'workflow' subcommand"), "the error names the unknown subcommand");
}

void test_missing_subcommand_is_rejected() {
    oep::cli::commands::WorkflowCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "a bare 'oep workflow' with no subcommand fails");
    check(contains(error, "requires a subcommand"), "the error explains a subcommand is required");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_workflow_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_inspect_context_runs_without_target(scratch_dir);
    test_query_runs_with_target(scratch_dir);
    test_validate_runs_with_target_and_profile(scratch_dir);
    test_analyze_runs_with_target(scratch_dir);
    test_reason_runs_with_starting_objects_and_objective(scratch_dir);
    test_reason_requires_at_least_one_starting_object(scratch_dir);
    test_recommend_runs_with_target(scratch_dir);
    test_non_reason_subcommand_requires_target(scratch_dir);
    test_unknown_subcommand_is_rejected();
    test_missing_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All workflow command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " workflow command test(s) failed.\n";
    return 1;
}
