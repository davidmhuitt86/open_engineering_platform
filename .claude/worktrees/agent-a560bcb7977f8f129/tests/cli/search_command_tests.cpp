#include "commands/object_command.hpp"
#include "commands/relationship_command.hpp"
#include "commands/search_command.hpp"
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
    check(result.success, "generating a sample repository for search command tests succeeds");
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

std::string create_object(const std::filesystem::path& repo, const std::string& type, const std::string& name,
                           const std::string& author = "", const std::string& tags = "") {
    oep::cli::commands::ObjectCommand object_command;
    std::vector<std::string> args = {"create", "--type", type, "--name", name, "--repository", repo.string()};
    if (!author.empty()) {
        args.push_back("--author");
        args.push_back(author);
    }
    if (!tags.empty()) {
        args.push_back("--tags");
        args.push_back(tags);
    }
    const std::string output = capture_stdout([&] { object_command.execute(args); });
    return extract_created_id(output);
}

void test_object_search_finds_a_match(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "object-search");
    const std::string object_id = create_object(repo, "Component", "Ignition Coil");

    oep::cli::commands::SearchCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"objects", "coil", "--repository", repo.string()}); });

    check(exit_code == 0, "object search succeeds");
    check(contains(output, "Objects:"), "object search output has an Objects section");
    check(contains(output, object_id), "object search finds the created object by name");
    check(contains(output, "Component"), "object search result includes the object type");
}

void test_relationship_search_finds_a_match(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "relationship-search");
    const std::string source_id = create_object(repo, "Document", "Manual");
    const std::string target_id = create_object(repo, "Component", "Coil");

    oep::cli::commands::RelationshipCommand relationship_command;
    capture_stdout([&] {
        relationship_command.execute({"create", "--source", source_id, "--target", target_id, "--type", "Documents",
                                       "--description", "Manual documents the coil", "--repository", repo.string()});
    });

    oep::cli::commands::SearchCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"relationships", "documents", "--repository", repo.string()}); });

    check(exit_code == 0, "relationship search succeeds");
    check(contains(output, "Relationships:"), "relationship search output has a Relationships section");
    check(contains(output, source_id) && contains(output, target_id),
          "relationship search result includes both endpoints");
}

void test_bare_query_searches_both(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "bare-query");
    create_object(repo, "Component", "Ignition Coil");

    oep::cli::commands::SearchCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"coil", "--repository", repo.string()}); });

    check(exit_code == 0, "a bare query succeeds");
    check(contains(output, "Objects:"), "a bare query includes an Objects section");
    check(contains(output, "Relationships:"), "a bare query includes a Relationships section");
}

void test_type_filter_excludes_non_matching_type(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "type-filter");
    create_object(repo, "Component", "Widget Component");
    create_object(repo, "Document", "Widget Document");

    oep::cli::commands::SearchCommand command;
    const std::string output = capture_stdout([&] {
        command.execute({"objects", "widget", "--type", "Document", "--repository", repo.string()});
    });

    check(contains(output, "Widget Document"), "the --type filter keeps the matching type");
    check(!contains(output, "Widget Component"), "the --type filter excludes the non-matching type");
}

void test_author_filter_excludes_non_matching_author(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "author-filter");
    create_object(repo, "Component", "Widget A", "Jane");
    create_object(repo, "Component", "Widget B", "John");

    oep::cli::commands::SearchCommand command;
    const std::string output = capture_stdout(
        [&] { command.execute({"objects", "widget", "--author", "Jane", "--repository", repo.string()}); });

    check(contains(output, "Widget A"), "the --author filter keeps the matching author");
    check(!contains(output, "Widget B"), "the --author filter excludes the non-matching author");
}

void test_tag_filter_excludes_non_matching_tag(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "tag-filter");
    create_object(repo, "Component", "Widget A", "", "electrical");
    create_object(repo, "Component", "Widget B", "", "mechanical");

    oep::cli::commands::SearchCommand command;
    const std::string output = capture_stdout(
        [&] { command.execute({"objects", "widget", "--tag", "electrical", "--repository", repo.string()}); });

    check(contains(output, "Widget A"), "the --tag filter keeps the object with the matching tag");
    check(!contains(output, "Widget B"), "the --tag filter excludes the object without the matching tag");
}

void test_no_matching_results_reported_gracefully(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "no-match");
    create_object(repo, "Component", "Ignition Coil");

    oep::cli::commands::SearchCommand command;
    int exit_code = 0;
    const std::string output = capture_stdout(
        [&] { exit_code = command.execute({"objects", "nonexistent-term-xyz", "--repository", repo.string()}); });

    check(exit_code == 0, "a query with no matches still succeeds as an operation");
    check(contains(output, "No matching objects found"), "a query with no matches is reported gracefully");
}

void test_empty_repository_reports_no_matches(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "empty-repo");

    oep::cli::commands::SearchCommand command;
    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"anything", "--repository", repo.string()}); });

    check(exit_code == 0, "searching an empty repository succeeds");
    check(contains(output, "No matching objects found") && contains(output, "No matching relationships found"),
          "an empty repository reports no matches for both objects and relationships");
}

void test_invalid_repository_reports_descriptive_error(const std::filesystem::path& scratch_dir) {
    oep::cli::commands::SearchCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr(
        [&] { exit_code = command.execute({"anything", "--repository", (scratch_dir / "missing").string()}); });

    check(exit_code != 0, "searching a nonexistent repository fails");
    check(!error_output.empty(), "searching a nonexistent repository reports a descriptive error");
}

void test_missing_query_is_rejected() {
    oep::cli::commands::SearchCommand command;
    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({}); });

    check(exit_code != 0, "search fails when no query is given");
    check(!error_output.empty(), "search reports a descriptive error when no query is given");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_search_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_object_search_finds_a_match(scratch_dir);
    test_relationship_search_finds_a_match(scratch_dir);
    test_bare_query_searches_both(scratch_dir);
    test_type_filter_excludes_non_matching_type(scratch_dir);
    test_author_filter_excludes_non_matching_author(scratch_dir);
    test_tag_filter_excludes_non_matching_tag(scratch_dir);
    test_no_matching_results_reported_gracefully(scratch_dir);
    test_empty_repository_reports_no_matches(scratch_dir);
    test_invalid_repository_reports_descriptive_error(scratch_dir);
    test_missing_query_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All search command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " search command test(s) failed.\n";
    return 1;
}
