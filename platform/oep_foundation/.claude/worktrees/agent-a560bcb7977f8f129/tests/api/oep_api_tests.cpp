#include "oep/api/oep_api.h"

#include "oep/repository/audit_store.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship_store.hpp"

#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

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
    metadata.repository_id = "1b9e1b02-e845-482a-b299-1e15ffe3932b";
    metadata.repository_name = "my-workshop";
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = "0.1.0";
    metadata.template_version = "1.0";
    metadata.created_utc = "2026-01-01T00:00:00Z";
    oep::repository::save_metadata(root / "repository.json", metadata);

    return root;
}

// Builds a repository with the same metadata as build_repository, plus two
// Engineering Objects (one Component with tags, one Document) and one
// Relationship between them, for enumeration/statistics tests.
std::filesystem::path build_populated_repository(const std::filesystem::path& root) {
    build_repository(root);

    oep::repository::AuditStore audit(root / "repository" / "audit");
    oep::repository::ObjectStore objects(root / "repository" / "objects", audit);
    oep::repository::RelationshipStore relationships(root / "repository" / "relationships", objects, audit);

    oep::repository::EngineeringObject coil;
    coil.object_type = oep::repository::ObjectType::Component;
    coil.name = "Ignition Coil";
    coil.description = "Generates spark";
    coil.author = "Jane";
    coil.tags = {"electrical", "ignition"};
    const oep::repository::LoadObjectResult coil_created = objects.create(coil);

    oep::repository::EngineeringObject manual;
    manual.object_type = oep::repository::ObjectType::Document;
    manual.name = "Manual";
    manual.author = "Jane";
    const oep::repository::LoadObjectResult manual_created = objects.create(manual);

    oep::repository::Relationship relationship;
    relationship.source_object_id = manual_created.object.object_id;
    relationship.target_object_id = coil_created.object.object_id;
    relationship.relationship_type = oep::repository::RelationshipType::Documents;
    relationships.create(relationship);

    return root;
}

void append_u16(std::vector<std::uint8_t>& out, std::uint16_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}
void append_u32(std::vector<std::uint8_t>& out, std::uint32_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}
void append_bytes(std::vector<std::uint8_t>& out, const std::string& text) {
    out.insert(out.end(), text.begin(), text.end());
}

// Same minimal, Stored-only ZIP builder as tests/installer/*_tests.cpp —
// duplicated per this codebase's own self-contained-test-file convention.
std::vector<std::uint8_t> build_stored_zip(const std::vector<std::pair<std::string, std::string>>& entries) {
    std::vector<std::uint8_t> out;
    std::vector<std::uint32_t> local_header_offsets;
    for (const auto& [name, content] : entries) {
        local_header_offsets.push_back(static_cast<std::uint32_t>(out.size()));
        append_u32(out, 0x04034b50);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_bytes(out, name);
        append_bytes(out, content);
    }
    const std::uint32_t central_directory_start = static_cast<std::uint32_t>(out.size());
    for (std::size_t i = 0; i < entries.size(); ++i) {
        const auto& [name, content] = entries[i];
        append_u32(out, 0x02014b50);
        append_u16(out, 20);
        append_u16(out, 20);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u16(out, 0);
        append_u32(out, 0);
        append_u32(out, local_header_offsets[i]);
        append_bytes(out, name);
    }
    const std::uint32_t central_directory_size = static_cast<std::uint32_t>(out.size()) - central_directory_start;
    append_u32(out, 0x06054b50);
    append_u16(out, 0);
    append_u16(out, 0);
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u32(out, central_directory_size);
    append_u32(out, central_directory_start);
    append_u16(out, 0);
    return out;
}

