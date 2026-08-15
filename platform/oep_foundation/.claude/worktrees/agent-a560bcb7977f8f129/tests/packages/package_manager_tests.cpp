#include "oep/packages/package_manager.hpp"

#include <algorithm>
#include <filesystem>
#include <fstream>
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

void write_raw(const std::filesystem::path& path, const std::string& contents) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file << contents;
}

void write_manifest(const std::filesystem::path& package_dir, const std::string& package_id,
                     const std::string& package_name, const std::string& foundation_version = "0.1.0") {
    write_raw(package_dir / "package.json",
              "{\n"
              "  \"packageId\": \"" + package_id + "\",\n"
              "  \"packageName\": \"" + package_name + "\",\n"
              "  \"packageVersion\": \"1.0.0\",\n"
              "  \"packageType\": \"Extension\",\n"
              "  \"author\": \"Test Author\",\n"
              "  \"organization\": \"Test Org\",\n"
              "  \"description\": \"A sample package\",\n"
              "  \"tags\": [\"sample\"],\n"
              "  \"foundationVersion\": \"" + foundation_version + "\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\"\n"
              "}\n");
}

bool contains_name(const std::vector<std::string>& names, const std::string& name) {
    return std::find(names.begin(), names.end(), name) != names.end();
}

void test_discover_packages_finds_only_manifested_directories(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "discover";
    write_manifest(root / "pkg-b", "2b9e1b02-e845-482a-b299-1e15ffe3932b", "Package B");
    write_manifest(root / "pkg-a", "1b9e1b02-e845-482a-b299-1e15ffe3932b", "Package A");
    write_raw(root / "not-a-package" / "readme.txt", "no manifest here");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::DiscoverPackagesResult result = manager.discover_packages();

    check(result.success, "discover_packages succeeds");
    check(result.package_directory_names.size() == 2, "discover_packages finds exactly the two manifested packages");
    check(contains_name(result.package_directory_names, "pkg-a"), "discover_packages finds pkg-a");
    check(contains_name(result.package_directory_names, "pkg-b"), "discover_packages finds pkg-b");
    check(!contains_name(result.package_directory_names, "not-a-package"),
          "discover_packages ignores a directory with no package.json");
    check(result.package_directory_names.front() == "pkg-a", "discover_packages returns a deterministic sorted order");
}

void test_load_valid_package_succeeds(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "valid";
    write_manifest(root / "pkg", "1b9e1b02-e845-482a-b299-1e15ffe3932b", "Valid Package");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::LoadPackageResult result = manager.load_package("pkg");

    check(result.success, "load_package succeeds for an existing directory");
    check(result.package.state == oep::packages::PackageState::Loaded, "a valid package is reported Loaded");
    check(result.package.manifest.package_name == "Valid Package", "the loaded manifest is populated correctly");
}

void test_missing_manifest_is_invalid(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "missing_manifest";
    write_raw(root / "pkg" / "readme.txt", "no manifest");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::LoadPackageResult result = manager.load_package("pkg");

    check(result.success, "load_package still succeeds as an operation for a missing manifest");
    check(result.package.state == oep::packages::PackageState::Invalid,
          "a package directory with no manifest is Invalid");
}

void test_invalid_json_manifest_is_invalid(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid_json";
    write_raw(root / "pkg" / "package.json", "{ not valid json ");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::LoadPackageResult result = manager.load_package("pkg");

    check(result.package.state == oep::packages::PackageState::Invalid, "malformed manifest JSON is Invalid");
}

void test_invalid_manifest_fields_are_invalid(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "invalid_fields";
    write_raw(root / "pkg" / "package.json",
              "{\n"
              "  \"packageId\": \"not-a-uuid\",\n"
              "  \"packageName\": \"\",\n"
              "  \"packageVersion\": \"1.0.0\",\n"
              "  \"packageType\": \"Extension\",\n"
              "  \"foundationVersion\": \"0.1.0\",\n"
              "  \"createdUtc\": \"2026-01-01T00:00:00Z\"\n"
              "}\n");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::LoadPackageResult result = manager.load_package("pkg");

    check(result.package.state == oep::packages::PackageState::Invalid,
          "a manifest with a bad packageId and missing packageName is Invalid");
}

