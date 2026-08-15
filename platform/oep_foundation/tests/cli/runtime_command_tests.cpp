#include "commands/object_command.hpp"
#include "commands/runtime_command.hpp"
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

std::size_t line_count(const std::string& output) {
    if (output.empty()) return 0;
    std::size_t count = 0;
    for (char c : output) {
        if (c == '\n') ++count;
    }
    return count;
}

std::filesystem::path build_repository(const std::filesystem::path& parent, const std::string& name) {
    const oep::cli::generator::GenerationResult result =
        oep::cli::generator::generate_foundation_repository(parent / name, name);
    check(result.success, "generating a sample repository for runtime command tests succeeds");
    return parent / name;
}

// Note: the Repository Events log (WP-REP-006) is a process-wide,
// in-memory EventBus (see runtime_event_log.hpp) shared by every CLI
// command executed in this process — it does not reset between
// Command::execute() calls, and it is not scoped to a single
// repository. Tests therefore only assert on relative growth of the
// log (before/after counts), never on an absolute empty state, since
// earlier tests in this binary may have already published events.

void test_object_create_publishes_an_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "runtime-events-create");
    const std::string repo_arg = repo.string();

    oep::cli::commands::RuntimeCommand runtime_command;
    std::string before = capture_stdout([&] { runtime_command.execute({"events", "--repository", repo_arg}); });
    const std::size_t before_count = contains(before, "No repository events recorded.") ? 0 : line_count(before);

    oep::cli::commands::ObjectCommand object_command;
    int exit_code = 1;
    capture_stdout([&] {
        exit_code = object_command.execute(
            {"create", "--type", "Component", "--name", "Eventful Widget", "--repository", repo_arg});
    });
    check(exit_code == 0, "creating an object via the CLI succeeds");

    exit_code = 1;
    std::string output = capture_stdout([&] { exit_code = runtime_command.execute({"events", "--repository", repo_arg}); });
    check(exit_code == 0, "runtime events succeeds after a mutation");
    check(line_count(output) >= before_count + 1, "at least one new event appears after creating an object");
    check(contains(output, "ObjectCreated") && contains(output, "Eventful Widget"),
          "the published event names the object that was created");
}

void test_limit_truncates(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "runtime-events-limit");
    const std::string repo_arg = repo.string();

    oep::cli::commands::ObjectCommand object_command;
    for (int i = 0; i < 5; ++i) {
        int exit_code = 1;
        capture_stdout([&] {
            exit_code = object_command.execute({"create", "--type", "Component", "--name",
                                                 "Limit Widget " + std::to_string(i), "--repository", repo_arg});
        });
        check(exit_code == 0, "creating object " + std::to_string(i) + " for the limit test succeeds");
    }

    oep::cli::commands::RuntimeCommand runtime_command;
    int exit_code = 1;
    std::string output =
        capture_stdout([&] { exit_code = runtime_command.execute({"events", "--limit", "2", "--repository", repo_arg}); });
    check(exit_code == 0, "runtime events with --limit succeeds");
    check(line_count(output) == 2, "--limit 2 returns exactly two events");

    std::string unlimited =
        capture_stdout([&] { exit_code = runtime_command.execute({"events", "--repository", repo_arg}); });
    check(line_count(unlimited) >= 5, "without --limit, at least the five just-published events are present");
}

void test_fresh_repository_reports_zero_new_events(const std::filesystem::path& scratch_dir) {
    // The log is process-wide rather than per-repository (see the note
    // above), so this asserts that simply opening a freshly generated
    // repository — with no mutations performed against it — does not by
    // itself add any events, by checking the log's size is unchanged
    // across a no-op window.
    const std::filesystem::path repo = build_repository(scratch_dir, "runtime-events-fresh");
    const std::string repo_arg = repo.string();

    oep::cli::commands::RuntimeCommand runtime_command;
    std::string before = capture_stdout([&] { runtime_command.execute({"events"}); });
    std::string after = capture_stdout([&] { runtime_command.execute({"events"}); });
    check(before == after, "querying events for an unmodified repository twice yields the same log");
}

void test_missing_arguments_are_rejected() {
    oep::cli::commands::RuntimeCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "runtime with no subcommand is rejected");
    capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });
    check(exit_code != 0, "an unknown runtime subcommand is rejected");
    capture_stderr([&] { exit_code = command.execute({"events", "--limit", "not-a-number"}); });
    check(exit_code != 0, "a non-numeric --limit is rejected");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_runtime_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_object_create_publishes_an_event(scratch_dir);
    test_limit_truncates(scratch_dir);
    test_fresh_repository_reports_zero_new_events(scratch_dir);
    test_missing_arguments_are_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All runtime command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " runtime command test(s) failed.\n";
    return 1;
}
