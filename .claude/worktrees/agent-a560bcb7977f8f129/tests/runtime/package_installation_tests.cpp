#include "oep/runtime/foundation_runtime.hpp"

#include "oep/repository/metadata.hpp"

#include <cstdint>
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

std::filesystem::path write_temp_archive(const std::vector<std::uint8_t>& bytes, const std::string& file_name) {
    const std::filesystem::path path =
        std::filesystem::temp_directory_path() / "oep_package_installation_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

std::string manifest_for(const std::string& package_id) {
    return R"({"schemaVersion":"1.0","packageId":")" + package_id +
           R"(","version":"1.0.0","publisher":{"id":"demo-publisher","name":"OEP Demo Publisher"},)"
           R"("title":"Engineering Demo Package","summary":"s","description":"d","category":"demonstration",)"
           R"("engineeringDomains":["Automotive"],"license":{},"dependencies":[],"capabilities":[],)"
           R"("repository":{},"statistics":{},"signatures":{},"build":{}})";
}

std::filesystem::path build_demo_archive(const std::string& package_id, const std::string& file_name) {
    const std::string object_a = R"({"objectId":"aaaaaaaa-0000-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";
    const std::string object_b = R"({"objectId":"bbbbbbbb-0000-4000-8000-000000000002","objectType":"Diagram",)"
                                  R"("name":"Wiring Diagram","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";
    const std::string relationship = R"({"relationshipId":"cccccccc-0000-4000-8000-000000000003",)"
                                      R"("sourceObjectId":"bbbbbbbb-0000-4000-8000-000000000002",)"
                                      R"("targetObjectId":"aaaaaaaa-0000-4000-8000-000000000001",)"
                                      R"("relationshipType":"Documents","createdUtc":"2026-01-01T00:00:00Z",)"
                                      R"("author":"a","description":"d"})";
    return write_temp_archive(build_stored_zip({
                                   {"manifest/package.json", manifest_for(package_id)},
                                   {"fragment/objects/a.json", object_a},
                                   {"fragment/objects/b.json", object_b},
                                   {"fragment/relationships/r.json", relationship},
                               }),
                               file_name);
}

void test_install_creates_objects_relationships_registry_and_indexes(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "install_happy_path");
    const std::filesystem::path archive = build_demo_archive("com.oep.demo.a", "a.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    check(runtime.open_repository(root).success, "open_repository succeeds");

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(result.success, "install_package succeeds for a well-formed archive: " + result.error);
    check(result.objects_created == 2, "install_package reports 2 objects created");
    check(result.relationships_created == 1, "install_package reports 1 relationship created");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.size() == 2, "the two installed objects are now in ObjectStore");

    const oep::repository::ListRelationshipsResult relationships = runtime.relationship_store()->list_all();
    check(relationships.success && relationships.relationships.size() == 1,
          "the installed relationship is now in RelationshipStore");

    // "Update Repository indexes" — confirm Search actually finds the
    // newly-installed content, not just that ObjectStore has it on disk.
    const oep::search::SearchObjectsResult found = runtime.search_engine()->search_objects("Harness");
    check(found.success && !found.results.empty(), "Search finds the installed object by name after install");

    const oep::runtime::RuntimeInstalledPackagesResult installed = runtime.list_installed_packages();
    check(installed.success && installed.packages.size() == 1, "the Repository Registry has one record");
    check(installed.packages[0].package_id == "com.oep.demo.a", "the registry record has the correct packageId");
    check(installed.packages[0].object_ids.size() == 2, "the registry record lists both contributed object ids");

    // WP-REP-002: the Repository Registry entry carries full manifest
    // metadata, publisher, hash, path, and runtime state.
    const oep::installer::RepositoryRegistryEntry& entry = installed.packages[0];
    check(entry.publisher_name == "OEP Demo Publisher", "the registry entry records the publisher name");
    check(entry.category == "demonstration", "the registry entry records the category");
    check(entry.engineering_domains.size() == 1 && entry.engineering_domains[0] == "Automotive",
          "the registry entry records the engineering domains");
    check(entry.runtime_state == "Installed", "the registry entry records the Installed runtime state");
    check(entry.package_hash.size() == 64, "the registry entry records a SHA-256 package hash");
    check(!entry.installation_path.empty(), "the registry entry records the installation path");

    runtime.shutdown();
}