// A minimal valid .oep archive with one Component ("API Harness") and no
// relationships, for the Package Installation / Lifecycle Query tests.
std::filesystem::path write_demo_archive(const std::filesystem::path& scratch_dir) {
    const std::string manifest =
        R"({"schemaVersion":"1.0","packageId":"com.oep.demo.capi","version":"1.0.0",)"
        R"("publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
        R"("title":"C API Demo Package","summary":"s","description":"d","category":"demonstration",)"
        R"("engineeringDomains":["Automotive"],"license":{},"dependencies":[],"capabilities":[],)"
        R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
    const std::string object_a = R"({"objectId":"aaaaaaaa-3333-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"API Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";

    const std::filesystem::path path = scratch_dir / "capi-demo.oep";
    const std::vector<std::uint8_t> bytes = build_stored_zip({
        {"manifest/package.json", manifest},
        {"fragment/objects/a.json", object_a},
    });
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

void test_version_reporting() {
    check(std::string(oep_foundation_version()) == "0.1.0", "oep_foundation_version reports the Foundation version");
    check(oep_api_version() == OEP_API_VERSION, "oep_api_version reports OEP_API_VERSION");
    check(oep_abi_version() == OEP_ABI_VERSION, "oep_abi_version reports OEP_ABI_VERSION");
}

void test_state_to_string_is_deterministic() {
    check(std::string(oep_runtime_state_to_string(OEP_STATE_UNINITIALIZED)) == "Uninitialized",
          "OEP_STATE_UNINITIALIZED stringifies correctly");
    check(std::string(oep_runtime_state_to_string(OEP_STATE_REPOSITORY_OPEN)) == "RepositoryOpen",
          "OEP_STATE_REPOSITORY_OPEN stringifies correctly");
    check(std::string(oep_runtime_state_to_string(OEP_STATE_REPOSITORY_OPEN)) ==
              std::string(oep_runtime_state_to_string(OEP_STATE_REPOSITORY_OPEN)),
          "state_to_string is deterministic across repeated calls");
}

void test_error_code_and_category_strings() {
    check(std::string(oep_error_code_to_string(OEP_ERROR_INVALID_STATE)) == "InvalidState",
          "OEP_ERROR_INVALID_STATE stringifies correctly");
    check(std::string(oep_error_category_to_string(OEP_ERROR_CATEGORY_STATE)) == "State",
          "OEP_ERROR_CATEGORY_STATE stringifies correctly");
}

void test_create_rejects_null_version() {
    OEP_Runtime runtime = oep_runtime_create(nullptr);
    check(runtime == nullptr, "oep_runtime_create returns NULL for a NULL foundation_version");
}

void test_destroy_is_null_safe() {
    oep_runtime_destroy(nullptr); // must not crash
    check(true, "oep_runtime_destroy(NULL) does not crash");
}

void test_null_handle_calls_return_invalid_argument() {
    const oep_result_t init_result = oep_runtime_initialize(nullptr);
    check(!init_result.success && init_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_runtime_initialize(NULL) fails with OEP_ERROR_INVALID_ARGUMENT");
    check(init_result.error_category == OEP_ERROR_CATEGORY_VALIDATION,
          "a NULL-handle failure reports OEP_ERROR_CATEGORY_VALIDATION");
    check(std::strlen(init_result.error_message) > 0, "a failed result carries a non-empty error message");

    check(oep_runtime_get_state(nullptr) == OEP_STATE_UNINITIALIZED,
          "oep_runtime_get_state(NULL) returns OEP_STATE_UNINITIALIZED rather than crashing");
}

void test_full_lifecycle(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "lifecycle");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    check(runtime != nullptr, "oep_runtime_create succeeds for a valid foundation_version");
    check(oep_runtime_get_state(runtime) == OEP_STATE_UNINITIALIZED, "a fresh handle starts Uninitialized");

    const oep_result_t open_before_init = oep_runtime_open_repository(runtime, root.string().c_str());
    check(!open_before_init.success && open_before_init.error_code == OEP_ERROR_INVALID_STATE,
          "opening a repository before initialize() fails with OEP_ERROR_INVALID_STATE");

    const oep_result_t init_result = oep_runtime_initialize(runtime);
    check(init_result.success, "oep_runtime_initialize succeeds from Uninitialized");
    check(oep_runtime_get_state(runtime) == OEP_STATE_INITIALIZED, "initialize transitions to Initialized");

    const oep_result_t reinit_result = oep_runtime_initialize(runtime);
    check(!reinit_result.success && reinit_result.error_code == OEP_ERROR_INVALID_STATE,
          "re-initializing an already-initialized Runtime fails with OEP_ERROR_INVALID_STATE");

    const oep_result_t open_result = oep_runtime_open_repository(runtime, root.string().c_str());
    check(open_result.success, "oep_runtime_open_repository succeeds for a valid repository");
    check(oep_runtime_get_state(runtime) == OEP_STATE_REPOSITORY_OPEN, "open_repository transitions to RepositoryOpen");

    oep_repository_status_t status;
    const oep_result_t status_result = oep_runtime_get_repository_status(runtime, &status);
    check(status_result.success, "oep_runtime_get_repository_status succeeds while a repository is open");
    check(status.repository_open != 0, "the status reports repository_open");
    check(std::string(status.repository_id) == "1b9e1b02-e845-482a-b299-1e15ffe3932b",
          "the status reports the correct repository_id");
    check(std::string(status.repository_name) == "my-workshop", "the status reports the correct repository_name");
    check(status.loaded_package_count == 0, "the status reports zero loaded packages for an empty repository");

    const oep_result_t close_result = oep_runtime_close_repository(runtime);
    check(close_result.success, "oep_runtime_close_repository succeeds while a repository is open");
    check(oep_runtime_get_state(runtime) == OEP_STATE_REPOSITORY_CLOSED, "close_repository transitions to RepositoryClosed");

    const oep_result_t close_again_result = oep_runtime_close_repository(runtime);
    check(!close_again_result.success && close_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "closing an already-closed repository fails with OEP_ERROR_INVALID_STATE");

    const oep_result_t shutdown_result = oep_runtime_shutdown(runtime);
    check(shutdown_result.success, "oep_runtime_shutdown succeeds");
    check(oep_runtime_get_state(runtime) == OEP_STATE_SHUTDOWN, "shutdown transitions to Shutdown");

    const oep_result_t shutdown_again_result = oep_runtime_shutdown(runtime);
    check(!shutdown_again_result.success && shutdown_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "shutting down an already-shut-down Runtime fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

void test_open_repository_reports_not_found(const std::filesystem::path& scratch_dir) {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    const std::filesystem::path missing = scratch_dir / "does-not-exist";
    const oep_result_t result = oep_runtime_open_repository(runtime, missing.string().c_str());
    check(!result.success, "opening a nonexistent repository fails");
    check(result.error_code == OEP_ERROR_NOT_FOUND, "opening a nonexistent repository reports OEP_ERROR_NOT_FOUND");
    check(result.error_category == OEP_ERROR_CATEGORY_IO, "a NotFound error reports OEP_ERROR_CATEGORY_IO");

    oep_runtime_destroy(runtime);
}

void test_open_repository_rejects_null_path() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    const oep_result_t result = oep_runtime_open_repository(runtime, nullptr);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "opening with a NULL repository_path fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_repository_status_fails_without_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_repository_status_t status;
    status.repository_open = 1; // deliberately non-zero, to confirm the API resets it
    const oep_result_t result = oep_runtime_get_repository_status(runtime, &status);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_STATE,
          "getting repository status without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(status.repository_open == 0, "a failed status call zero-initializes the output structure");

    oep_runtime_destroy(runtime);
}

void test_object_enumeration(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "enumeration");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    int count = -1;
    const oep_result_t count_result = oep_object_store_get_count(runtime, &count);
    check(count_result.success, "oep_object_store_get_count succeeds while a repository is open");
    check(count == 2, "the object count reflects both created objects");

    oep_object_list_t list;
    const oep_result_t list_result = oep_object_store_list(runtime, &list);
    check(list_result.success, "oep_object_store_list succeeds while a repository is open");
    check(list.count == 2, "the enumerated list contains both objects");
    check(list.items != nullptr, "a non-empty list has a non-NULL items array");

    if (list.count == 2) {
        check(std::string(list.items[0].object_id) < std::string(list.items[1].object_id),
              "the enumerated list is sorted deterministically by object_id");
    }

    bool found_coil = false;
    for (int i = 0; i < list.count; ++i) {
        if (std::string(list.items[i].name) == "Ignition Coil") {
            found_coil = true;
            check(list.items[i].object_type == OEP_OBJECT_TYPE_COMPONENT,
                  "the enumerated Ignition Coil object reports OEP_OBJECT_TYPE_COMPONENT");
            check(std::string(list.items[i].author) == "Jane", "the enumerated object reports the correct author");
            check(list.items[i].tag_count == 2, "the enumerated object reports both tags");
        }
    }
    check(found_coil, "the enumerated list includes the Ignition Coil object");

    // Repeating enumeration produces the same order (determinism across calls).
    oep_object_list_t second_list;
    oep_object_store_list(runtime, &second_list);
    bool same_order = second_list.count == list.count;
    for (int i = 0; same_order && i < list.count; ++i) {
        same_order = std::string(list.items[i].object_id) == std::string(second_list.items[i].object_id);
    }
    check(same_order, "repeated enumeration produces the same deterministic order");

    oep_object_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_object_list_release zeroes the released list");
    oep_object_list_release(&second_list);

    // Releasing an already-released (zeroed) list is a safe no-op.
    oep_object_list_release(&list);
    check(true, "releasing an already-released list does not crash");

    oep_object_list_release(nullptr);
    check(true, "oep_object_list_release(NULL) does not crash");

    oep_runtime_destroy(runtime);
}

void test_object_lookup_by_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "lookup");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t list;
    oep_object_store_list(runtime, &list);
    check(list.count == 2, "the fixture repository has exactly two objects for the lookup test");

    if (list.count == 2) {
        oep_object_info_t looked_up;
        const oep_result_t lookup_result = oep_object_store_get_by_id(runtime, list.items[0].object_id, &looked_up);
        check(lookup_result.success, "looking up an existing object by ID succeeds");
        check(std::string(looked_up.object_id) == std::string(list.items[0].object_id),
              "the looked-up object has the requested object_id");
        check(std::string(looked_up.name) == std::string(list.items[0].name),
              "the looked-up object has the requested name");
    }
    oep_object_list_release(&list);

    oep_object_info_t missing;
    const oep_result_t missing_result =
        oep_object_store_get_by_id(runtime, "00000000-0000-4000-8000-000000000000", &missing);
    check(!missing_result.success && missing_result.error_code == OEP_ERROR_NOT_FOUND,
          "looking up a nonexistent object ID fails with OEP_ERROR_NOT_FOUND");
    check(std::string(missing.object_id).empty(), "a failed lookup zero-initializes the output structure");

    const oep_result_t null_id_result = oep_object_store_get_by_id(runtime, nullptr, &missing);
    check(!null_id_result.success && null_id_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "looking up with a NULL object_id fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_object_enumeration_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    int count = -1;
    const oep_result_t count_result = oep_object_store_get_count(runtime, &count);
    check(!count_result.success && count_result.error_code == OEP_ERROR_INVALID_STATE,
          "getting the object count without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(count == 0, "a failed count call resets out_count to zero");

    oep_object_list_t list;
    const oep_result_t list_result = oep_object_store_list(runtime, &list);
    check(!list_result.success && list_result.error_code == OEP_ERROR_INVALID_STATE,
          "listing objects without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(list.items == nullptr && list.count == 0, "a failed list call is zero-initialized");

    oep_runtime_destroy(runtime);
}

void test_repository_statistics(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "statistics");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_repository_statistics_t statistics;
    const oep_result_t statistics_result = oep_runtime_get_repository_statistics(runtime, &statistics);
    check(statistics_result.success, "oep_runtime_get_repository_statistics succeeds while a repository is open");
    check(std::string(statistics.repository_id) == "1b9e1b02-e845-482a-b299-1e15ffe3932b",
          "statistics report the correct repository_id");
    check(std::string(statistics.repository_name) == "my-workshop", "statistics report the correct repository_name");
    check(statistics.total_object_count == 2, "statistics report the correct total object count");
    check(statistics.object_count_by_type[OEP_OBJECT_TYPE_COMPONENT] == 1,
          "statistics report exactly one Component object");
    check(statistics.object_count_by_type[OEP_OBJECT_TYPE_DOCUMENT] == 1,
          "statistics report exactly one Document object");
    check(statistics.object_count_by_type[OEP_OBJECT_TYPE_DIAGRAM] == 0,
          "statistics report zero for an object type not present in the repository");
    check(statistics.relationship_count == 1, "statistics report the correct relationship count");
    check(statistics.package_count == 0, "statistics report zero packages for a package-free repository");

    oep_runtime_destroy(runtime);
}

void test_repository_statistics_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_repository_statistics_t statistics;
    statistics.total_object_count = 99; // deliberately nonzero, to confirm the API resets it
    const oep_result_t result = oep_runtime_get_repository_statistics(runtime, &statistics);
    check(!result.success && result.error_code == OEP_ERROR_INVALID_STATE,
          "getting repository statistics without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(statistics.total_object_count == 0, "a failed statistics call zero-initializes the output structure");

    oep_runtime_destroy(runtime);
}

void test_object_type_to_string() {
    check(std::string(oep_object_type_to_string(OEP_OBJECT_TYPE_COMPONENT)) == "Component",
          "OEP_OBJECT_TYPE_COMPONENT stringifies correctly");
    check(std::string(oep_object_type_to_string(OEP_OBJECT_TYPE_DOCUMENT)) == "Document",
          "OEP_OBJECT_TYPE_DOCUMENT stringifies correctly");
}

void test_relationship_enumeration(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "relationship-enumeration");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    int count = -1;
    const oep_result_t count_result = oep_relationship_store_get_count(runtime, &count);
    check(count_result.success, "oep_relationship_store_get_count succeeds while a repository is open");
    check(count == 1, "the relationship count reflects the one created relationship");

    oep_relationship_list_t list;
    const oep_result_t list_result = oep_relationship_store_list(runtime, &list);
    check(list_result.success, "oep_relationship_store_list succeeds while a repository is open");
    check(list.count == 1, "the enumerated list contains the one relationship");
    check(list.items != nullptr, "a non-empty list has a non-NULL items array");

    if (list.count == 1) {
        check(list.items[0].relationship_type == OEP_RELATIONSHIP_TYPE_DOCUMENTS,
              "the enumerated relationship reports OEP_RELATIONSHIP_TYPE_DOCUMENTS");
        check(std::strlen(list.items[0].source_object_id) == 36, "the relationship reports a source_object_id");
        check(std::strlen(list.items[0].target_object_id) == 36, "the relationship reports a target_object_id");
    }

    // Repeated enumeration produces the same deterministic order.
    oep_relationship_list_t second_list;
    oep_relationship_store_list(runtime, &second_list);
    bool same_order = second_list.count == list.count;
    for (int i = 0; same_order && i < list.count; ++i) {
        same_order = std::string(list.items[i].relationship_id) == std::string(second_list.items[i].relationship_id);
    }
    check(same_order, "repeated relationship enumeration produces the same deterministic order");

    oep_relationship_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_relationship_list_release zeroes the released list");
    oep_relationship_list_release(&second_list);

    oep_relationship_list_release(&list); // already released; must be a safe no-op
    check(true, "releasing an already-released relationship list does not crash");
    oep_relationship_list_release(nullptr);
    check(true, "oep_relationship_list_release(NULL) does not crash");

    oep_runtime_destroy(runtime);
}

