#include "oep/installer/repository_registry.hpp"

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

oep::installer::RepositoryRegistryEntry sample_entry(const std::string& package_id) {
    oep::installer::RepositoryRegistryEntry entry;
    entry.package_id = package_id;
    entry.version = "1.0.0";
    entry.title = "Sample Package";
    entry.summary = "A sample package for Repository Registry tests.";
    entry.category = "demonstration";
    entry.schema_version = "1.0";
    entry.engineering_domains = {"Automotive", "Electrical"};
    entry.publisher_id = "demo-publisher";
    entry.publisher_name = "OEP Demo Publisher";
    entry.installed_utc = "2026-01-01T00:00:00Z";
    entry.source = "local";
    entry.installation_path = "/tmp/sample.oep";
    entry.package_hash = "deadbeef";
    entry.runtime_state = "Installed";
    entry.object_ids = {"obj-1", "obj-2"};
    entry.relationship_ids = {"rel-1"};
    return entry;
}

void test_record_install_then_is_installed(const oep::installer::RepositoryRegistry& registry) {
    const oep::installer::RegistryResult recorded = registry.record_install(sample_entry("com.example.a"));
    check(recorded.success, "record_install succeeds for a new package");

    const oep::installer::IsInstalledResult found = registry.is_installed("com.example.a");
    check(found.success, "is_installed succeeds");
    check(found.installed, "is_installed reports true after recording");
    check(found.record.version == "1.0.0", "is_installed returns the recorded version");
    check(found.record.object_ids.size() == 2, "is_installed returns the recorded object ids");
    check(found.record.publisher_name == "OEP Demo Publisher", "is_installed returns the recorded publisher name");
    check(found.record.category == "demonstration", "is_installed returns the recorded category");
    check(found.record.engineering_domains.size() == 2, "is_installed returns the recorded engineering domains");
    check(found.record.package_hash == "deadbeef", "is_installed returns the recorded package hash");
    check(found.record.installation_path == "/tmp/sample.oep", "is_installed returns the recorded installation path");
    check(found.record.runtime_state == "Installed", "is_installed returns the recorded runtime state");
}

void test_is_installed_false_for_unknown_package(const oep::installer::RepositoryRegistry& registry) {
    const oep::installer::IsInstalledResult found = registry.is_installed("com.example.does-not-exist");
    check(found.success, "is_installed succeeds for an unknown package");
    check(!found.installed, "is_installed reports false for a package never recorded");
}

void test_record_install_rejects_a_duplicate_package_id(const oep::installer::RepositoryRegistry& registry) {
    const oep::installer::RegistryResult first = registry.record_install(sample_entry("com.example.b"));
    check(first.success, "the first install of a package succeeds");

    const oep::installer::RegistryResult second = registry.record_install(sample_entry("com.example.b"));
    check(!second.success, "a second install attempt for the same packageId is rejected");
}

void test_list_installed_returns_every_recorded_package(const oep::installer::RepositoryRegistry& registry) {
    registry.record_install(sample_entry("com.example.c"));
    registry.record_install(sample_entry("com.example.d"));

    const oep::installer::ListInstalledResult listed = registry.list_installed();
    check(listed.success, "list_installed succeeds");
    bool has_c = false;
    bool has_d = false;
    for (const oep::installer::RepositoryRegistryEntry& entry : listed.packages) {
        if (entry.package_id == "com.example.c") has_c = true;
        if (entry.package_id == "com.example.d") has_d = true;
    }
    check(has_c, "list_installed includes a package installed earlier in this test run");
    check(has_d, "list_installed includes another package installed earlier in this test run");
}

void test_list_installed_empty_for_a_fresh_registry() {
    const std::filesystem::path scratch_dir =
        std::filesystem::temp_directory_path() / "oep_repository_registry_tests_empty";
    std::filesystem::remove_all(scratch_dir);
    const oep::installer::RepositoryRegistry registry(scratch_dir);

    const oep::installer::ListInstalledResult listed = registry.list_installed();
    check(listed.success, "list_installed succeeds even when the packages/ directory doesn't exist yet");
    check(listed.packages.empty(), "a fresh registry has no installed packages");

    std::filesystem::remove_all(scratch_dir);
}

void test_find_owner_locates_the_package_that_owns_an_object(const oep::installer::RepositoryRegistry& registry) {
    oep::installer::RepositoryRegistryEntry entry = sample_entry("com.example.owner-test");
    entry.object_ids = {"owned-object-1"};
    entry.relationship_ids = {"owned-relationship-1"};
    registry.record_install(entry);

    const oep::installer::FindOwnerResult object_owner = registry.find_owner("owned-object-1");
    check(object_owner.success, "find_owner succeeds for a known object id");
    check(object_owner.kind == oep::installer::OwnedEntityKind::Object, "find_owner reports Object for an object id");
    check(object_owner.owner.package_id == "com.example.owner-test", "find_owner reports the correct owning package");

    const oep::installer::FindOwnerResult relationship_owner = registry.find_owner("owned-relationship-1");
    check(relationship_owner.kind == oep::installer::OwnedEntityKind::Relationship,
          "find_owner reports Relationship for a relationship id");

    const oep::installer::FindOwnerResult none = registry.find_owner("no-such-id");
    check(none.success, "find_owner succeeds even when nothing matches");
    check(none.kind == oep::installer::OwnedEntityKind::None, "find_owner reports None for an unrecognized id");
}

void test_search_packages_matches_metadata_fields(const oep::installer::RepositoryRegistry& registry) {
    oep::installer::RepositoryRegistryEntry entry = sample_entry("com.example.searchable");
    entry.title = "GL1200 Ignition Harness Pack";
    entry.publisher_name = "Wing Motors";
    entry.engineering_domains = {"Motorcycle Electrical"};
    registry.record_install(entry);

    const oep::installer::SearchPackagesResult by_title = registry.search_packages("ignition");
    check(by_title.success, "search_packages succeeds");
    bool found_by_title = false;
    for (const auto& match : by_title.packages) {
        if (match.package_id == "com.example.searchable") found_by_title = true;
    }
    check(found_by_title, "search_packages matches a case-insensitive substring of the title");

    const oep::installer::SearchPackagesResult by_publisher = registry.search_packages("wing motors");
    bool found_by_publisher = false;
    for (const auto& match : by_publisher.packages) {
        if (match.package_id == "com.example.searchable") found_by_publisher = true;
    }
    check(found_by_publisher, "search_packages matches a case-insensitive substring of the publisher name");

    const oep::installer::SearchPackagesResult by_domain = registry.search_packages("Motorcycle");
    bool found_by_domain = false;
    for (const auto& match : by_domain.packages) {
        if (match.package_id == "com.example.searchable") found_by_domain = true;
    }
    check(found_by_domain, "search_packages matches an engineering domain");

    const oep::installer::SearchPackagesResult no_match = registry.search_packages("no-such-term-anywhere");
    check(no_match.success && no_match.packages.empty(), "search_packages returns no matches for an unrelated query");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_repository_registry_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);
    const oep::installer::RepositoryRegistry registry(scratch_dir);

    test_record_install_then_is_installed(registry);
    test_is_installed_false_for_unknown_package(registry);
    test_record_install_rejects_a_duplicate_package_id(registry);
    test_list_installed_returns_every_recorded_package(registry);
    test_list_installed_empty_for_a_fresh_registry();
    test_find_owner_locates_the_package_that_owns_an_object(registry);
    test_search_packages_matches_metadata_fields(registry);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All RepositoryRegistry tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " RepositoryRegistry test(s) failed.\n";
    return 1;
}
