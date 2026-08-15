#include "commands/analysis_command.hpp"
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
    check(result.success, "generating a sample repository for analysis command tests succeeds");
    return parent / name;
}

void test_dependencies_and_impact_succeed(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "dependencies-impact");

    oep::cli::commands::AnalysisCommand command;
    int exit_code = -1;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"dependencies", "any-object-id", "--repository", repo.string()}); });

    check(exit_code == 0, "analysis dependencies succeeds against a fresh repository");
    check(contains(output, "Max depth:"), "analysis dependencies prints a max depth line");
    check(contains(output, "Evidence:"), "analysis dependencies prints an evidence line");

    int impact_exit = -1;
    const std::string impact_output =
        capture_stdout([&] { impact_exit = command.execute({"impact", "any-object-id", "--repository", repo.string()}); });
    check(impact_exit == 0, "analysis impact succeeds against a fresh repository");
    check(contains(impact_output, "Affected objects"), "analysis impact prints an affected-objects section");
}

// A nonexistent object id is not necessarily "reachable from itself" --
// that depends on whether AnalysisEngine treats an unknown id as a
// trivial single-node path or as simply absent from the graph. This
// test only asserts the command runs the algorithm and prints its
// verdict (exit code 0 for reachable, 1 for not), matching
// oep_analysis_reachability's own documented int/bool convention --
// it does not assume which verdict a nonexistent id produces.
void test_reachability_prints_a_verdict(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "reachability");

    oep::cli::commands::AnalysisCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"reachability", "some-id", "some-id", "--repository", repo.string()}); });

    check(exit_code == 0 || exit_code == 1, "analysis reachability exits 0 (reachable) or 1 (not reachable)");
    check(contains(output, "Reachable: "), "analysis reachability prints a Reachable: verdict line");
    check((contains(output, "Reachable: yes") && exit_code == 0) ||
              (contains(output, "Reachable: no") && exit_code == 1),
          "analysis reachability's exit code matches its printed verdict");
}

void test_root_cause_against_empty_registry(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "root-cause");

    oep::cli::commands::AnalysisCommand command;
    int exit_code = -1;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"root-cause", "any-object-id", "--repository", repo.string()}); });

    check(exit_code == 0, "analysis root-cause succeeds against a fresh repository");
    check(contains(output, "Candidate root causes"), "analysis root-cause prints a candidate-root-causes section");
    check(contains(output, "process-local"), "analysis root-cause documents the empty-registry limitation");
}

void test_dependencies_requires_object_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "dependencies-missing-id");

    oep::cli::commands::AnalysisCommand command;
    int exit_code = -1;
    const std::string error =
        capture_stderr([&] { exit_code = command.execute({"dependencies", "--repository", repo.string()}); });

    check(exit_code != 0, "analysis dependencies fails without an object-id argument");
    check(contains(error, "requires an object ID"), "analysis dependencies explains an object ID is required");
}

void test_reachability_requires_two_ids(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "reachability-missing-id");

    oep::cli::commands::AnalysisCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr(
        [&] { exit_code = command.execute({"reachability", "only-one-id", "--repository", repo.string()}); });

    check(exit_code != 0, "analysis reachability fails with only one object-id argument");
    check(contains(error, "source object ID and a target object ID"),
          "analysis reachability explains both a source and target ID are required");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::AnalysisCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"not-a-subcommand"}); });
    check(exit_code != 0, "an unknown analysis subcommand fails");
    check(contains(error, "unknown 'analysis' subcommand"), "the error names the unknown subcommand");
}

void test_missing_subcommand_is_rejected() {
    oep::cli::commands::AnalysisCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "a bare 'oep analysis' with no subcommand fails");
    check(contains(error, "requires a subcommand"), "the error explains a subcommand is required");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_analysis_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_dependencies_and_impact_succeed(scratch_dir);
    test_reachability_prints_a_verdict(scratch_dir);
    test_root_cause_against_empty_registry(scratch_dir);
    test_dependencies_requires_object_id(scratch_dir);
    test_reachability_requires_two_ids(scratch_dir);
    test_unknown_subcommand_is_rejected();
    test_missing_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All analysis command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " analysis command test(s) failed.\n";
    return 1;
}