void test_relationship_lookup_by_id(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "relationship-lookup");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_relationship_list_t list;
    oep_relationship_store_list(runtime, &list);
    check(list.count == 1, "the fixture repository has exactly one relationship for the lookup test");

    if (list.count == 1) {
        oep_relationship_info_t looked_up;
        const oep_result_t lookup_result =
            oep_relationship_store_get_by_id(runtime, list.items[0].relationship_id, &looked_up);
        check(lookup_result.success, "looking up an existing relationship by ID succeeds");
        check(std::string(looked_up.relationship_id) == std::string(list.items[0].relationship_id),
              "the looked-up relationship has the requested relationship_id");
        check(std::string(looked_up.source_object_id) == std::string(list.items[0].source_object_id),
              "the looked-up relationship has the requested source_object_id");
    }
    oep_relationship_list_release(&list);

    oep_relationship_info_t missing;
    const oep_result_t missing_result =
        oep_relationship_store_get_by_id(runtime, "00000000-0000-4000-8000-000000000000", &missing);
    check(!missing_result.success && missing_result.error_code == OEP_ERROR_NOT_FOUND,
          "looking up a nonexistent relationship ID fails with OEP_ERROR_NOT_FOUND");
    check(std::string(missing.relationship_id).empty(), "a failed lookup zero-initializes the output structure");

    const oep_result_t null_id_result = oep_relationship_store_get_by_id(runtime, nullptr, &missing);
    check(!null_id_result.success && null_id_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "looking up with a NULL relationship_id fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_relationship_enumeration_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    int count = -1;
    const oep_result_t count_result = oep_relationship_store_get_count(runtime, &count);
    check(!count_result.success && count_result.error_code == OEP_ERROR_INVALID_STATE,
          "getting the relationship count without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(count == 0, "a failed count call resets out_count to zero");

    oep_relationship_list_t list;
    const oep_result_t list_result = oep_relationship_store_list(runtime, &list);
    check(!list_result.success && list_result.error_code == OEP_ERROR_INVALID_STATE,
          "listing relationships without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(list.items == nullptr && list.count == 0, "a failed list call is zero-initialized");

    oep_runtime_destroy(runtime);
}

void test_relationship_type_to_string() {
    check(std::string(oep_relationship_type_to_string(OEP_RELATIONSHIP_TYPE_DOCUMENTS)) == "Documents",
          "OEP_RELATIONSHIP_TYPE_DOCUMENTS stringifies correctly");
    check(std::string(oep_relationship_type_to_string(OEP_RELATIONSHIP_TYPE_REFERENCES)) == "References",
          "OEP_RELATIONSHIP_TYPE_REFERENCES stringifies correctly");
}

void test_match_location_to_string() {
    check(std::string(oep_match_location_to_string(OEP_MATCH_LOCATION_NAME)) == "Name",
          "OEP_MATCH_LOCATION_NAME stringifies correctly");
    check(std::string(oep_match_location_to_string(OEP_MATCH_LOCATION_TAGS)) == "Tags",
          "OEP_MATCH_LOCATION_TAGS stringifies correctly");
}

void test_search_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "search-objects");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_search_result_list_t list;
    const oep_result_t result = oep_search_objects(runtime, "coil", &list);
    check(result.success, "oep_search_objects succeeds for a matching query");
    check(list.count == 1, "searching for 'coil' finds exactly the Ignition Coil object");
    if (list.count == 1) {
        check(std::string(list.items[0].display_name) == "Ignition Coil",
              "the search result reports the correct display_name");
        check(list.items[0].object_type == OEP_OBJECT_TYPE_COMPONENT,
              "the search result reports the correct object_type");
        check(list.items[0].match_score > 0.0, "the search result reports a positive match_score");
    }
    oep_object_search_result_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_object_search_result_list_release zeroes the list");

    oep_object_search_result_list_t no_match_list;
    oep_search_objects(runtime, "zzz-nomatch", &no_match_list);
    check(no_match_list.count == 0, "searching for a nonexistent term finds no objects");
    oep_object_search_result_list_release(&no_match_list);

    oep_object_search_result_list_t empty_query_list;
    const oep_result_t empty_query_result = oep_search_objects(runtime, "", &empty_query_list);
    check(!empty_query_result.success, "searching with an empty query fails");

    const oep_result_t null_query_result = oep_search_objects(runtime, nullptr, &list);
    check(!null_query_result.success && null_query_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "searching with a NULL query fails with OEP_ERROR_INVALID_ARGUMENT");

    oep_runtime_destroy(runtime);
}

