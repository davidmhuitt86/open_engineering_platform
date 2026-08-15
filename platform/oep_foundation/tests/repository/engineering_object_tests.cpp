#include "oep/repository/engineering_object.hpp"
#include "oep/repository/object_store.hpp"

#include <chrono>
#include <filesystem>
#include <iostream>
#include <string>
#include <thread>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

oep::repository::EngineeringObject sample_object() {
    oep::repository::EngineeringObject object;
    object.object_type = oep::repository::ObjectType::Component;
    object.name = "Ignition Coil";
    object.description = "Sample component";
    object.version = "1.0.0";
    object.author = "Test Author";
    object.tags = {"electrical", "sample"};
    return object;
}

void test_create_assigns_id_and_timestamps(const oep::repository::ObjectStore& store) {
    const oep::repository::LoadObjectResult result = store.create(sample_object());
    check(result.success, "create succeeds for a valid object");
    check(!result.object.object_id.empty(), "create assigns an objectId");
    check(!result.object.created_utc.empty(), "create assigns createdUtc");
    check(!result.object.last_modified_utc.empty(), "create assigns lastModifiedUtc");
}

void test_load_round_trips(const oep::repository::ObjectStore& store) {
    const oep::repository::LoadObjectResult created = store.create(sample_object());
    check(created.success, "create succeeds before load test");

    const oep::repository::LoadObjectResult loaded = store.load(created.object.object_id);
    check(loaded.success, "load succeeds for an existing object");
    check(loaded.object.object_id == created.object.object_id, "load preserves objectId");
    check(loaded.object.object_type == oep::repository::ObjectType::Component, "load preserves objectType");
    check(loaded.object.name == "Ignition Coil", "load preserves name");
    check(loaded.object.tags.size() == 2, "load preserves tags");
}

void test_load_missing_object_fails(const oep::repository::ObjectStore& store) {
    const oep::repository::LoadObjectResult result = store.load("00000000-0000-4000-8000-000000000000");
    check(!result.success, "load fails for a nonexistent objectId");
}

void test_update_preserves_immutable_fields(const oep::repository::ObjectStore& store) {
    const oep::repository::LoadObjectResult created = store.create(sample_object());
    check(created.success, "create succeeds before update test");

    oep::repository::EngineeringObject updated = created.object;
    updated.object_type = oep::repository::ObjectType::Document; // attempt to change; must be ignored
    updated.name = "Ignition Coil (Rev B)";
    updated.created_utc = "2000-01-01T00:00:00Z"; // attempt to change; must be ignored

    // Timestamps have one-second resolution; without this wait, a fast
    // machine performs create and update within the same second and
    // lastModifiedUtc "refreshes" to an identical value, failing the
    // final check below spuriously.
    std::this_thread::sleep_for(std::chrono::milliseconds(1100));

    const oep::repository::ObjectResult update_result = store.update(updated);
    check(update_result.success, "update succeeds for an existing object");

    const oep::repository::LoadObjectResult reloaded = store.load(created.object.object_id);
    check(reloaded.success, "load succeeds after update");
    check(reloaded.object.name == "Ignition Coil (Rev B)", "update applies the new name");
    check(reloaded.object.object_type == oep::repository::ObjectType::Component,
          "update preserves the original objectType");
    check(reloaded.object.created_utc == created.object.created_utc, "update preserves the original createdUtc");
    check(reloaded.object.last_modified_utc != created.object.last_modified_utc,
          "update refreshes lastModifiedUtc");
}

void test_remove_deletes_object(const oep::repository::ObjectStore& store) {
    const oep::repository::LoadObjectResult created = store.create(sample_object());
    check(created.success, "create succeeds before remove test");

    const oep::repository::ObjectResult remove_result = store.remove(created.object.object_id);
    check(remove_result.success, "remove succeeds for an existing object");

    const oep::repository::LoadObjectResult reloaded = store.load(created.object.object_id);
    check(!reloaded.success, "load fails after the object has been removed");
}

void test_validation_rejects_missing_name() {
    oep::repository::EngineeringObject object = sample_object();
    object.object_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    object.created_utc = "2026-01-01T00:00:00Z";
    object.last_modified_utc = "2026-01-01T00:00:00Z";
    object.name = "";

    const std::vector<std::string> errors = oep::repository::validate_object(object);
    check(!errors.empty(), "validate_object rejects an object with no name");
}

void test_validation_rejects_bad_object_id() {
    oep::repository::EngineeringObject object = sample_object();
    object.object_id = "not-a-uuid";
    object.created_utc = "2026-01-01T00:00:00Z";
    object.last_modified_utc = "2026-01-01T00:00:00Z";

    const std::vector<std::string> errors = oep::repository::validate_object(object);
    check(!errors.empty(), "validate_object rejects a malformed objectId");
}

void test_create_rejects_invalid_object(const oep::repository::ObjectStore& store) {
    oep::repository::EngineeringObject object = sample_object();
    object.name = ""; // required

    const oep::repository::LoadObjectResult result = store.create(object);
    check(!result.success, "create refuses to save an invalid object");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_engineering_object_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    const oep::repository::ObjectStore store(scratch_dir / "objects",
                                              oep::repository::AuditStore(scratch_dir / "audit"));

    test_create_assigns_id_and_timestamps(store);
    test_load_round_trips(store);
    test_load_missing_object_fails(store);
    test_update_preserves_immutable_fields(store);
    test_remove_deletes_object(store);
    test_validation_rejects_missing_name();
    test_validation_rejects_bad_object_id();
    test_create_rejects_invalid_object(store);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All Engineering Object tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " Engineering Object test(s) failed.\n";
    return 1;
}
