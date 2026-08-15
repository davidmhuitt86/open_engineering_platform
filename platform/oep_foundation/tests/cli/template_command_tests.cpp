#include "commands/object_command.hpp"
#include "commands/template_command.hpp"
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
    check(result.success, "generating a sample repository for template command tests succeeds");
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

void test_template_create_requires_name(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "create-no-name");
    oep::cli::commands::TemplateCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr([&] {
        exit_code = command.execute({"create", "--repository", repo.string()});
    });

    check(exit_code != 0, "template create fails without --name");
    check(!error_output.empty(), "template create reports a descriptive error without --name");
}

void test_full_template_workflow(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "workflow-source");
    const std::filesystem::path templates_dir = scratch_dir / "workflow-templates";

    oep::cli::commands::ObjectCommand object_command;
    capture_stdout([&] {
        object_command.execute(
            {"create", "--type", "Component", "--name", "Standard Widget", "--repository", repo.string()});
    });

    oep::cli::commands::TemplateCommand template_command;

    int create_exit = 0;
    const std::string create_output = capture_stdout([&] {
        create_exit = template_command.execute({"create", "--name", "Standard Kit", "--description", "A kit",
                                                 "--author", "Jane", "--repository", repo.string(),
                                                 "--templates-dir", templates_dir.string()});
    });
    check(create_exit == 0, "template create succeeds");
    check(contains(create_output, "Created template"), "template create reports the created template");
    const std::string template_id = extract_created_id(create_output);
    check(!template_id.empty(), "the created template's ID can be extracted from output");

    int list_exit = 0;
    const std::string list_output = capture_stdout(
        [&] { list_exit = template_command.execute({"list", "--templates-dir", templates_dir.string()}); });
    check(list_exit == 0, "template list succeeds");
    check(contains(list_output, template_id) && contains(list_output, "Standard Kit"),
          "template list includes the created template");

    const std::filesystem::path instantiate_parent = scratch_dir / "workflow-instantiate";
    std::filesystem::create_directories(instantiate_parent);
    const std::string original_cwd = std::filesystem::current_path().string();
    std::filesystem::current_path(instantiate_parent);

    int instantiate_exit = 0;
    const std::string instantiate_output = capture_stdout([&] {
        instantiate_exit = template_command.execute(
            {"instantiate", template_id, "new-workshop", "--templates-dir", templates_dir.string()});
    });

    std::filesystem::current_path(original_cwd);

    check(instantiate_exit == 0, "template instantiate succeeds");
    check(contains(instantiate_output, "Instantiated template"), "template instantiate reports success");
    check(std::filesystem::exists(instantiate_parent / "new-workshop" / "repository.json"),
          "template instantiate creates a new repository");

    oep::cli::commands::ObjectCommand list_objects_command;
    const std::string objects_output = capture_stdout([&] {
        list_objects_command.execute(
            {"list", "--repository", (instantiate_parent / "new-workshop").string()});
    });
    check(contains(objects_output, "Standard Widget"),
          "the instantiated repository contains the template's object");
}

void test_template_instantiate_requires_two_arguments() {
    oep::cli::commands::TemplateCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({"instantiate", "only-one"}); });

    check(exit_code != 0, "template instantiate fails when the new repository name is missing");
    check(!error_output.empty(), "template instantiate reports a descriptive error");
}

void test_template_list_reports_none_for_empty_directory(const std::filesystem::path& scratch_dir) {
    oep::cli::commands::TemplateCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout([&] {
        exit_code = command.execute({"list", "--templates-dir", (scratch_dir / "no-templates-here").string()});
    });

    check(exit_code == 0, "template list succeeds for a directory with no templates");
    check(contains(output, "No templates found"), "template list reports that none were found");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::TemplateCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });

    check(exit_code != 0, "an unrecognized 'template' subcommand fails");
    check(contains(error_output, "unknown"), "the error names the unknown subcommand");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_template_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_template_create_requires_name(scratch_dir);
    test_full_template_workflow(scratch_dir);
    test_template_instantiate_requires_two_arguments();
    test_template_list_reports_none_for_empty_directory(scratch_dir);
    test_unknown_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All template command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " template command test(s) failed.\n";
    return 1;
}