void test_unsupported_foundation_version_is_invalid(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "unsupported_version";
    write_manifest(root / "pkg", "1b9e1b02-e845-482a-b299-1e15ffe3932b", "Future Package", "9.9.0");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::LoadPackageResult result = manager.load_package("pkg");

    check(result.success, "load_package succeeds even when the package targets an unsupported Foundation version");
    check(result.package.state == oep::packages::PackageState::Invalid,
          "a package requiring an incompatible Foundation version is Invalid");
    check(!result.package.message.empty(), "the incompatibility reason is reported");
}

void test_disabled_package_is_reported_disabled(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "disabled";
    write_manifest(root / "pkg", "1b9e1b02-e845-482a-b299-1e15ffe3932b", "Disableable Package");
    write_raw(root / "pkg" / ".disabled", "");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::LoadPackageResult result = manager.load_package("pkg");

    check(result.package.state == oep::packages::PackageState::Disabled,
          "a package directory with a .disabled marker is Disabled, even though its manifest is otherwise valid");
}

void test_duplicate_package_ids_are_detected(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "duplicate_ids";
    write_manifest(root / "pkg-first", "1b9e1b02-e845-482a-b299-1e15ffe3932b", "First");
    write_manifest(root / "pkg-second", "1b9e1b02-e845-482a-b299-1e15ffe3932b", "Second (duplicate ID)");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::ListPackagesResult result = manager.list_packages();

    check(result.success, "list_packages succeeds even with a duplicate packageId present");
    check(result.packages.size() == 2, "both packages are still reported");

    int loaded_count = 0;
    int invalid_count = 0;
    for (const oep::packages::DiscoveredPackage& package : result.packages) {
        if (package.state == oep::packages::PackageState::Loaded) ++loaded_count;
        if (package.state == oep::packages::PackageState::Invalid) ++invalid_count;
    }
    check(loaded_count == 1, "exactly one of the two packages sharing an ID is Loaded");
    check(invalid_count == 1, "the other package sharing the ID is Invalid");
}

void test_invalid_package_does_not_block_others(const std::filesystem::path& scratch_dir) {
    const std::filesystem::path root = scratch_dir / "mixed";
    write_manifest(root / "pkg-good", "1b9e1b02-e845-482a-b299-1e15ffe3932b", "Good Package");
    write_raw(root / "pkg-bad" / "package.json", "{ not valid json ");

    const oep::packages::PackageManager manager(root, "0.1.0");
    const oep::packages::ListPackagesResult result = manager.list_packages();

    check(result.success, "list_packages succeeds despite one invalid package");
    check(result.packages.size() == 2, "both the good and bad packages are reported");

    bool good_loaded = false;
    for (const oep::packages::DiscoveredPackage& package : result.packages) {
        if (package.directory_name == "pkg-good" && package.state == oep::packages::PackageState::Loaded) {
            good_loaded = true;
        }
    }
    check(good_loaded, "the valid package still loads despite the invalid sibling");
}

} // namespace

int main() {
    const std::filesystem::path scratch_dir = std::filesystem::temp_directory_path() / "oep_package_manager_tests";
    std::filesystem::remove_all(scratch_dir);
    std::filesystem::create_directories(scratch_dir);

    test_discover_packages_finds_only_manifested_directories(scratch_dir);
    test_load_valid_package_succeeds(scratch_dir);
    test_missing_manifest_is_invalid(scratch_dir);
    test_invalid_json_manifest_is_invalid(scratch_dir);
    test_invalid_manifest_fields_are_invalid(scratch_dir);
    test_unsupported_foundation_version_is_invalid(scratch_dir);
    test_disabled_package_is_reported_disabled(scratch_dir);
    test_duplicate_package_ids_are_detected(scratch_dir);
    test_invalid_package_does_not_block_others(scratch_dir);

    std::filesystem::remove_all(scratch_dir);

    if (g_failures == 0) {
        std::cout << "All package manager tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " package manager test(s) failed.\n";
    return 1;
}