void test_search_relationships(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "search-relationships");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_relationship_search_result_list_t list;
    const oep_result_t result = oep_search_relationships(runtime, "documents", &list);
    check(result.success, "oep_search_relationships succeeds for a matching query");
    check(list.count == 1, "searching for 'documents' finds the one Documents relationship");
    if (list.count == 1) {
        check(list.items[0].relationship_type == OEP_RELATIONSHIP_TYPE_DOCUMENTS,
              "the search result reports the correct relationship_type");
    }
    oep_relationship_search_result_list_release(&list);
    check(list.items == nullptr && list.count == 0, "oep_relationship_search_result_list_release zeroes the list");

    oep_runtime_destroy(runtime);
}

void test_search_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "search-repository");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_repository_search_result_t result;
    const oep_result_t search_result = oep_search_repository(runtime, "jane", &result);
    check(search_result.success, "oep_search_repository succeeds for a matching query");
    check(result.objects.count >= 1, "searching 'jane' finds at least one object (both objects have author Jane)");
    check(result.relationships.count >= 0, "the relationships list is present, even if zero-length");
    oep_repository_search_result_release(&result);
    check(result.objects.items == nullptr && result.objects.count == 0,
          "oep_repository_search_result_release zeroes the objects list");
    check(result.relationships.items == nullptr && result.relationships.count == 0,
          "oep_repository_search_result_release zeroes the relationships list");

    oep_repository_search_result_release(nullptr);
    check(true, "oep_repository_search_result_release(NULL) does not crash");

    oep_runtime_destroy(runtime);
}

