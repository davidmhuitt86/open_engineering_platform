#include "oep/packages/package_manager.hpp"

#include <algorithm>
#include <fstream>
#include <optional>
#include <set>
#include <sstream>
#include <system_error>
#include <utility>

#include "oep/repository/json_value.hpp"

namespace oep::packages {

namespace {

namespace json = oep::repository::json;

std::string read_string_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

std::vector<std::string> read_tags(const json::Value& value) {
    std::vector<std::string> tags;
    const json::Value* found = value.find("tags");
    if (found == nullptr || !found->is_array()) {
        return tags;
    }
    for (const json::Value& entry : found->as_array()) {
        if (entry.is_string()) {
            tags.push_back(entry.as_string());
        }
    }
    return tags;
}

struct ParsedManifest {
    bool success = false;
    std::string error;
    PackageManifest manifest;
};

ParsedManifest read_manifest_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'", {}};
    }

    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();

    const json::ParseResult parsed = json::parse(contents_stream.str());
    if (!parsed.success) {
        return {false, "invalid JSON in '" + path.string() + "': " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "'" + path.string() + "' must contain a JSON object", {}};
    }

    PackageManifest manifest;
    manifest.package_id = read_string_field(parsed.value, "packageId");
    manifest.package_name = read_string_field(parsed.value, "packageName");
    manifest.package_version = read_string_field(parsed.value, "packageVersion");

    const std::string type_name = read_string_field(parsed.value, "packageType");
    const std::optional<PackageType> type = package_type_from_string(type_name);
    if (!type.has_value()) {
        return {false, "'" + path.string() + "' has an unrecognized packageType '" + type_name + "'", {}};
    }
    manifest.package_type = *type;

    manifest.author = read_string_field(parsed.value, "author");
    manifest.organization = read_string_field(parsed.value, "organization");
    manifest.description = read_string_field(parsed.value, "description");
    manifest.tags = read_tags(parsed.value);
    manifest.foundation_version = read_string_field(parsed.value, "foundationVersion");
    manifest.created_utc = read_string_field(parsed.value, "createdUtc");

    return {true, "", manifest};
}

// Parses "major.minor.patch"; returns {major, minor} or nullopt if malformed.
std::optional<std::pair<int, int>> major_minor(const std::string& version) {
    int major = 0;
    int minor = 0;
    int patch = 0;
    char dot1 = 0;
    char dot2 = 0;
    std::istringstream stream(version);
    stream >> major >> dot1 >> minor >> dot2 >> patch;
    if (!stream || dot1 != '.' || dot2 != '.') {
        return std::nullopt;
    }
    return std::make_pair(major, minor);
}

// Packages are considered compatible with the Foundation release they
// were built against, at major.minor granularity; patch differences
// within the same minor line are assumed compatible. This is a
// deliberately simple starting policy, not a full semver range engine.
bool is_compatible_foundation_version(const std::string& package_foundation_version,
                                      const std::string& running_foundation_version) {
    const std::optional<std::pair<int, int>> package_version = major_minor(package_foundation_version);
    const std::optional<std::pair<int, int>> running_version = major_minor(running_foundation_version);
    if (!package_version.has_value() || !running_version.has_value()) {
        return false;
    }
    return *package_version == *running_version;
}

} // namespace

std::string to_string(PackageState state) {
    switch (state) {
        case PackageState::Loaded: return "Loaded";
        case PackageState::Invalid: return "Invalid";
        case PackageState::Disabled: return "Disabled";
    }
    return "Invalid";
}

PackageManager::PackageManager(std::filesystem::path packages_root, std::string foundation_version)
    : packages_root_(std::move(packages_root)), foundation_version_(std::move(foundation_version)) {}

DiscoverPackagesResult PackageManager::discover_packages() const {
    std::vector<std::string> names;

    std::error_code error_code;
    if (!std::filesystem::exists(packages_root_, error_code)) {
        return {true, "", names};
    }

    for (const std::filesystem::directory_entry& entry :
         std::filesystem::directory_iterator(packages_root_, error_code)) {
        if (!entry.is_directory()) {
            continue;
        }
        if (std::filesystem::exists(entry.path() / "package.json")) {
            names.push_back(entry.path().filename().string());
        }
    }

    if (error_code) {
        return {false, "could not enumerate '" + packages_root_.string() + "': " + error_code.message(), {}};
    }

    std::sort(names.begin(), names.end());
    return {true, "", names};
}

LoadPackageResult PackageManager::load_package(const std::string& package_directory_name) const {
    const std::filesystem::path package_directory = packages_root_ / package_directory_name;

    std::error_code error_code;
    if (!std::filesystem::is_directory(package_directory, error_code)) {
        return {false, "no package directory '" + package_directory_name + "'", {}};
    }

    DiscoveredPackage package;
    package.directory_name = package_directory_name;

    if (std::filesystem::exists(package_directory / ".disabled")) {
        package.state = PackageState::Disabled;
        return {true, "", package};
    }

    const std::filesystem::path manifest_path = package_directory / "package.json";
    if (!std::filesystem::exists(manifest_path)) {
        package.state = PackageState::Invalid;
        package.message = "missing package.json manifest";
        return {true, "", package};
    }

    const ParsedManifest parsed = read_manifest_file(manifest_path);
    if (!parsed.success) {
        package.state = PackageState::Invalid;
        package.message = parsed.error;
        return {true, "", package};
    }
    package.manifest = parsed.manifest;

    const std::vector<std::string> errors = validate_package_manifest(parsed.manifest);
    if (!errors.empty()) {
        std::string message = "manifest failed validation: ";
        for (std::size_t i = 0; i < errors.size(); ++i) {
            message += errors[i];
            if (i + 1 != errors.size()) message += "; ";
        }
        package.state = PackageState::Invalid;
        package.message = message;
        return {true, "", package};
    }

    if (!is_compatible_foundation_version(parsed.manifest.foundation_version, foundation_version_)) {
        package.state = PackageState::Invalid;
        package.message = "package requires Foundation " + parsed.manifest.foundation_version +
                           ", which is incompatible with the running Foundation " + foundation_version_;
        return {true, "", package};
    }

    package.state = PackageState::Loaded;
    return {true, "", package};
}

ListPackagesResult PackageManager::list_packages() const {
    const DiscoverPackagesResult discovered = discover_packages();
    if (!discovered.success) {
        return {false, discovered.error, {}};
    }

    std::vector<DiscoveredPackage> packages;
    for (const std::string& name : discovered.package_directory_names) {
        const LoadPackageResult loaded = load_package(name);
        if (!loaded.success) {
            return {false, loaded.error, {}};
        }
        packages.push_back(loaded.package);
    }

    // A packageId reused across more than one package directory cannot be
    // detected by load_package in isolation; check across the whole set
    // (in the deterministic order discover_packages produced) and demote
    // every package after the first with a given ID to Invalid.
    std::set<std::string> seen_package_ids;
    for (DiscoveredPackage& package : packages) {
        if (package.state != PackageState::Loaded || package.manifest.package_id.empty()) {
            continue;
        }
        if (!seen_package_ids.insert(package.manifest.package_id).second) {
            package.state = PackageState::Invalid;
            package.message = "duplicate packageId '" + package.manifest.package_id +
                               "' is already used by another package";
        }
    }

    return {true, "", packages};
}

} // namespace oep::packages
