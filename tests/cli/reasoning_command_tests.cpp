#include "commands/reasoning_command.hpp"
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
    check(result.success, "generating a sample repository for reasoning command tests succeeds");
    return parent / name;
}

void test_execute_prints_summary_conclusions_and_recommendations(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "execute");

    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute(
            {"execute", "any-object-id", "--objective", "investigate", "--repository", repo.string()});
    });

    check(exit_code == 0, "reasoning execute succeeds against a fresh repository");
    check(contains(output, "Session:"), "reasoning execute prints the session id");
    check(contains(output, "Objective: investigate"), "reasoning execute prints the objective");
    check(contains(output, "Conclusions ("), "reasoning execute prints a conclusions section");
    check(contains(output, "Recommendations ("), "reasoning execute prints a recommendations section");
}

void test_execute_requires_starting_object(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "execute-missing-object");

    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string error =
        capture_stderr([&] { exit_code = command.execute({"execute", "--repository", repo.string()}); });

    check(exit_code != 0, "reasoning execute fails without a starting object id");
    check(contains(error, "at least one starting object ID"), "reasoning execute explains a starting object is required");
}

void test_report_fails_for_any_session_id_in_a_fresh_invocation(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "report-fresh-process");

    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr(
        [&] { exit_code = command.execute({"report", "some-session-id", "--repository", repo.string()}); });

    check(exit_code != 0, "reasoning report fails for any session_id in a fresh process");
    check(contains(error, "process-local"), "reasoning report documents the process-local limitation");
}

void test_report_requires_session_id() {
    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"report"}); });

    check(exit_code != 0, "reasoning report fails without a session-id argument");
    check(contains(error, "requires a session ID"), "reasoning report explains a session ID is required");
}

void test_recommendations_requires_session_id() {
    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"recommendations"}); });

    check(exit_code != 0, "reasoning recommendations fails without a session-id argument");
    check(contains(error, "requires a session ID"), "reasoning recommendations explains a session ID is required");
}

void test_evidence_requires_session_id() {
    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"evidence"}); });

    check(exit_code != 0, "reasoning evidence fails without a session-id argument");
    check(contains(error, "requires a session ID"), "reasoning evidence explains a session ID is required");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"not-a-subcommand"}); });
    check(exit_code != 0, "an unknown reasoning subcommand fails");
    check(contains(error, "unknown 'reasoning' subcommand"), "the error names the unknown subcommand");
}

void test_missing_subcommand_is_rejected() {
    oep::cli::commands::ReasoningCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "a bare 'oep reasoning' with no subcommand fails");
    check(contains(error, "requires a subcommand"), "the error explains a subcommand is required");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_reasoning_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_execute_prints_summary_conclusions_and_recommendations(scratch_dir);
    test_execute_requires_starting_object(scratch_dir);
    test_report_fails_for_any_session_id_in_a_fresh_invocation(scratch_dir);
    test_report_requires_session_id();
    test_recommendations_requires_session_id();
    test_evidence_requires_session_id();
    test_unknown_subcommand_is_rejected();
    test_missing_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All reasoning command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " reasoning command test(s) failed.\n";
    return 1;
}