void test_search_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_object_search_result_list_t objects_list;
    const oep_result_t objects_result = oep_search_objects(runtime, "anything", &objects_list);
    check(!objects_result.success && objects_result.error_code == OEP_ERROR_INVALID_STATE,
          "searching objects without an open repository fails with OEP_ERROR_INVALID_STATE");
    check(objects_list.items == nullptr && objects_list.count == 0, "the failed search's list is zero-initialized");

    oep_repository_search_result_t repo_result;
    const oep_result_t repo_search_result = oep_search_repository(runtime, "anything", &repo_result);
    check(!repo_search_result.success && repo_search_result.error_code == OEP_ERROR_INVALID_STATE,
          "searching the repository without an open repository fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

// ---------------------------------------------------------------------
// Work Package 014: Object Mutation, Relationship Mutation,
// Transactions, Batch Mutation.
// ---------------------------------------------------------------------

void test_object_create_update_delete(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "object-mutation");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    const char* tags[2] = {"electrical", "ignition"};
    oep_object_info_t created;
    const oep_result_t create_result =
        oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "Ignition Coil", "Generates spark", "Jane", tags, 2,
                           &created);
    check(create_result.success, "oep_object_create succeeds for a valid Component");
    check(std::strlen(created.object_id) == 36, "the created object has a generated object_id");
    check(std::string(created.name) == "Ignition Coil", "the created object reports the given name");
    check(created.object_type == OEP_OBJECT_TYPE_COMPONENT, "the created object reports the given type");
    check(created.tag_count == 2, "the created object reports both tags");

    oep_object_info_t null_name_result;
    const oep_result_t null_name = oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, nullptr, "", "", nullptr, 0,
                                                       &null_name_result);
    check(!null_name.success && null_name.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_create fails with OEP_ERROR_INVALID_ARGUMENT for a NULL name");

    oep_object_info_t empty_name_result;
    const oep_result_t empty_name =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "", "", "", nullptr, 0, &empty_name_result);
    check(!empty_name.success && empty_name.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_create fails for an empty name via Foundation's own validation");

    oep_object_info_t updated;
    const oep_result_t update_result =
        oep_object_update(runtime, created.object_id, "Ignition Coil (Rev B)", "Updated", "Jane Doe", nullptr, 0,
                           &updated);
    check(update_result.success, "oep_object_update succeeds");
    check(std::string(updated.name) == "Ignition Coil (Rev B)", "the updated object reports the new name");
    check(std::string(updated.object_id) == std::string(created.object_id), "the updated object keeps its object_id");
    check(updated.object_type == OEP_OBJECT_TYPE_COMPONENT, "the updated object keeps its original object_type");
    check(updated.tag_count == 0, "the updated object reflects the new (empty) tag list");

    oep_object_info_t missing_update;
    const oep_result_t missing_update_result = oep_object_update(
        runtime, "00000000-0000-4000-8000-000000000000", "X", "", "", nullptr, 0, &missing_update);
    check(!missing_update_result.success && missing_update_result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_object_update fails with OEP_ERROR_NOT_FOUND for a nonexistent object_id");

    const oep_result_t delete_result = oep_object_delete(runtime, created.object_id);
    check(delete_result.success, "oep_object_delete succeeds");

    const oep_result_t double_delete_result = oep_object_delete(runtime, created.object_id);
    check(!double_delete_result.success && double_delete_result.error_code == OEP_ERROR_NOT_FOUND,
          "deleting the same object twice fails with OEP_ERROR_NOT_FOUND");

    const oep_result_t null_object_id_result = oep_object_delete(runtime, nullptr);
    check(!null_object_id_result.success && null_object_id_result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_object_delete fails with OEP_ERROR_INVALID_ARGUMENT for a NULL object_id");

    oep_runtime_destroy(runtime);
}

void test_object_mutation_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_object_info_t out_object;
    const oep_result_t create_result =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "X", "", "", nullptr, 0, &out_object);
    check(!create_result.success && create_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_object_create fails with OEP_ERROR_INVALID_STATE without an open repository");

    const oep_result_t delete_result = oep_object_delete(runtime, "00000000-0000-4000-8000-000000000000");
    check(!delete_result.success && delete_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_object_delete fails with OEP_ERROR_INVALID_STATE without an open repository");

    oep_runtime_destroy(runtime);
}

void test_relationship_create_update_delete(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "relationship-mutation");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects;
    oep_object_store_list(runtime, &objects);
    check(objects.count == 2, "the fixture repository has exactly two objects for relationship mutation tests");
    const std::string source_id = objects.count == 2 ? objects.items[0].object_id : "";
    const std::string target_id = objects.count == 2 ? objects.items[1].object_id : "";
    oep_object_list_release(&objects);

    oep_relationship_info_t created;
    const oep_result_t create_result =
        oep_relationship_create(runtime, source_id.c_str(), target_id.c_str(), OEP_RELATIONSHIP_TYPE_CONTAINS,
                                 "Jane", "a new relationship", &created);
    check(create_result.success, "oep_relationship_create succeeds for two existing objects");
    check(std::strlen(created.relationship_id) == 36, "the created relationship has a generated relationship_id");
    check(created.relationship_type == OEP_RELATIONSHIP_TYPE_CONTAINS, "the created relationship reports the given type");

    oep_relationship_info_t missing_source_result;
    const oep_result_t missing_source = oep_relationship_create(
        runtime, "00000000-0000-4000-8000-000000000000", target_id.c_str(), OEP_RELATIONSHIP_TYPE_REFERENCES, "", "",
        &missing_source_result);
    check(!missing_source.success && missing_source.error_code == OEP_ERROR_NOT_FOUND,
          "oep_relationship_create fails with OEP_ERROR_NOT_FOUND for a nonexistent source object");

    oep_relationship_info_t updated;
    const oep_result_t update_result =
        oep_relationship_update(runtime, created.relationship_id, "Jane Doe", "revised description", &updated);
    check(update_result.success, "oep_relationship_update succeeds");
    check(std::string(updated.author) == "Jane Doe", "the updated relationship reports the new author");
    check(updated.relationship_type == OEP_RELATIONSHIP_TYPE_CONTAINS,
          "the updated relationship keeps its original relationship_type");
    check(std::string(updated.source_object_id) == source_id,
          "the updated relationship keeps its original source_object_id");

    oep_relationship_info_t missing_update;
    const oep_result_t missing_update_result = oep_relationship_update(
        runtime, "00000000-0000-4000-8000-000000000000", "", "", &missing_update);
    check(!missing_update_result.success && missing_update_result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_relationship_update fails with OEP_ERROR_NOT_FOUND for a nonexistent relationship_id");

    const oep_result_t delete_result = oep_relationship_delete(runtime, created.relationship_id);
    check(delete_result.success, "oep_relationship_delete succeeds");

    const oep_result_t double_delete_result = oep_relationship_delete(runtime, created.relationship_id);
    check(!double_delete_result.success && double_delete_result.error_code == OEP_ERROR_NOT_FOUND,
          "deleting the same relationship twice fails with OEP_ERROR_NOT_FOUND");

    oep_runtime_destroy(runtime);
}

void test_transaction_commit(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "transaction-commit");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    check(!oep_transaction_is_active(runtime), "no transaction is active initially");

    const oep_result_t begin_result = oep_transaction_begin(runtime);
    check(begin_result.success, "oep_transaction_begin succeeds from RepositoryOpen");
    check(oep_transaction_is_active(runtime), "the transaction reports active after begin");

    const oep_result_t nested_begin_result = oep_transaction_begin(runtime);
    check(!nested_begin_result.success && nested_begin_result.error_code == OEP_ERROR_INVALID_STATE,
          "a nested oep_transaction_begin fails with OEP_ERROR_INVALID_STATE");

    oep_object_info_t created;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Committed Object", "", "", nullptr, 0, &created);

    const oep_result_t commit_result = oep_transaction_commit(runtime);
    check(commit_result.success, "oep_transaction_commit succeeds");
    check(!oep_transaction_is_active(runtime), "the transaction reports inactive after commit");

    oep_object_info_t looked_up;
    const oep_result_t lookup_result = oep_object_store_get_by_id(runtime, created.object_id, &looked_up);
    check(lookup_result.success, "the committed object still exists after commit");

    const oep_result_t commit_again_result = oep_transaction_commit(runtime);
    check(!commit_again_result.success && commit_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "committing with no active transaction fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

void test_transaction_rollback(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "transaction-rollback");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_info_t survivor;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Survivor", "", "", nullptr, 0, &survivor);

    oep_transaction_begin(runtime);

    oep_object_info_t doomed_object;
    const oep_result_t create_result =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Doomed", "", "", nullptr, 0, &doomed_object);
    check(create_result.success, "create inside a transaction succeeds and is visible immediately");

    oep_object_info_t updated_survivor;
    oep_object_update(runtime, survivor.object_id, "Survivor (Modified)", "", "", nullptr, 0, &updated_survivor);

    const oep_result_t rollback_result = oep_transaction_rollback(runtime);
    check(rollback_result.success, "oep_transaction_rollback succeeds");
    check(!oep_transaction_is_active(runtime), "the transaction reports inactive after rollback");

    oep_object_info_t missing_doomed;
    const oep_result_t doomed_lookup = oep_object_store_get_by_id(runtime, doomed_object.object_id, &missing_doomed);
    check(!doomed_lookup.success && doomed_lookup.error_code == OEP_ERROR_NOT_FOUND,
          "the object created inside the rolled-back transaction no longer exists");

    oep_object_info_t restored_survivor;
    const oep_result_t survivor_lookup =
        oep_object_store_get_by_id(runtime, survivor.object_id, &restored_survivor);
    check(survivor_lookup.success && std::string(restored_survivor.name) == "Survivor",
          "the object updated inside the rolled-back transaction is restored to its pre-transaction name");

    const oep_result_t rollback_again_result = oep_transaction_rollback(runtime);
    check(!rollback_again_result.success && rollback_again_result.error_code == OEP_ERROR_INVALID_STATE,
          "rolling back with no active transaction fails with OEP_ERROR_INVALID_STATE");

    oep_runtime_destroy(runtime);
}

void test_transaction_automatic_rollback_on_failure(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "transaction-auto-rollback");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_transaction_begin(runtime);

    oep_object_info_t first;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "First", "", "", nullptr, 0, &first);

    oep_object_info_t failed;
    const oep_result_t failing_create =
        oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "", "", "", nullptr, 0, &failed);
    check(!failing_create.success, "a create with an invalid empty name fails inside the transaction");
    check(!oep_transaction_is_active(runtime),
          "the transaction is automatically deactivated after the failure, per TASK-000029");

    oep_object_info_t missing_first;
    const oep_result_t first_lookup = oep_object_store_get_by_id(runtime, first.object_id, &missing_first);
    check(!first_lookup.success && first_lookup.error_code == OEP_ERROR_NOT_FOUND,
          "the successful create earlier in the transaction was automatically rolled back too");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 0, "the repository has zero objects after the automatic rollback");

    oep_runtime_destroy(runtime);
}

void test_transaction_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    const oep_result_t begin_result = oep_transaction_begin(runtime);
    check(!begin_result.success && begin_result.error_code == OEP_ERROR_INVALID_STATE,
          "oep_transaction_begin fails with OEP_ERROR_INVALID_STATE without an open repository");
    check(!oep_transaction_is_active(runtime), "oep_transaction_is_active(NULL-state runtime) reports inactive");

    oep_runtime_destroy(runtime);
}

