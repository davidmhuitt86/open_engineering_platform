#include "commands/rules_command.hpp"
#include "commands/object_command.hpp"
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
    check(result.success, "generating a sample repository for rules command tests succeeds");
    return parent / name;
}

std::string extract_created_id(const std::string& output) {
    const std::size_t first_quote = output.find('\'');
    const std::size_t second_quote = output.find('\'', first_quote + 1);
    if (first_quote == std::string::npos || second_quote == std::string::npos) {
        return "";
    }
    return output.substr(first_quote + 1, second_quote - first_quote - 1);
}

// Creates one object WITHOUT a description -- an easy target for a
// HasDescription rule below. ObjectCommand's `create` never sets
// description unless `--description` is given.
std::string create_object(const std::filesystem::path& repo, const std::string& type, const std::string& name) {
    oep::cli::commands::ObjectCommand object_command;
    const std::string output = capture_stdout([&] {
        object_command.execute({"create", "--type", type, "--name", name, "--repository", repo.string()});
    });
    return extract_created_id(output);
}

void test_list_reports_empty_registry(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "list-empty");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo.string()}); });

    check(exit_code == 0, "rules list succeeds against a fresh repository");
    check(contains(output, "Enabled rules (0):"), "rules list reports zero enabled rules (fresh process-local registry)");
    check(contains(output, "Disabled rules (0):"), "rules list reports zero disabled rules");
}

void test_register_without_evaluate_reports_success(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "register-basic");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"register", "--id", "r1", "--name", "Needs description", "--category",
                                      "Documentation", "--severity", "Warning", "--scope-type", "AllObjects",
                                      "--condition-kind", "HasDescription", "--message", "missing description",
                                      "--repository", repo.string()});
    });

    check(exit_code == 0, "rules register succeeds with the required flags");
    check(contains(output, "Rule 'r1' registered"), "rules register confirms the rule id");
    check(contains(output, "not persisted"), "rules register documents the process-local limitation");
}

void test_register_rejects_missing_required_flags(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "register-missing-flags");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] {
        exit_code = command.execute({"register", "--id", "r1", "--repository", repo.string()});
    });

    check(exit_code != 0, "rules register fails when required flags are missing");
    check(contains(error, "requires"), "rules register explains which flags are required");
}

void test_register_rejects_unknown_category(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "register-bad-category");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] {
        exit_code = command.execute({"register", "--id", "r1", "--name", "n", "--category", "NotACategory",
                                      "--severity", "Warning", "--scope-type", "AllObjects", "--condition-kind",
                                      "HasDescription", "--message", "m", "--repository", repo.string()});
    });

    check(exit_code != 0, "rules register fails for an unrecognized --category");
    check(contains(error, "unrecognized --category"), "rules register reports the unrecognized category");
}

void test_register_with_evaluate_reports_result(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "register-evaluate");
    const std::string object_id = create_object(repo, "Document", "Undescribed");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"register", "--id", "r-eval", "--name", "Needs description", "--category",
                                      "Documentation", "--severity", "Warning", "--scope-type", "AllObjects",
                                      "--condition-kind", "HasDescription", "--message", "missing description",
                                      "--evaluate", "--repository", repo.string()});
    });

    check(exit_code == 1, "rules register --evaluate exits 1 when the rule fails (undescribed object present)");
    check(contains(output, "registered"), "rules register --evaluate confirms registration");
    check(contains(output, "Status: Failed"), "rules register --evaluate reports the Failed status");
    check(contains(output, object_id), "rules register --evaluate lists the affected object id");
}

void test_register_with_evaluate_passes_when_scope_empty(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "register-evaluate-pass");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"register", "--id", "r-empty", "--name", "Needs description", "--category",
                                      "Documentation", "--severity", "Info", "--scope-type", "AllObjects",
                                      "--condition-kind", "HasDescription", "--message", "missing description",
                                      "--evaluate", "--repository", repo.string()});
    });

    // Only a Passed status exits 0 (mirroring 'rules evaluate'); NotApplicable
    // still exits nonzero even though it is not itself a "failure".
    check(exit_code == 1, "rules register --evaluate exits nonzero for a NotApplicable result");
    check(contains(output, "Status: NotApplicable"), "rules register --evaluate reports NotApplicable for an empty scope");
}

void test_enable_disable_fail_on_unregistered_rule(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "enable-disable-fresh");

    oep::cli::commands::RulesCommand command;
    int enable_exit = -1;
    const std::string enable_error = capture_stderr([&] {
        enable_exit = command.execute({"enable", "no-such-rule", "--repository", repo.string()});
    });
    check(enable_exit != 0, "rules enable fails against a fresh (empty) registry");
    check(contains(enable_error, "not registered"), "rules enable explains the registry is empty/process-local");

    int disable_exit = -1;
    const std::string disable_error = capture_stderr([&] {
        disable_exit = command.execute({"disable", "no-such-rule", "--repository", repo.string()});
    });
    check(disable_exit != 0, "rules disable fails against a fresh (empty) registry");
    check(contains(disable_error, "not registered"), "rules disable explains the registry is empty/process-local");
}

void test_enable_requires_rule_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "enable-missing-id");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    capture_stderr([&] { exit_code = command.execute({"enable", "--repository", repo.string()}); });
    check(exit_code != 0, "rules enable fails without a rule id argument");
}

void test_evaluate_fails_on_unregistered_rule(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "evaluate-fresh");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] {
        exit_code = command.execute({"evaluate", "no-such-rule", "--repository", repo.string()});
    });
    check(exit_code != 0, "rules evaluate fails against a fresh (empty) registry");
    check(contains(error, "not registered"), "rules evaluate explains the registry is empty/process-local");
}

void test_info_fails_on_unregistered_rule(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "info-fresh");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] {
        exit_code = command.execute({"info", "no-such-rule", "--repository", repo.string()});
    });
    check(exit_code != 0, "rules info fails against a fresh (empty) registry");
    check(contains(error, "not registered"), "rules info explains the registry is empty/process-local");
}

void test_info_requires_rule_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "info-missing-id");

    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    capture_stderr([&] { exit_code = command.execute({"info", "--repository", repo.string()}); });
    check(exit_code != 0, "rules info fails without a rule id argument");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({"not-a-subcommand"}); });
    check(exit_code != 0, "an unknown rules subcommand fails");
    check(contains(error, "unknown 'rules' subcommand"), "the error names the unknown subcommand");
}

void test_missing_subcommand_is_rejected() {
    oep::cli::commands::RulesCommand command;
    int exit_code = -1;
    const std::string error = capture_stderr([&] { exit_code = command.execute({}); });
    check(exit_code != 0, "a bare 'oep rules' with no subcommand fails");
    check(contains(error, "requires a subcommand"), "the error explains a subcommand is required");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_rules_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_list_reports_empty_registry(scratch_dir);
    test_register_without_evaluate_reports_success(scratch_dir);
    test_register_rejects_missing_required_flags(scratch_dir);
    test_register_rejects_unknown_category(scratch_dir);
    test_register_with_evaluate_reports_result(scratch_dir);
    test_register_with_evaluate_passes_when_scope_empty(scratch_dir);
    test_enable_disable_fail_on_unregistered_rule(scratch_dir);
    test_enable_requires_rule_id(scratch_dir);
    test_evaluate_fails_on_unregistered_rule(scratch_dir);
    test_info_fails_on_unregistered_rule(scratch_dir);
    test_info_requires_rule_id(scratch_dir);
    test_unknown_subcommand_is_rejected();
    test_missing_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All rules command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " rules command test(s) failed.\n";
    return 1;
}
