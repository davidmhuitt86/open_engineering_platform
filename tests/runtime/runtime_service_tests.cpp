#include "oep/runtime/runtime_service.hpp"

#include "oep/repository/metadata.hpp"

#include <filesystem>
#include <iostream>
#include <string>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

std::filesystem::path build_repository(const std::filesystem::path& root) {
    std::filesystem::create_directories(root);

    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = "2c8f1a44-1111-4b1e-9a4d-0f6a2b7c9e10";
    metadata.repository_name = "runtime-service-tests";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);

    return root;
}

oep::runtime::FoundationRuntime open_runtime(const std::filesystem::path& root) {
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    return runtime;
}

// ---------------------------------------------------------------------
// EventBus
// ---------------------------------------------------------------------

void test_event_bus_assigns_ascending_sequence_numbers() {
    oep::runtime::EventBus bus;
    bus.publish(oep::runtime::EventType::ObjectCreated, "obj-1", "first");
    bus.publish(oep::runtime::EventType::ObjectCreated, "obj-2", "second");
    bus.publish(oep::runtime::EventType::ObjectDeleted, "obj-1", "third");

    const auto events = bus.recent_events();
    check(events.size() == 3, "all three published events are retained");
    check(events[0].sequence() == 1 && events[1].sequence() == 2 && events[2].sequence() == 3,
          "sequence numbers are assigned in ascending publication order");
    check(events[0].subject_id() == "obj-1" && events[2].subject_id() == "obj-1",
          "subject_id is preserved exactly as published");
    check(events[2].type() == oep::runtime::EventType::ObjectDeleted, "event type is preserved exactly as published");
    check(bus.published_count() == 3, "published_count reflects the total number ever published");
}

void test_event_bus_recent_events_respects_limit() {
    oep::runtime::EventBus bus;
    for (int i = 0; i < 5; ++i) {
        bus.publish(oep::runtime::EventType::ObjectCreated, "obj-" + std::to_string(i), "");
    }
    const auto limited = bus.recent_events(2);
    check(limited.size() == 2, "recent_events(2) returns exactly 2 events");
    check(limited[0].subject_id() == "obj-3" && limited[1].subject_id() == "obj-4",
          "recent_events(limit) returns the MOST RECENT events, oldest of the kept set first");
}

void test_event_bus_enforces_retention_bound() {
    oep::runtime::EventBus bus(/*max_retained=*/3);
    for (int i = 0; i < 10; ++i) {
        bus.publish(oep::runtime::EventType::ObjectCreated, "obj-" + std::to_string(i), "");
    }
    const auto events = bus.recent_events();
    check(events.size() == 3, "the log never grows past max_retained");
    check(events.front().subject_id() == "obj-7" && events.back().subject_id() == "obj-9",
          "only the most recently published events survive retention trimming");
    check(bus.published_count() == 10, "published_count still reflects everything ever published, not just retained");
}

void test_to_string_covers_every_event_type() {
    check(oep::runtime::to_string(oep::runtime::EventType::ObjectCreated) == "ObjectCreated", "ObjectCreated name");
    check(oep::runtime::to_string(oep::runtime::EventType::PackageInstallFailed) == "PackageInstallFailed",
          "PackageInstallFailed name");
    check(oep::runtime::to_string(oep::runtime::EventType::DependencyResolutionCompleted) ==
              "DependencyResolutionCompleted",
          "DependencyResolutionCompleted name");
}

// ---------------------------------------------------------------------
// RuntimeService: object/relationship/transaction sequencing + events
// ---------------------------------------------------------------------

void test_create_object_publishes_object_created_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "create_object");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto response = service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(
        oep::repository::ObjectType::Document, "Spec Sheet", "A test object", "tester", {}));

    check(response.success, "create_object succeeds through RuntimeService");
    check(!response.object.object_id.empty(), "the created object has an assigned id");
    check(events.published_count() == 1, "exactly one event is published for a successful create_object");

    const auto log = events.recent_events();
    check(log.size() == 1 && log[0].type() == oep::runtime::EventType::ObjectCreated,
          "the published event is ObjectCreated");
    check(log[0].subject_id() == response.object.object_id,
          "the published event's subject_id is the created object's id");
}