void test_batch_create_objects(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "batch-create-objects");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_create_spec_t specs[3];
    specs[0] = {OEP_OBJECT_TYPE_DOCUMENT, "Batch A", "", "", nullptr, 0};
    specs[1] = {OEP_OBJECT_TYPE_COMPONENT, "Batch B", "", "", nullptr, 0};
    specs[2] = {OEP_OBJECT_TYPE_DOCUMENT, "Batch C", "", "", nullptr, 0};

    oep_batch_create_objects_result_t result;
    const oep_result_t call_result = oep_batch_create_objects(runtime, specs, 3, &result);
    check(call_result.success, "oep_batch_create_objects succeeds for three valid specs");
    check(result.success != 0, "the batch result itself reports success");
    check(result.failed_index == -1, "failed_index is -1 on a fully successful batch");
    check(result.created.count == 3, "three objects were created");
    check(std::string(result.created.items[0].name) == "Batch A",
          "the created list preserves execution order (index 0)");
    check(std::string(result.created.items[1].name) == "Batch B",
          "the created list preserves execution order (index 1)");
    check(std::string(result.created.items[2].name) == "Batch C",
          "the created list preserves execution order (index 2)");
    oep_batch_create_objects_result_release(&result);
    check(result.created.items == nullptr, "oep_batch_create_objects_result_release zeroes the created list");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 3, "all three batch-created objects are persisted");

    oep_runtime_destroy(runtime);
}

void test_batch_create_objects_rolls_back_on_failure(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "batch-create-objects-failure");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_create_spec_t specs[3];
    specs[0] = {OEP_OBJECT_TYPE_DOCUMENT, "Should Not Survive 1", "", "", nullptr, 0};
    specs[1] = {OEP_OBJECT_TYPE_DOCUMENT, "", "", "", nullptr, 0}; // invalid: empty name
    specs[2] = {OEP_OBJECT_TYPE_DOCUMENT, "Should Not Survive 3", "", "", nullptr, 0};

    oep_batch_create_objects_result_t result;
    const oep_result_t call_result = oep_batch_create_objects(runtime, specs, 3, &result);
    check(!call_result.success, "oep_batch_create_objects fails when one spec is invalid");
    check(result.failed_index == 1, "failed_index identifies the second (0-based) spec");
    check(result.created.count == 0, "the created list is empty — the whole batch was rolled back");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 0, "no objects were persisted after the failed batch rolled back");

    oep_runtime_destroy(runtime);
}

void test_batch_create_relationships(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_populated_repository(scratch_dir / "batch-create-relationships");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_object_list_t objects;
    oep_object_store_list(runtime, &objects);
    check(objects.count == 2, "the fixture repository has exactly two objects for batch relationship tests");
    const std::string source_id = objects.count == 2 ? objects.items[0].object_id : "";
    const std::string target_id = objects.count == 2 ? objects.items[1].object_id : "";
    oep_object_list_release(&objects);

    oep_relationship_create_spec_t specs[2];
    specs[0] = {source_id.c_str(), target_id.c_str(), OEP_RELATIONSHIP_TYPE_REFERENCES, "Jane", "first"};
    specs[1] = {target_id.c_str(), source_id.c_str(), OEP_RELATIONSHIP_TYPE_CONNECTED_TO, "Jane", "second"};

    oep_batch_create_relationships_result_t result;
    const oep_result_t call_result = oep_batch_create_relationships(runtime, specs, 2, &result);
    check(call_result.success, "oep_batch_create_relationships succeeds for two valid specs");
    check(result.created.count == 2, "two relationships were created");
    oep_batch_create_relationships_result_release(&result);
    check(result.created.items == nullptr, "oep_batch_create_relationships_result_release zeroes the created list");

    int count = -1;
    oep_relationship_store_get_count(runtime, &count);
    check(count == 3, "both batch-created relationships are persisted alongside the fixture's existing one");

    oep_runtime_destroy(runtime);
}

void test_batch_participates_in_caller_transaction(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "batch-caller-transaction");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, root.string().c_str());

    oep_transaction_begin(runtime);

    oep_object_info_t manual_object;
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Manually Created", "", "", nullptr, 0, &manual_object);

    oep_object_create_spec_t specs[1] = {{OEP_OBJECT_TYPE_DOCUMENT, "Batch Item", "", "", nullptr, 0}};
    oep_batch_create_objects_result_t batch_result;
    oep_batch_create_objects(runtime, specs, 1, &batch_result);

    check(oep_transaction_is_active(runtime) != 0,
          "the transaction the caller began is still active after a successful batch participates in it");

    const oep_result_t rollback_result = oep_transaction_rollback(runtime);
    check(rollback_result.success, "rolling back the caller's transaction succeeds");

    int count = -1;
    oep_object_store_get_count(runtime, &count);
    check(count == 0,
          "rolling back the caller's transaction undoes both the manual create and the batch create together");

    oep_runtime_destroy(runtime);
}

void test_destroy_closes_an_open_repository(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "destroy-open");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    const oep_result_t open_result = oep_runtime_open_repository(runtime, root.string().c_str());
    check(open_result.success, "opening the fixture repository succeeds for the destroy-while-open test");

    oep_runtime_destroy(runtime); // must not leak or crash even with a repository still open
    check(true, "destroying a handle with an open repository does not crash");
}

} // namespace

void test_package_install_and_lifecycle_queries(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "package_lifecycle");
    const std::filesystem::path archive = write_demo_archive(scratch_dir);

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "package_lifecycle").string().c_str());

    // install
    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("oep_package_install succeeds: ") + result.error_message);
    check(std::string(install_result.package_id) == "com.oep.demo.capi",
          "the install result carries the installed packageId");
    check(install_result.objects_created == 1, "the install result counts the installed object");

    // list
    oep_installed_package_list_t installed;
    result = oep_package_list_installed(runtime, &installed);
    check(result.success == 1 && installed.count == 1, "oep_package_list_installed lists the installed package");
    oep_installed_package_list_release(&installed);

    // get_info
    oep_package_details_t details;
    result = oep_package_get_info(runtime, "com.oep.demo.capi", &details);
    check(result.success == 1, std::string("oep_package_get_info succeeds: ") + result.error_message);
    check(std::string(details.title) == "C API Demo Package", "package details carry the title");
    check(std::string(details.publisher_name) == "OEP Demo Publisher", "package details carry the publisher");
    check(std::string(details.runtime_state) == "Installed", "package details carry the runtime state");
    check(std::strlen(details.package_hash) == 64, "package details carry a SHA-256 hash");
    check(details.engineering_domain_count == 1 &&
              std::string(details.engineering_domains[0]) == "Automotive",
          "package details carry the engineering domains");
    check(details.object_count == 1 && details.relationship_count == 0,
          "package details carry contribution counts");

    result = oep_package_get_info(runtime, "com.oep.no-such", &details);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_get_info reports NOT_FOUND for an uninstalled package");

    // get_contents
    oep_object_list_t content_objects;
    oep_relationship_list_t content_relationships;
    result = oep_package_get_contents(runtime, "com.oep.demo.capi", &content_objects, &content_relationships);
    check(result.success == 1, std::string("oep_package_get_contents succeeds: ") + result.error_message);
    check(content_objects.count == 1 && std::string(content_objects.items[0].name) == "API Harness",
          "package contents include the installed object, loaded live from the repository");
    check(content_relationships.count == 0, "package contents report no relationships for this package");
    oep_object_list_release(&content_objects);
    oep_relationship_list_release(&content_relationships);

    // locate
    oep_package_owner_t owner;
    result = oep_package_locate(runtime, "aaaaaaaa-3333-4000-8000-000000000001", &owner);
    check(result.success == 1 && owner.found == 1 && owner.kind == OEP_OWNED_ENTITY_OBJECT,
          "oep_package_locate resolves an installed object to its owner");
    check(std::string(owner.package_id) == "com.oep.demo.capi", "the owner is the installed package");

    result = oep_package_locate(runtime, "not-an-id", &owner);
    check(result.success == 1 && owner.found == 0,
          "oep_package_locate succeeds with found == 0 for an unowned id — a normal answer, not an error");

    // verify
    oep_package_verify_result_t verify_result;
    result = oep_package_verify(runtime, "com.oep.demo.capi", &verify_result);
    check(result.success == 1 && verify_result.verified == 1,
          "oep_package_verify passes for an intact install");
    check(verify_result.archive_available == 1 && verify_result.archive_hash_matches == 1,
          "oep_package_verify confirms the archive hash");

    result = oep_package_verify(runtime, "com.oep.no-such", &verify_result);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_verify reports NOT_FOUND for an uninstalled package");

    // search
    oep_installed_package_list_t matches;
    result = oep_package_search(runtime, "API Harness", &matches);
    check(result.success == 1 && matches.count == 1,
          "oep_package_search matches by installed object name");
    oep_installed_package_list_release(&matches);

    result = oep_package_search(runtime, "", &matches);
    check(result.success == 0 && result.error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_package_search rejects an empty query");

    oep_runtime_destroy(runtime);
}

