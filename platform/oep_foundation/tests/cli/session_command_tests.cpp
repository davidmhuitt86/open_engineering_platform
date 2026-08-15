#include "commands/session_command.hpp"
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
    check(result.success, "generating a sample repository for session command tests succeeds");
    return parent / name;
}

void test_create_prints_session_id_and_process_local_note(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "create");

    oep::cli::commands::SessionCommand command;
    int exit_code = -1;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"create", "--repository", repo.string()}); });

    check(exit_code == 0, "session create succeeds against a fresh repository");
    check(contains(output, "Session created:"), "session create prints the created session id");
    check(contains(output, "process-local"), "session create documents the process-local limitation");
}

void test_list_reports_no_sessions_in_a_fresh_invocation(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "list-fresh");

    oep::cli::commands::SessionCommand command;
    int exit_code = -1;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo.string()}); });

    check(exit_code == 0, "session list succeeds against a fresh repository");
    check(contains(output, "Sessions (0)"), "session list reports zero sessions in a fresh invocation");
    check(contains(output, "process-local"), "session list documents the process-local limitation");
}

void test_close_fails_for_any_session_id_in_a_fresh_invocation(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "close-fresh-process");

    oep::cli::commands::SessionCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr(
        [&] { exit_code = command.execute({"close", "some-session-id", "--repository", repo.string()}); });

    check(exit_code != 0, "session close fails for any session_id in a fresh process");
    check(contains(error, "process-local"), "session close documents the process-local limitation");
}

void test_close_requires_session_id() {
    oep::cli::commands::SessionCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"close"}); });

    check(exit_code != 0, "session close fails without a session-id argument");
    check(contains(error, "requires a session ID"), "session close explains a session ID is required");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::SessionCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"not-a-subcommand"}); });
    check(exit_code != 0, "an unknown session subcommand fails");
    check(contains(error, "unknown 'session' subcommand"), "the error names the unknown subcommand");
}

void test_missing_subcommand_is_rejected() {
    oep::cli::commands::SessionCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "a bare 'oep session' with no subcommand fails");
    check(contains(error, "requires a subcommand"), "the error explains a subcommand is required");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_session_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_create_prints_session_id_and_process_local_note(scratch_dir);
    test_list_reports_no_sessions_in_a_fresh_invocation(scratch_dir);
    test_close_fails_for_any_session_id_in_a_fresh_invocation(scratch_dir);
    test_close_requires_session_id();
    test_unknown_subcommand_is_rejected();
    test_missing_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All session command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " session command test(s) failed.\n";
    return 1;
}
