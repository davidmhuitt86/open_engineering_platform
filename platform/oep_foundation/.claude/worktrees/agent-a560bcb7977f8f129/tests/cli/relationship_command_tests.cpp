#include "commands/object_command.hpp"
#include "commands/relationship_command.hpp"
#include "generator/repository_generator.hpp"
#include "oep/repository/audit_store.hpp"

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
    check(result.success, "generating a sample repository for relationship command tests succeeds");
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

std::string create_object_and_get_id(const std::filesystem::path& repo, const std::string& type,
                                      const std::string& name) {
    oep::cli::commands::ObjectCommand object_command;
    std::string output = capture_stdout([&] {
        object_command.execute({"create", "--type", type, "--name", name, "--repository", repo.string()});
    });
    return extract_created_id(output);
}

void test_create_requires_source_target_and_type() {
    oep::cli::commands::RelationshipCommand command;

    int exit_code = 0;
    const std::string error_output =
        capture_stderr([&] { exit_code = command.execute({"create", "--source", "x", "--target", "y"}); });

    check(exit_code != 0, "create fails when --type is missing");
    check(!error_output.empty(), "create reports a descriptive error when required fields are missing");
}

void test_create_rejects_unknown_relationship_type(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "bad-type");
    const std::string source_id = create_object_and_get_id(repo, "Document", "Manual");
    const std::string target_id = create_object_and_get_id(repo, "Component", "Coil");

    oep::cli::commands::RelationshipCommand command;
    int exit_code = 0;
    capture_stderr([&] {
        exit_code = command.execute({"create", "--source", source_id, "--target", target_id, "--type",
                                      "NotARealType", "--repository", repo.string()});
    });

    check(exit_code != 0, "create fails for an unrecognized relationship type");
}

void test_create_rejects_nonexistent_object(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "missing-object");
    const std::string source_id = create_object_and_get_id(repo, "Document", "Manual");

    oep::cli::commands::RelationshipCommand command;
    int exit_code = 0;
    capture_stderr([&] {
        exit_code = command.execute({"create", "--source", source_id, "--target",
                                      "00000000-0000-4000-8000-000000000000", "--type", "Documents", "--repository",
                                      repo.string()});
    });

    check(exit_code != 0, "create fails when the target object does not exist");
}

void test_create_rejects_matching_source_and_target(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "matching-endpoints");
    const std::string object_id = create_object_and_get_id(repo, "Component", "Self");

    oep::cli::commands::RelationshipCommand command;
    int exit_code = 0;
    capture_stderr([&] {
        exit_code = command.execute({"create", "--source", object_id, "--target", object_id, "--type", "References",
                                      "--repository", repo.string()});
    });

    check(exit_code != 0, "create fails when source and target are the same object");
}

void test_full_relationship_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "lifecycle");
    const std::string source_id = create_object_and_get_id(repo, "Document", "Manual");
    const std::string target_id = create_object_and_get_id(repo, "Component", "Coil");

    oep::cli::commands::RelationshipCommand command;

    int create_exit = 0;
    const std::string create_output = capture_stdout([&] {
        create_exit = command.execute({"create", "--source", source_id, "--target", target_id, "--type",
                                        "Documents", "--author", "Jane", "--description", "Manual documents the coil",
                                        "--repository", repo.string()});
    });
    check(create_exit == 0, "create succeeds with valid required fields");
    check(contains(create_output, "Created relationship"), "create reports the created relationship");

    const std::string relationship_id = extract_created_id(create_output);
    check(!relationship_id.empty(), "the created relationship's ID can be extracted from output");

    int list_exit = 0;
    const std::string list_output =
        capture_stdout([&] { list_exit = command.execute({"list", "--repository", repo.string()}); });
    check(list_exit == 0, "list succeeds");
    check(contains(list_output, relationship_id), "list includes the created relationship's ID");
    check(contains(list_output, "Documents"), "list includes the relationship type");
    check(contains(list_output, source_id) && contains(list_output, target_id),
          "list includes both endpoint object IDs");

    int show_exit = 0;
    const std::string show_output = capture_stdout(
        [&] { show_exit = command.execute({"show", relationship_id, "--repository", repo.string()}); });
    check(show_exit == 0, "show succeeds for an existing relationship");
    check(contains(show_output, "Relationship ID:"), "show displays the relationship ID field");
    check(contains(show_output, "Author:") && contains(show_output, "Jane"), "show displays the author");
    check(contains(show_output, "Description:") && contains(show_output, "Manual documents the coil"),
          "show displays the description");
    check(contains(show_output, "Created:"), "show displays the creation timestamp");

    int delete_exit = 0;
    const std::string delete_output = capture_stdout(
        [&] { delete_exit = command.execute({"delete", relationship_id, "--repository", repo.string()}); });
    check(delete_exit == 0, "delete succeeds for an existing relationship");
    check(contains(delete_output, "Deleted relationship"), "delete reports the deleted relationship");

    int show_after_delete_exit = 0;
    capture_stderr([&] {
        show_after_delete_exit = command.execute({"show", relationship_id, "--repository", repo.string()});
    });
    check(show_after_delete_exit != 0, "show fails for a relationship that has been deleted");
}

void test_delete_generates_audit_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "audit-on-delete");
    const std::string source_id = create_object_and_get_id(repo, "Document", "Manual");
    const std::string target_id = create_object_and_get_id(repo, "Component", "Coil");

    oep::cli::commands::RelationshipCommand command;
    const std::string create_output = capture_stdout([&] {
        command.execute({"create", "--source", source_id, "--target", target_id, "--type", "Documents",
                          "--repository", repo.string()});
    });
    const std::string relationship_id = extract_created_id(create_output);

    command.execute({"delete", relationship_id, "--repository", repo.string()});

    const oep::repository::AuditStore audit(repo / "repository" / "audit");
    const oep::repository::ListAuditEventsResult events = audit.list_events_for_object(relationship_id);
    check(events.success, "listing audit events for the deleted relationship succeeds");

    bool found_relationship_deleted = false;
    for (const oep::repository::AuditEvent& event : events.events) {
        if (event.event_type == oep::repository::AuditEventType::RelationshipDeleted) {
            found_relationship_deleted = true;
        }
    }
    check(found_relationship_deleted,
          "deleting a relationship through the CLI automatically records a RelationshipDeleted event");
}

void test_list_reports_none_for_empty_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "list-empty");
    oep::cli::commands::RelationshipCommand command;

    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo.string()}); });

    check(exit_code == 0, "list succeeds for a repository with no relationships");
    check(contains(output, "No relationships found"), "list reports that none were found");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::RelationshipCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });

    check(exit_code != 0, "an unrecognized 'relationship' subcommand fails");
    check(contains(error_output, "unknown"), "the error names the unknown subcommand");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_relationship_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_create_requires_source_target_and_type();
    test_create_rejects_unknown_relationship_type(scratch_dir);
    test_create_rejects_nonexistent_object(scratch_dir);
    test_create_rejects_matching_source_and_target(scratch_dir);
    test_full_relationship_lifecycle(scratch_dir);
    test_delete_generates_audit_event(scratch_dir);
    test_list_reports_none_for_empty_repository(scratch_dir);
    test_unknown_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All relationship command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " relationship command test(s) failed.\n";
    return 1;
}
