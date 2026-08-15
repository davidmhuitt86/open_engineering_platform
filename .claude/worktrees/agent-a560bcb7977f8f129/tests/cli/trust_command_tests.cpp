#include "commands/trust_command.hpp"
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
    check(result.success, "generating a sample repository for trust command tests succeeds");
    return parent / name;
}

constexpr const char* kValidKeyHex = "99c4ac9e6560c3a1e4bfd6a20e5ab6513aa77eea9233c01fe296e8b17f106cff";

void test_trust_list_revoke_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "trust-lifecycle");
    const std::string repo_arg = repo.string();
    oep::cli::commands::TrustCommand command;

    int exit_code = 1;
    std::string output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0, "trust list succeeds for a fresh Trust Store");
    check(contains(output, "No trusted publisher certificates"), "an empty Trust Store says so");

    output = capture_stdout([&] {
        exit_code = command.execute({"trust", "com.pub.cli", "--name", "CLI Publisher", "--key", kValidKeyHex,
                                      "--repository", repo_arg});
    });
    check(exit_code == 0, "trust trust succeeds for a well-formed certificate");
    check(contains(output, "com.pub.cli"), "the confirmation names the trusted publisher");

    output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0 && contains(output, "com.pub.cli") && contains(output, "CLI Publisher") &&
              contains(output, "Trusted"),
          "trust list shows the newly trusted publisher");

    output = capture_stdout([&] { exit_code = command.execute({"revoke", "com.pub.cli", "--repository", repo_arg}); });
    check(exit_code == 0, "trust revoke succeeds");

    output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo_arg}); });
    check(exit_code == 0 && contains(output, "Revoked"), "trust list shows the publisher as Revoked after revoke");
}

void test_trust_requires_key(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "trust-missing-key");
    oep::cli::commands::TrustCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code = command.execute({"trust", "com.pub.nokeys", "--repository", repo.string()});
    });
    check(exit_code != 0, "trust trust fails without --key");
    check(contains(error_output, "--key"), "the failure names the missing --key flag");
}

void test_policy_round_trip(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "trust-policy");
    const std::string repo_arg = repo.string();
    oep::cli::commands::TrustCommand command;

    int exit_code = 1;
    std::string output = capture_stdout([&] { exit_code = command.execute({"policy", "--repository", repo_arg}); });
    check(exit_code == 0 && contains(output, "Signatures required: no"), "the default policy does not require signatures");

    output = capture_stdout([&] { exit_code = command.execute({"policy", "require", "--repository", repo_arg}); });
    check(exit_code == 0, "trust policy require succeeds");

    output = capture_stdout([&] { exit_code = command.execute({"policy", "show", "--repository", repo_arg}); });
    check(exit_code == 0 && contains(output, "Signatures required: yes"), "the policy change is reflected");

    output = capture_stdout([&] { exit_code = command.execute({"policy", "allow-unsigned", "--repository", repo_arg}); });
    check(exit_code == 0, "trust policy allow-unsigned succeeds");

    output = capture_stdout([&] { exit_code = command.execute({"policy", "show", "--repository", repo_arg}); });
    check(exit_code == 0 && contains(output, "Signatures required: no"), "the policy reverts as expected");
}

void test_missing_arguments_and_unknown_subcommand() {
    oep::cli::commands::TrustCommand command;
    int exit_code = 0;
    capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "trust with no subcommand is rejected");
    capture_stderr([&] { exit_code = command.execute({"trust"}); });
    check(exit_code != 0, "trust trust with no publisher id is rejected");
    capture_stderr([&] { exit_code = command.execute({"revoke"}); });
    check(exit_code != 0, "trust revoke with no publisher id is rejected");
    capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });
    check(exit_code != 0, "an unknown trust subcommand is rejected");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_trust_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_trust_list_revoke_lifecycle(scratch_dir);
    test_trust_requires_key(scratch_dir);
    test_policy_round_trip(scratch_dir);
    test_missing_arguments_and_unknown_subcommand();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All trust command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " trust command test(s) failed.\n";
    return 1;
}