void test_package_uninstall(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "package_uninstall");
    const std::filesystem::path archive = write_demo_archive(scratch_dir);

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "package_uninstall").string().c_str());

    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("oep_package_install succeeds: ") + result.error_message);

    // Uninstalling an unknown package fails with NOT_FOUND and populates
    // nothing.
    oep_package_uninstall_result_t missing_result;
    result = oep_package_uninstall(runtime, "com.oep.no-such", &missing_result);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_uninstall reports NOT_FOUND for a package that isn't installed");
    check(std::string(missing_result.package_id).empty() && missing_result.objects_deleted == 0,
          "oep_package_uninstall zero-initializes its result on failure");

    // Uninstalling the installed package removes it and its contribution.
    oep_package_uninstall_result_t uninstall_result;
    result = oep_package_uninstall(runtime, "com.oep.demo.capi", &uninstall_result);
    check(result.success == 1, std::string("oep_package_uninstall succeeds: ") + result.error_message);
    check(std::string(uninstall_result.package_id) == "com.oep.demo.capi",
          "the uninstall result carries the uninstalled packageId");
    check(uninstall_result.objects_deleted == 1 && uninstall_result.relationships_deleted == 0,
          "the uninstall result counts the deleted contribution");

    // The package is gone from the registry...
    oep_installed_package_list_t installed;
    result = oep_package_list_installed(runtime, &installed);
    check(result.success == 1 && installed.count == 0,
          "oep_package_list_installed no longer lists the uninstalled package");
    oep_installed_package_list_release(&installed);

    oep_package_details_t details;
    result = oep_package_get_info(runtime, "com.oep.demo.capi", &details);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_get_info reports NOT_FOUND after uninstall");

    // ...and its object is gone from the repository too.
    oep_object_info_t object_info;
    result = oep_object_store_get_by_id(runtime, "aaaaaaaa-3333-4000-8000-000000000001", &object_info);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "the package's Engineering Object no longer exists after uninstall");

    // Uninstalling the same package again now fails the same way.
    result = oep_package_uninstall(runtime, "com.oep.demo.capi", &uninstall_result);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_uninstall reports NOT_FOUND on a repeat uninstall");

    oep_runtime_destroy(runtime);
}

void test_package_uninstall_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_package_uninstall_result_t uninstall_result;
    oep_result_t result = oep_package_uninstall(runtime, "com.oep.demo.capi", &uninstall_result);
    check(result.error_code == OEP_ERROR_INVALID_STATE, "oep_package_uninstall requires an open repository");

    result = oep_package_uninstall(runtime, nullptr, &uninstall_result);
    check(result.error_code == OEP_ERROR_INVALID_ARGUMENT, "oep_package_uninstall rejects a null package_id");

    check(oep_package_uninstall(nullptr, "x", &uninstall_result).error_code == OEP_ERROR_INVALID_ARGUMENT,
          "oep_package_uninstall rejects a null runtime handle");

    oep_runtime_destroy(runtime);
}

void test_transaction_engine_info_and_history(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "transaction_engine");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "transaction_engine").string().c_str());

    // No transaction active: info succeeds with active == 0.
    oep_transaction_info_t info;
    oep_result_t result = oep_transaction_get_info(runtime, &info);
    check(result.success == 1 && info.active == 0,
          "oep_transaction_get_info reports no active transaction as a normal answer");

    // Active transaction: id and description are visible.
    oep_transaction_begin(runtime);
    result = oep_transaction_get_info(runtime, &info);
    check(result.success == 1 && info.active == 1 && std::strlen(info.transaction_id) == 36,
          "an active transaction reports a UUIDv4 transaction id");

    oep_object_info_t created;
    oep_object_create(runtime, OEP_OBJECT_TYPE_COMPONENT, "Journaled Widget", "", "author", nullptr, 0, &created);
    result = oep_transaction_get_info(runtime, &info);
    check(result.success == 1 && info.journal_entry_count == 1,
          "the active transaction counts its journaled operations");

    oep_transaction_commit(runtime);

    // A single mutation outside a transaction is journaled too (implicit
    // transaction), so history now has two records.
    oep_object_create(runtime, OEP_OBJECT_TYPE_DOCUMENT, "Implicit Doc", "", "author", nullptr, 0, nullptr);

    oep_transaction_record_list_t history;
    result = oep_transaction_history(runtime, &history);
    check(result.success == 1 && history.count == 2,
          "oep_transaction_history lists the explicit and the implicit transaction");
    bool all_committed = true;
    for (int i = 0; i < history.count; ++i) {
        if (std::string(history.items[i].state) != "Committed") all_committed = false;
        check(std::strlen(history.items[i].transaction_id) == 36, "every history record has a transaction id");
    }
    check(all_committed, "both journaled transactions are Committed");
    oep_transaction_record_list_release(&history);
    check(history.items == nullptr && history.count == 0, "release zeroes the history list");

    oep_runtime_destroy(runtime);
}

void test_transaction_engine_requires_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_transaction_info_t info;
    check(oep_transaction_get_info(runtime, &info).error_code == OEP_ERROR_INVALID_STATE,
          "oep_transaction_get_info requires an open repository");
    oep_transaction_record_list_t history;
    check(oep_transaction_history(runtime, &history).error_code == OEP_ERROR_INVALID_STATE,
          "oep_transaction_history requires an open repository");

    oep_runtime_destroy(runtime);
}

