#include "commands/object_command.hpp"
#include "commands/transaction_command.hpp"
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
    check(result.success, "generating a sample repository for transaction command tests succeeds");
    return parent / name;
}

// Extracts the first UUID-shaped token from a listing line.
std::string extract_transaction_id(const std::string& output) {
    const std::size_t tab = output.find('\t');
    return tab == std::string::npos ? "" : output.substr(0, tab);
}

void test_list_and_show(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "txn-list-show");
    const std::string repo_arg = repo.string();

    // An empty journal lists cleanly.
    oep::cli::commands::TransactionCommand command;
    int exit_code = 1;
    std::string output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0, "transaction list succeeds for a fresh repository");
    check(contains(output, "No journaled transactions"), "an empty journal says so");

    // A CLI object create runs through an implicit Repository Transaction
    // (WP-REP-003), so it must appear in the journal.
    oep::cli::commands::ObjectCommand object_command;
    capture_stdout([&] {
        exit_code = object_command.execute(
            {"create", "--type", "Component", "--name", "Journaled Widget", "--repository", repo_arg});
    });
    check(exit_code == 0, "creating an object via the CLI succeeds");

    output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0, "transaction list succeeds after a mutation");
    check(contains(output, "Committed") && contains(output, "object create"),
          "the mutation's implicit transaction is journaled as Committed");

    const std::string transaction_id = extract_transaction_id(output);
    check(transaction_id.size() == 36, "the listing starts with the transaction's UUID");

    output = capture_stdout([&] { exit_code = command.execute({"show", transaction_id, "--repository", repo_arg}); });
    check(exit_code == 0, "transaction show succeeds for a journaled id");
    check(contains(output, "ObjectCreated") && contains(output, "absent -> present:Journaled Widget"),
          "transaction show lists the journaled operation with its previous/new state");
}

void test_show_fails_for_an_unknown_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "txn-unknown");
    oep::cli::commands::TransactionCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code = command.execute(
            {"show", "00000000-0000-4000-8000-00000000dead", "--repository", repo.string()});
    });
    check(exit_code != 0, "transaction show fails for an id that was never journaled");
    check(contains(error_output, "no journaled transaction"), "the failure names the problem");
}

void test_missing_arguments_are_rejected() {
    oep::cli::commands::TransactionCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "transaction with no subcommand is rejected");
    capture_stderr([&] { exit_code = command.execute({"show"}); });
    check(exit_code != 0, "transaction show with no id is rejected");
    capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });
    check(exit_code != 0, "an unknown transaction subcommand is rejected");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_transaction_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_list_and_show(scratch_dir);
    test_show_fails_for_an_unknown_id(scratch_dir);
    test_missing_arguments_are_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All transaction command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " transaction command test(s) failed.\n";
    return 1;
}