void test_lifecycle_queries(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "lifecycle_queries");
    const std::filesystem::path archive = build_demo_archive("com.oep.demo.lifecycle", "lifecycle.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    check(runtime.install_package(archive).success, "install succeeds for the lifecycle-query fixture");

    // get_installed_package
    const oep::runtime::RuntimeInstalledPackageResult found =
        runtime.get_installed_package("com.oep.demo.lifecycle");
    check(found.success && found.installed, "get_installed_package finds the installed package");
    check(found.entry.title == "Engineering Demo Package", "get_installed_package returns full metadata");

    const oep::runtime::RuntimeInstalledPackageResult missing = runtime.get_installed_package("com.oep.no-such");
    check(missing.success && !missing.installed,
          "get_installed_package reports not-installed (not an error) for an unknown package");

    // find_package_owner
    const oep::runtime::RuntimePackageOwnerResult object_owner =
        runtime.find_package_owner("aaaaaaaa-0000-4000-8000-000000000001");
    check(object_owner.success && object_owner.kind == oep::installer::OwnedEntityKind::Object,
          "find_package_owner resolves an installed object to its package");
    check(object_owner.owner.package_id == "com.oep.demo.lifecycle",
          "find_package_owner reports the correct owning package");

    const oep::runtime::RuntimePackageOwnerResult relationship_owner =
        runtime.find_package_owner("cccccccc-0000-4000-8000-000000000003");
    check(relationship_owner.success && relationship_owner.kind == oep::installer::OwnedEntityKind::Relationship,
          "find_package_owner resolves an installed relationship to its package");

    const oep::runtime::RuntimePackageOwnerResult no_owner = runtime.find_package_owner("not-an-id");
    check(no_owner.success && no_owner.kind == oep::installer::OwnedEntityKind::None,
          "find_package_owner reports None for an unowned id");

    // verify_package — everything intact immediately after install
    const oep::runtime::RuntimeVerifyPackageResult verified = runtime.verify_package("com.oep.demo.lifecycle");
    check(verified.success && verified.verified, "verify_package passes immediately after install");
    check(verified.objects_present == 2 && verified.objects_expected == 2,
          "verify_package counts both objects present");
    check(verified.archive_available && verified.archive_hash_matches,
          "verify_package confirms the archive is present and its hash matches");

    const oep::runtime::RuntimeVerifyPackageResult verify_missing = runtime.verify_package("com.oep.no-such");
    check(!verify_missing.success, "verify_package fails for a package that is not installed");

    // search_installed_packages — by manifest metadata, and by installed
    // object name (cross-referenced live against ObjectStore).
    const oep::runtime::RuntimeSearchPackagesResult by_title = runtime.search_installed_packages("Demo Package");
    check(by_title.success && by_title.packages.size() == 1, "search matches by title");

    const oep::runtime::RuntimeSearchPackagesResult by_domain = runtime.search_installed_packages("automotive");
    check(by_domain.success && by_domain.packages.size() == 1, "search matches an engineering domain (case-insensitive)");

    const oep::runtime::RuntimeSearchPackagesResult by_object_name = runtime.search_installed_packages("Wiring Diagram");
    check(by_object_name.success && by_object_name.packages.size() == 1,
          "search matches by the name of an installed Engineering Object");

    const oep::runtime::RuntimeSearchPackagesResult no_match = runtime.search_installed_packages("zzz-nothing");
    check(no_match.success && no_match.packages.empty(), "a valid non-matching search returns an empty list");

    runtime.shutdown();
}

void test_verify_detects_a_deleted_contribution(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "verify_deleted");
    const std::filesystem::path archive = build_demo_archive("com.oep.demo.verify", "verify.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    check(runtime.install_package(archive).success, "install succeeds for the verify fixture");

    // Delete one installed contribution out from under the registry
    // (the relationship first, then its source object).
    check(runtime.delete_relationship("cccccccc-0000-4000-8000-000000000003").success,
          "the installed relationship can be deleted");
    check(runtime.delete_object("bbbbbbbb-0000-4000-8000-000000000002").success,
          "an installed object can be deleted");

    const oep::runtime::RuntimeVerifyPackageResult verified = runtime.verify_package("com.oep.demo.verify");
    check(verified.success, "verify_package still succeeds operationally");
    check(!verified.verified, "verify_package reports FAILED once a contribution is missing");
    check(verified.objects_present == 1 && verified.objects_expected == 2,
          "verify_package counts the missing object");
    check(verified.relationships_present == 0 && verified.relationships_expected == 1,
          "verify_package counts the missing relationship");
    check(!verified.findings.empty(), "verify_package reports human-readable findings");

    runtime.shutdown();
}