void test_trust_store_certificate_lifecycle(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "trust_capi");

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "trust_capi").string().c_str());

    // Default policy: signatures not required.
    int require_signatures = -1;
    oep_result_t result = oep_trust_get_policy(runtime, &require_signatures);
    check(result.success == 1 && require_signatures == 0, "the default trust policy does not require signatures");

    // No certificate yet: NOT_FOUND.
    oep_publisher_certificate_t certificate;
    result = oep_trust_get_certificate(runtime, "com.pub.capi", &certificate);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_trust_get_certificate reports NOT_FOUND before any certificate is added");

    // Add.
    const char* public_key_hex = "99c4ac9e6560c3a1e4bfd6a20e5ab6513aa77eea9233c01fe296e8b17f106cff";
    result = oep_trust_add_certificate(runtime, "com.pub.capi", "CAPI Publisher", public_key_hex,
                                        "2026-01-01T00:00:00Z", "2030-01-01T00:00:00Z", "self", "1", &certificate);
    check(result.success == 1, std::string("oep_trust_add_certificate succeeds: ") + result.error_message);
    check(std::string(certificate.publisher_name) == "CAPI Publisher", "the returned certificate carries its fields");
    check(std::strlen(certificate.fingerprint) == 64, "the returned certificate carries a computed fingerprint");
    check(certificate.revoked == 0, "a freshly added certificate is not revoked");

    // Adding again for the same publisher is rejected (no renewal).
    result = oep_trust_add_certificate(runtime, "com.pub.capi", "CAPI Publisher", public_key_hex, nullptr, nullptr,
                                        nullptr, nullptr, nullptr);
    check(result.success == 0, "a second certificate for the same publisher is rejected");

    // Get.
    result = oep_trust_get_certificate(runtime, "com.pub.capi", &certificate);
    check(result.success == 1 && std::string(certificate.publisher_id) == "com.pub.capi",
          "oep_trust_get_certificate finds the added certificate");

    // List.
    oep_certificate_list_t list;
    result = oep_trust_list_certificates(runtime, &list);
    check(result.success == 1 && list.count == 1, "oep_trust_list_certificates lists the added certificate");
    oep_certificate_list_release(&list);
    check(list.items == nullptr && list.count == 0, "release zeroes the certificate list");

    // Set policy, then revoke.
    result = oep_trust_set_policy(runtime, 1);
    check(result.success == 1, "oep_trust_set_policy succeeds");
    result = oep_trust_get_policy(runtime, &require_signatures);
    check(result.success == 1 && require_signatures == 1, "the policy change round-trips");

    result = oep_trust_revoke_certificate(runtime, "com.pub.capi");
    check(result.success == 1, "oep_trust_revoke_certificate succeeds");
    result = oep_trust_get_certificate(runtime, "com.pub.capi", &certificate);
    check(result.success == 1 && certificate.revoked == 1, "the certificate is kept, marked revoked");

    result = oep_trust_revoke_certificate(runtime, "com.pub.capi");
    check(result.success == 0, "revoking an already-revoked certificate fails");
    result = oep_trust_revoke_certificate(runtime, "com.pub.never-added");
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "revoking an unknown publisher reports NOT_FOUND");

    oep_runtime_destroy(runtime);
}

void test_package_trust_status_and_unsigned_install(const std::filesystem::path& scratch_dir) {
    build_repository(scratch_dir / "trust_status_capi");
    const std::filesystem::path archive = write_demo_archive(scratch_dir);

    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);
    oep_runtime_open_repository(runtime, (scratch_dir / "trust_status_capi").string().c_str());

    oep_package_install_result_t install_result;
    oep_result_t result = oep_package_install(runtime, archive.string().c_str(), &install_result);
    check(result.success == 1, std::string("an unsigned package still installs by default: ") + result.error_message);

    oep_package_trust_status_t trust_status;
    result = oep_package_get_trust_status(runtime, "com.oep.demo.capi", &trust_status);
    check(result.success == 1 && trust_status.state == OEP_TRUST_UNSIGNED,
          "oep_package_get_trust_status reports OEP_TRUST_UNSIGNED for an unsigned install");

    result = oep_package_get_trust_status(runtime, "com.oep.no-such", &trust_status);
    check(result.success == 0 && result.error_code == OEP_ERROR_NOT_FOUND,
          "oep_package_get_trust_status reports NOT_FOUND for an uninstalled package");

    oep_runtime_destroy(runtime);
}

void test_trust_functions_require_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_publisher_certificate_t certificate;
    check(oep_trust_add_certificate(runtime, "x", nullptr, "y", nullptr, nullptr, nullptr, nullptr, nullptr)
                  .error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_add_certificate requires an open repository");
    check(oep_trust_get_certificate(runtime, "x", &certificate).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_get_certificate requires an open repository");
    oep_certificate_list_t list;
    check(oep_trust_list_certificates(runtime, &list).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_list_certificates requires an open repository");
    check(oep_trust_revoke_certificate(runtime, "x").error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_revoke_certificate requires an open repository");
    int require_signatures = 0;
    check(oep_trust_get_policy(runtime, &require_signatures).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_get_policy requires an open repository");
    check(oep_trust_set_policy(runtime, 1).error_code == OEP_ERROR_INVALID_STATE,
          "oep_trust_set_policy requires an open repository");
    oep_package_trust_status_t trust_status;
    check(oep_package_get_trust_status(runtime, "x", &trust_status).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_get_trust_status requires an open repository");

    oep_runtime_destroy(runtime);
}

void test_package_queries_require_open_repository() {
    OEP_Runtime runtime = oep_runtime_create("0.1.0");
    oep_runtime_initialize(runtime);

    oep_package_details_t details;
    check(oep_package_get_info(runtime, "x", &details).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_get_info requires an open repository");
    oep_package_owner_t owner;
    check(oep_package_locate(runtime, "x", &owner).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_locate requires an open repository");
    oep_package_verify_result_t verify_result;
    check(oep_package_verify(runtime, "x", &verify_result).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_verify requires an open repository");
    oep_installed_package_list_t list;
    check(oep_package_search(runtime, "x", &list).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_search requires an open repository");
    oep_object_list_t objects;
    oep_relationship_list_t relationships;
    check(oep_package_get_contents(runtime, "x", &objects, &relationships).error_code == OEP_ERROR_INVALID_STATE,
          "oep_package_get_contents requires an open repository");

    oep_runtime_destroy(runtime);
}

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_api_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_version_reporting();
    test_state_to_string_is_deterministic();
    test_error_code_and_category_strings();
    test_create_rejects_null_version();
    test_destroy_is_null_safe();
    test_null_handle_calls_return_invalid_argument();
    test_full_lifecycle(scratch_dir);
    test_open_repository_reports_not_found(scratch_dir);
    test_open_repository_rejects_null_path();
    test_repository_status_fails_without_open_repository();
    test_object_enumeration(scratch_dir);
    test_object_lookup_by_id(scratch_dir);
    test_object_enumeration_requires_open_repository();
    test_repository_statistics(scratch_dir);
    test_repository_statistics_requires_open_repository();
    test_object_type_to_string();
    test_relationship_enumeration(scratch_dir);
    test_relationship_lookup_by_id(scratch_dir);
    test_relationship_enumeration_requires_open_repository();
    test_relationship_type_to_string();
    test_match_location_to_string();
    test_search_objects(scratch_dir);
    test_search_relationships(scratch_dir);
    test_search_repository(scratch_dir);
    test_search_requires_open_repository();
    test_object_create_update_delete(scratch_dir);
    test_object_mutation_requires_open_repository();
    test_relationship_create_update_delete(scratch_dir);
    test_transaction_commit(scratch_dir);
    test_transaction_rollback(scratch_dir);
    test_transaction_automatic_rollback_on_failure(scratch_dir);
    test_transaction_requires_open_repository();
    test_batch_create_objects(scratch_dir);
    test_batch_create_objects_rolls_back_on_failure(scratch_dir);
    test_batch_create_relationships(scratch_dir);
    test_batch_participates_in_caller_transaction(scratch_dir);
    test_destroy_closes_an_open_repository(scratch_dir);
    test_package_install_and_lifecycle_queries(scratch_dir);
    test_package_uninstall(scratch_dir);
    test_package_uninstall_requires_open_repository();
    test_package_queries_require_open_repository();
    test_transaction_engine_info_and_history(scratch_dir);
    test_transaction_engine_requires_open_repository();
    test_trust_store_certificate_lifecycle(scratch_dir);
    test_package_trust_status_and_unsigned_install(scratch_dir);
    test_trust_functions_require_open_repository();

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All Public C API tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " Public C API test(s) failed.\n";
    return 1;
}