void test_failed_create_object_publishes_no_event(const std::filesystem::path& scratch_dir) {
    // No repository open -> FoundationRuntime::create_object fails.
    oep::runtime::FoundationRuntime runtime("0.1.0");
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto response = service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(
        oep::repository::ObjectType::Document, "Spec Sheet", "", "tester", {}));

    check(!response.success, "create_object fails when no repository is open");
    check(!response.error.empty(), "the failure carries a descriptive error, exactly as FoundationRuntime reports it");
    check(events.published_count() == 0, "no event is published for a failed operation");
}

void test_update_and_delete_object_publish_events(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "update_delete_object");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto created = service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(
        oep::repository::ObjectType::Document, "Original", "", "tester", {}));
    check(created.success, "setup: create_object succeeds");

    const auto updated = service.update_object(
        oep::runtime::RuntimeService::UpdateObjectRequest(created.object.object_id, "Renamed", "", "tester", {}));
    check(updated.success && updated.object.name == "Renamed", "update_object applies the new name");

    const auto deleted =
        service.delete_object(oep::runtime::RuntimeService::DeleteObjectRequest(created.object.object_id));
    check(deleted.success, "delete_object succeeds for an existing object");

    check(events.published_count() == 3, "create + update + delete each publish exactly one event");
    const auto log = events.recent_events();
    check(log[0].type() == oep::runtime::EventType::ObjectCreated, "event 1 is ObjectCreated");
    check(log[1].type() == oep::runtime::EventType::ObjectUpdated, "event 2 is ObjectUpdated");
    check(log[2].type() == oep::runtime::EventType::ObjectDeleted, "event 3 is ObjectDeleted");
}

// AP-DS-002: update_object_content replaces only `content`, preserving
// every other field, and participates in the same transaction/undo
// machinery as update_object.
void test_update_object_content_preserves_other_fields_and_publishes_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "update_object_content");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto created = service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(
        oep::repository::ObjectType::Diagram, "Wiring Diagram", "a description", "tester", {"harness"}));
    check(created.success, "setup: create_object succeeds");
    check(created.object.content.empty(), "a freshly created object has empty content");

    const auto updated = service.update_object_content(oep::runtime::RuntimeService::UpdateObjectContentRequest(
        created.object.object_id, R"({"nodes":[{"id":"n1","x":10,"y":20}]})"));
    check(updated.success, "update_object_content succeeds");
    check(updated.object.content == R"({"nodes":[{"id":"n1","x":10,"y":20}]})",
          "update_object_content applies the new content");
    check(updated.object.name == "Wiring Diagram" && updated.object.description == "a description" &&
              updated.object.author == "tester" && updated.object.tags.size() == 1 &&
              updated.object.tags[0] == "harness" && updated.object.object_type == oep::repository::ObjectType::Diagram,
          "update_object_content leaves name/description/author/tags/object_type unchanged");

    // A second update replaces (not appends to) the content.
    const auto replaced = service.update_object_content(
        oep::runtime::RuntimeService::UpdateObjectContentRequest(created.object.object_id, "{}"));
    check(replaced.success && replaced.object.content == "{}", "a second update_object_content replaces the prior content, not appends");

    check(events.published_count() == 3, "create + two content updates each publish exactly one ObjectUpdated/ObjectCreated event");
    const auto log = events.recent_events();
    check(log[1].type() == oep::runtime::EventType::ObjectUpdated && log[2].type() == oep::runtime::EventType::ObjectUpdated,
          "both content updates publish ObjectUpdated, matching update_object's own event type");
}

void test_update_object_content_fails_for_unknown_object(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "update_object_content_missing");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto result = service.update_object_content(
        oep::runtime::RuntimeService::UpdateObjectContentRequest("11111111-1111-4111-8111-111111111111", "{}"));
    check(!result.success, "update_object_content fails for an object_id that does not exist");
    check(!result.error.empty(), "the failure carries a descriptive error");
    check(events.published_count() == 0, "no event is published for a failed content update");
}