void test_install_requires_an_open_repository() {
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    const oep::runtime::RuntimeInstallResult result = runtime.install_package("/does/not/matter.oep");
    check(!result.success, "install_package fails when no repository is open");
}

void test_reinstalling_the_same_package_is_rejected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "reinstall_rejected");
    const std::filesystem::path archive = build_demo_archive("com.oep.demo.b", "b.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    check(runtime.install_package(archive).success, "the first install succeeds");
    const oep::runtime::RuntimeInstallResult second = runtime.install_package(archive);
    check(!second.success, "installing the same package a second time is rejected");
    check(second.error.find("already installed") != std::string::npos,
          "the rejection explains the package is already installed");

    runtime.shutdown();
}

void test_a_failure_partway_through_is_rolled_back(const std::filesystem::path& scratch_dir) {
    // A relationship whose sourceObjectId does not correspond to any
    // object in this package (and none exists yet in the repository
    // either) — RelationshipStore::create fails. Since WP-REP-003
    // (Repository Transaction Engine), the whole install is atomic: the
    // object created immediately before the failure must be rolled back,
    // and the transaction journaled as RolledBack. This inverts
    // WP-REP-001/002's deliberately-non-transactional behavior.
    const std::string object_a = R"({"objectId":"aaaaaaaa-1111-4000-8000-000000000001","objectType":"Component",)"
                                  R"("name":"Harness","description":"d","createdUtc":"2026-01-01T00:00:00Z",)"
                                  R"("lastModifiedUtc":"2026-01-01T00:00:00Z","version":"1.0.0","author":"a","tags":[]})";
    const std::string dangling_relationship =
        R"({"sourceObjectId":"00000000-0000-4000-8000-000000000000",)"
        R"("targetObjectId":"aaaaaaaa-1111-4000-8000-000000000001","relationshipType":"References",)"
        R"("createdUtc":"2026-01-01T00:00:00Z","author":"a","description":"d"})";
    const std::filesystem::path archive =
        write_temp_archive(build_stored_zip({
                                {"manifest/package.json", manifest_for("com.oep.demo.c")},
                                {"fragment/objects/a.json", object_a},
                                {"fragment/relationships/r.json", dangling_relationship},
                            }),
                            "c.oep");

    const std::filesystem::path root = build_repository(scratch_dir / "partial_failure");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(!result.success, "install_package fails when a relationship references a nonexistent object");
    check(result.objects_created == 0, "a failed install reports 0 objects created (the install was rolled back)");

    const oep::repository::ListObjectsResult objects = runtime.object_store()->list_all();
    check(objects.success && objects.objects.empty(),
          "the object created before the failure was rolled back — the repository is unchanged");

    const oep::runtime::RuntimeInstalledPackagesResult installed = runtime.list_installed_packages();
    check(installed.success && installed.packages.empty(),
          "no Repository Registry record is written when install_package fails");

    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    check(history.success && history.records.size() == 1, "the failed install left exactly one journal record");
    if (history.success && !history.records.empty()) {
        check(history.records[0].state == oep::runtime::TransactionState::RolledBack,
              "the failed install's transaction is journaled as RolledBack");
        check(history.records[0].description.find("install com.oep.demo.c") != std::string::npos,
              "the journal record names the install");
    }

    runtime.shutdown();
}

void test_a_successful_install_is_journaled_committed(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "journal_committed");
    const std::filesystem::path archive = build_demo_archive("com.oep.demo.journaled", "journaled.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    check(runtime.install_package(archive).success, "the install succeeds");

    const oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    check(history.success && history.records.size() == 1, "the install left exactly one journal record");
    if (history.success && !history.records.empty()) {
        const oep::runtime::TransactionRecord& record = history.records[0];
        check(record.state == oep::runtime::TransactionState::Committed,
              "the successful install's transaction is journaled as Committed");
        // 2 objects + 1 relationship + 1 PackageRecorded = 4 operations.
        check(record.entries.size() == 4, "the journal records every operation the install performed");
        check(record.entries.back().operation == "PackageRecorded",
              "the final journaled operation is the Repository Registry write");
        const oep::runtime::RuntimeTransactionRecordResult loaded =
            runtime.get_transaction_record(record.transaction_id);
        check(loaded.success && loaded.record.transaction_id == record.transaction_id,
              "the journal record can be loaded back by its transaction id");
    }

    runtime.shutdown();
}

