#include "commands/object_command.hpp"
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
    check(result.success, "generating a sample repository for object command tests succeeds");
    return parent / name;
}

// Extracts the object ID from a "Created object '<id>' (...) '...'" line.
std::string extract_created_id(const std::string& output) {
    const std::size_t first_quote = output.find('\'');
    const std::size_t second_quote = output.find('\'', first_quote + 1);
    if (first_quote == std::string::npos || second_quote == std::string::npos) {
        return "";
    }
    return output.substr(first_quote + 1, second_quote - first_quote - 1);
}

void test_create_requires_type_and_name() {
    oep::cli::commands::ObjectCommand command;

    int exit_code = 0;
    const std::string error_output =
        capture_stderr([&] { exit_code = command.execute({"create", "--type", "Component"}); });

    check(exit_code != 0, "create fails when --name is missing");
    check(!error_output.empty(), "create reports a descriptive error when required fields are missing");
}

void test_create_rejects_unknown_object_type(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "create-bad-type");
    oep::cli::commands::ObjectCommand command;

    int exit_code = 0;
    capture_stderr([&] {
        exit_code = command.execute(
            {"create", "--type", "NotARealType", "--name", "X", "--repository", repo.string()});
    });

    check(exit_code != 0, "create fails for an unrecognized object type");
}

void test_full_object_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "lifecycle");
    oep::cli::commands::ObjectCommand command;

    int create_exit = 0;
    const std::string create_output = capture_stdout([&] {
        create_exit = command.execute({"create", "--type", "Component", "--name", "Ignition Coil", "--description",
                                        "Generates spark", "--author", "Jane", "--tags", "electrical,ignition",
                                        "--repository", repo.string()});
    });
    check(create_exit == 0, "create succeeds with valid required fields");
    check(contains(create_output, "Created object"), "create reports the created object");

    const std::string object_id = extract_created_id(create_output);
    check(!object_id.empty(), "the created object's ID can be extracted from output");

    int list_exit = 0;
    const std::string list_output =
        capture_stdout([&] { list_exit = command.execute({"list", "--repository", repo.string()}); });
    check(list_exit == 0, "list succeeds");
    check(contains(list_output, object_id), "list includes the created object's ID");
    check(contains(list_output, "Component"), "list includes the object type");
    check(contains(list_output, "Ignition Coil"), "list includes the object name");

    int show_exit = 0;
    const std::string show_output =
        capture_stdout([&] { show_exit = command.execute({"show", object_id, "--repository", repo.string()}); });
    check(show_exit == 0, "show succeeds for an existing object");
    check(contains(show_output, "Object ID:"), "show displays the object ID field");
    check(contains(show_output, "Description:") && contains(show_output, "Generates spark"),
          "show displays the description");
    check(contains(show_output, "Author:") && contains(show_output, "Jane"), "show displays the author");
    check(contains(show_output, "Tags:") && contains(show_output, "electrical"), "show displays tags");
    check(contains(show_output, "Created:"), "show displays the creation timestamp");
    check(contains(show_output, "Last Modified:"), "show displays the last-modified timestamp");

    int delete_exit = 0;
    const std::string delete_output =
        capture_stdout([&] { delete_exit = command.execute({"delete", object_id, "--repository", repo.string()}); });
    check(delete_exit == 0, "delete succeeds for an existing object");
    check(contains(delete_output, "Deleted object"), "delete reports the deleted object");

    int show_after_delete_exit = 0;
    capture_stderr(
        [&] { show_after_delete_exit = command.execute({"show", object_id, "--repository", repo.string()}); });
    check(show_after_delete_exit != 0, "show fails for an object that has been deleted");
}

void test_delete_generates_audit_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "audit-on-delete");
    oep::cli::commands::ObjectCommand command;

    int create_exit = 0;
    const std::string create_output = capture_stdout([&] {
        create_exit =
            command.execute({"create", "--type", "Document", "--name", "Manual", "--repository", repo.string()});
    });
    check(create_exit == 0, "create succeeds before the audit test");
    const std::string object_id = extract_created_id(create_output);

    command.execute({"delete", object_id, "--repository", repo.string()});

    const oep::repository::AuditStore audit(repo / "repository" / "audit");
    const oep::repository::ListAuditEventsResult events = audit.list_events_for_object(object_id);
    check(events.success, "listing audit events for the deleted object succeeds");

    bool found_object_deleted = false;
    for (const oep::repository::AuditEvent& event : events.events) {
        if (event.event_type == oep::repository::AuditEventType::ObjectDeleted) {
            found_object_deleted = true;
        }
    }
    check(found_object_deleted, "deleting an object through the CLI automatically records an ObjectDeleted event");
}

void test_show_fails_for_nonexistent_object(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "show-missing");
    oep::cli::commands::ObjectCommand command;

    int exit_code = 0;
    capture_stderr([&] {
        exit_code = command.execute({"show", "00000000-0000-4000-8000-000000000000", "--repository", repo.string()});
    });

    check(exit_code != 0, "show fails for a nonexistent object ID");
}

void test_list_reports_no_objects_for_empty_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path repo = build_repository(scratch_dir, "list-empty");
    oep::cli::commands::ObjectCommand command;

    int exit_code = 0;
    const std::string output =
        capture_stdout([&] { exit_code = command.execute({"list", "--repository", repo.string()}); });

    check(exit_code == 0, "list succeeds for a repository with no objects");
    check(contains(output, "No objects found"), "list reports that no objects were found");
}

void test_unknown_subcommand_is_rejected() {
    oep::cli::commands::ObjectCommand command;

    int exit_code = 0;
    const std::string error_output = capture_stderr([&] { exit_code = command.execute({"frobnicate"}); });

    check(exit_code != 0, "an unrecognized 'object' subcommand fails");
    check(contains(error_output, "unknown"), "the error names the unknown subcommand");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_object_command_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_create_requires_type_and_name();
    test_create_rejects_unknown_object_type(scratch_dir);
    test_full_object_lifecycle(scratch_dir);
    test_delete_generates_audit_event(scratch_dir);
    test_show_fails_for_nonexistent_object(scratch_dir);
    test_list_reports_no_objects_for_empty_repository(scratch_dir);
    test_unknown_subcommand_is_rejected();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All object command tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " object command test(s) failed.\n";
    return 1;
}