void test_relationship_mutations_publish_events(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "relationship_events");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto source = service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(
        oep::repository::ObjectType::Document, "Source", "", "tester", {}));
    const auto target = service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(
        oep::repository::ObjectType::Document, "Target", "", "tester", {}));
    check(source.success && target.success, "setup: both endpoint objects are created");

    const auto created = service.create_relationship(oep::runtime::RuntimeService::CreateRelationshipRequest(
        source.object.object_id, target.object.object_id, oep::repository::RelationshipType::References, "tester",
        ""));
    check(created.success, "create_relationship succeeds through RuntimeService");

    const auto updated = service.update_relationship(oep::runtime::RuntimeService::UpdateRelationshipRequest(
        created.relationship.relationship_id, "tester", "updated description"));
    check(updated.success, "update_relationship succeeds through RuntimeService");

    const auto deleted = service.delete_relationship(
        oep::runtime::RuntimeService::DeleteRelationshipRequest(created.relationship.relationship_id));
    check(deleted.success, "delete_relationship succeeds through RuntimeService");

    // 2 ObjectCreated (source, target) + Created/Updated/Deleted for the relationship.
    check(events.published_count() == 5, "every successful mutation publishes exactly one event");
    const auto log = events.recent_events();
    check(log[2].type() == oep::runtime::EventType::RelationshipCreated, "event 3 is RelationshipCreated");
    check(log[3].type() == oep::runtime::EventType::RelationshipUpdated, "event 4 is RelationshipUpdated");
    check(log[4].type() == oep::runtime::EventType::RelationshipDeleted, "event 5 is RelationshipDeleted");
}

void test_transactions_publish_events_in_sequence(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "transaction_events");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    check(service.begin_transaction().success, "begin_transaction succeeds");
    check(service.create_object(oep::runtime::RuntimeService::CreateObjectRequest(
                                     oep::repository::ObjectType::Document, "In Tx", "", "tester", {}))
              .success,
          "create_object succeeds inside the transaction");
    check(service.commit_transaction().success, "commit_transaction succeeds");

    const auto log = events.recent_events();
    check(log.size() == 3, "begin + create + commit each publish exactly one event");
    check(log[0].type() == oep::runtime::EventType::TransactionBegun, "event 1 is TransactionBegun");
    check(log[1].type() == oep::runtime::EventType::ObjectCreated, "event 2 is ObjectCreated");
    check(log[2].type() == oep::runtime::EventType::TransactionCommitted, "event 3 is TransactionCommitted");
}

void test_rollback_publishes_rolled_back_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "rollback_events");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    check(service.begin_transaction().success, "begin_transaction succeeds");
    check(service.rollback_transaction().success, "rollback_transaction succeeds on an empty transaction");

    const auto log = events.recent_events();
    check(log.size() == 2 && log[1].type() == oep::runtime::EventType::TransactionRolledBack,
          "rollback publishes TransactionRolledBack");
}

// RuntimeService must not reimplement business logic: this is the
// permanent regression guard for that constraint. It asserts that
// RuntimeService::create_object rejecting an operation produces the
// EXACT SAME error message FoundationRuntime::create_object itself
// would -- if RuntimeService ever started reinterpreting or
// rewrapping errors, this would catch it.
void test_runtime_service_preserves_foundation_runtime_error_text(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "error_passthrough_direct");
    build_repository(scratch_dir / "error_passthrough_via_service");
    oep::runtime::FoundationRuntime direct = open_runtime(scratch_dir / "error_passthrough_direct");
    oep::runtime::FoundationRuntime via_service = open_runtime(scratch_dir / "error_passthrough_via_service");

    const oep::runtime::RuntimeResult direct_result = direct.delete_object("does-not-exist");

    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(via_service, events));
    const auto service_response =
        service.delete_object(oep::runtime::RuntimeService::DeleteObjectRequest("does-not-exist"));

    check(!direct_result.success && !service_response.success, "both direct and RuntimeService calls fail");
    check(direct_result.error == service_response.error,
          "RuntimeService passes FoundationRuntime's error text through byte-for-byte, unmodified");
    check(events.published_count() == 0, "the failed delete publishes no event");
}

// ---------------------------------------------------------------------
// RuntimeService: Uninstall/Update (WP-REP-007) sequencing + events
// ---------------------------------------------------------------------
//
// Full end-to-end uninstall/update scenarios (an actually-installed
// package, blocking dependents, broken updates) are covered against
// FoundationRuntime directly in
// tests/runtime/package_lifecycle_integration_tests.cpp, since they
// require building synthetic .oep archives. These tests only confirm
// RuntimeService's own sequencing contract: it calls straight through
// to FoundationRuntime (error text preserved verbatim) and publishes
// exactly the right event on success / nothing on failure.