void test_every_mutation_is_journaled(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "implicit_transactions");
    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);

    // A single mutation outside any explicit transaction runs in an
    // implicit one — journaled like any other write (WP-REP-003: all
    // Repository write operations execute through Repository Transactions).
    const oep::runtime::RuntimeObjectMutationResult created =
        runtime.create_object(oep::repository::ObjectType::Component, "Widget", "", "author", {});
    check(created.success, "an implicit-transaction create succeeds");

    oep::runtime::RuntimeTransactionHistoryResult history = runtime.transaction_history();
    check(history.success && history.records.size() == 1, "the implicit transaction was journaled");
    if (history.success && !history.records.empty()) {
        check(history.records[0].state == oep::runtime::TransactionState::Committed,
              "the implicit transaction committed");
        check(history.records[0].entries.size() == 1 && history.records[0].entries[0].operation == "ObjectCreated",
              "the implicit transaction journaled the single ObjectCreated operation");
    }

    // An explicit transaction has an id while active, and journals every
    // operation on commit.
    check(runtime.begin_transaction().success, "an explicit transaction begins");
    const oep::runtime::RuntimeTransactionInfoResult info = runtime.current_transaction_info();
    check(info.success && info.active && !info.transaction_id.empty(),
          "the active transaction reports its id via current_transaction_info");

    runtime.update_object(created.object.object_id, "Widget Rev B", "", "author", {});
    check(runtime.commit_transaction().success, "the explicit transaction commits");

    history = runtime.transaction_history();
    check(history.success && history.records.size() == 2, "the explicit transaction was journaled too");

    // An explicit rollback journals RolledBack and restores state.
    runtime.begin_transaction();
    runtime.delete_object(created.object.object_id);
    check(runtime.rollback_transaction().success, "rollback succeeds");
    check(runtime.object_store()->load(created.object.object_id).success,
          "the deleted object is restored by rollback");

    history = runtime.transaction_history();
    check(history.success && history.records.size() == 3, "the rolled-back transaction was journaled");
    bool has_rolled_back = false;
    for (const oep::runtime::TransactionRecord& record : history.records) {
        if (record.state == oep::runtime::TransactionState::RolledBack) has_rolled_back = true;
    }
    check(has_rolled_back, "one journal record has state RolledBack");

    runtime.shutdown();
}

void test_install_is_rejected_inside_an_explicit_transaction(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = build_repository(scratch_dir / "install_in_txn");
    const std::filesystem::path archive = build_demo_archive("com.oep.demo.nested", "nested.oep");

    oep::runtime::FoundationRuntime runtime("0.1.0");
    runtime.initialize();
    runtime.open_repository(root);
    runtime.begin_transaction();

    const oep::runtime::RuntimeInstallResult result = runtime.install_package(archive);
    check(!result.success, "install_package is rejected while a caller transaction is active");
    check(result.error.find("already active") != std::string::npos,
          "the rejection explains a transaction is already active");

    runtime.rollback_transaction();
    runtime.shutdown();
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_package_installation_runtime_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_install_creates_objects_relationships_registry_and_indexes(scratch_dir);
    test_install_requires_an_open_repository();
    test_reinstalling_the_same_package_is_rejected(scratch_dir);
    test_a_failure_partway_through_is_rolled_back(scratch_dir);
    test_a_successful_install_is_journaled_committed(scratch_dir);
    test_every_mutation_is_journaled(scratch_dir);
    test_install_is_rejected_inside_an_explicit_transaction(scratch_dir);
    test_lifecycle_queries(scratch_dir);
    test_verify_detects_a_deleted_contribution(scratch_dir);

    std::filesystem::remove_all(scratch_dir);
    std::filesystem::remove_all(std::filesystem::temp_directory_path() / "oep_package_installation_tests");

    if (g_failures == 0) {
        std::cout << "All package installation (FoundationRuntime) tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " package installation test(s) failed.\n";
    return 1;
}