void test_uninstall_impact_analysis_publishes_no_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninstall_impact_no_event");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    const auto report =
        service.analyze_uninstall_impact(oep::runtime::RuntimeService::AnalyzeUninstallImpactRequest("com.example.never"));
    check(report.success && !report.found, "analyzing an uninstalled package's impact reports found == false");
    check(events.published_count() == 0, "a read-only impact analysis publishes no event");
}

void test_uninstall_failure_matches_foundation_runtime_and_publishes_no_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "uninstall_failure_passthrough");
    oep::runtime::FoundationRuntime direct = open_runtime(root);
    const oep::runtime::RuntimeUninstallResult direct_result = direct.uninstall_package("com.example.never");

    const std::filesystem::path root2 = build_repository(scratch_dir / "uninstall_failure_passthrough_2");
    oep::runtime::FoundationRuntime via_runtime = open_runtime(root2);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(via_runtime, events));
    const auto response =
        service.uninstall_package(oep::runtime::RuntimeService::UninstallPackageRequest("com.example.never"));

    check(!direct_result.success && !response.success, "both calls fail for an uninstalled package");
    check(direct_result.error == response.error,
          "RuntimeService passes FoundationRuntime's uninstall error text through unmodified");
    check(events.published_count() == 0, "a failed uninstall publishes no event");
}

void test_update_impact_analysis_publishes_no_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "update_impact_no_event");
    oep::runtime::FoundationRuntime runtime = open_runtime(root);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(runtime, events));

    // A nonexistent archive path -- analyze_update_impact fails at
    // extraction, which is enough to confirm the sequencing/event
    // contract without needing a real archive.
    const auto report = service.analyze_update_impact(
        oep::runtime::RuntimeService::AnalyzeUpdateImpactRequest(root / "does-not-exist.oep"));
    check(!report.success, "analyzing update impact for an unreadable archive fails");
    check(events.published_count() == 0, "a read-only (or failed) impact analysis publishes no event");
}

void test_update_failure_matches_foundation_runtime_and_publishes_no_event(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path missing_archive = scratch_dir / "shared-does-not-exist.oep";

    const std::filesystem::path root = build_repository(scratch_dir / "update_failure_passthrough");
    oep::runtime::FoundationRuntime direct = open_runtime(root);
    const oep::runtime::RuntimeUpdateResult direct_result = direct.update_package(missing_archive);

    const std::filesystem::path root2 = build_repository(scratch_dir / "update_failure_passthrough_2");
    oep::runtime::FoundationRuntime via_runtime = open_runtime(root2);
    oep::runtime::EventBus events;
    oep::runtime::RuntimeService service(oep::runtime::RuntimeContext(via_runtime, events));
    const auto response =
        service.update_package(oep::runtime::RuntimeService::UpdatePackageRequest(missing_archive));

    check(!direct_result.success && !response.success, "both calls fail for an unreadable archive");
    check(direct_result.error == response.error,
          "RuntimeService passes FoundationRuntime's update error text through unmodified");
    check(events.published_count() == 0, "a failed update publishes no event");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_runtime_service_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_event_bus_assigns_ascending_sequence_numbers();
    test_event_bus_recent_events_respects_limit();
    test_event_bus_enforces_retention_bound();
    test_to_string_covers_every_event_type();
    test_create_object_publishes_object_created_event(scratch_dir);
    test_failed_create_object_publishes_no_event(scratch_dir);
    test_update_and_delete_object_publish_events(scratch_dir);
    test_update_object_content_preserves_other_fields_and_publishes_event(scratch_dir);
    test_update_object_content_fails_for_unknown_object(scratch_dir);
    test_relationship_mutations_publish_events(scratch_dir);
    test_transactions_publish_events_in_sequence(scratch_dir);
    test_rollback_publishes_rolled_back_event(scratch_dir);
    test_runtime_service_preserves_foundation_runtime_error_text(scratch_dir);
    test_uninstall_impact_analysis_publishes_no_event(scratch_dir);
    test_uninstall_failure_matches_foundation_runtime_and_publishes_no_event(scratch_dir);
    test_update_impact_analysis_publishes_no_event(scratch_dir);
    test_update_failure_matches_foundation_runtime_and_publishes_no_event(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All runtime_service tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " runtime_service test(s) failed.\n";
    return 1;
}
