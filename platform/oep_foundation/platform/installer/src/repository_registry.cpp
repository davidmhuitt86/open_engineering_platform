#include "oep/installer/repository_registry.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <sstream>
#include <system_error>

#include "oep/repository/json_value.hpp"

namespace oep::installer {

namespace {

namespace json = oep::repository::json;

json::Value string_array_to_json(const std::vector<std::string>& values) {
    json::Array array;
    for (const std::string& value : values) {
        array.push_back(json::Value::string(value));
    }
    return json::Value::array(std::move(array));
}

json::Value dependencies_to_json(const std::vector<DependencyDeclaration>& dependencies) {
    json::Array array;
    for (const DependencyDeclaration& dependency : dependencies) {
        json::Object fields;
        fields.emplace_back("packageId", json::Value::string(dependency.package_id));
        fields.emplace_back("version", json::Value::string(dependency.version_constraint));
        fields.emplace_back("optional", json::Value::boolean(dependency.optional));
        array.push_back(json::Value::object(std::move(fields)));
    }
    return json::Value::array(std::move(array));
}

json::Value to_json(const RepositoryRegistryEntry& entry) {
    json::Object fields;
    fields.emplace_back("packageId", json::Value::string(entry.package_id));
    fields.emplace_back("version", json::Value::string(entry.version));
    fields.emplace_back("title", json::Value::string(entry.title));
    fields.emplace_back("summary", json::Value::string(entry.summary));
    fields.emplace_back("category", json::Value::string(entry.category));
    fields.emplace_back("schemaVersion", json::Value::string(entry.schema_version));
    fields.emplace_back("engineeringDomains", string_array_to_json(entry.engineering_domains));
    fields.emplace_back("publisherId", json::Value::string(entry.publisher_id));
    fields.emplace_back("publisherName", json::Value::string(entry.publisher_name));
    fields.emplace_back("installedUtc", json::Value::string(entry.installed_utc));
    fields.emplace_back("source", json::Value::string(entry.source));
    fields.emplace_back("installationPath", json::Value::string(entry.installation_path));
    fields.emplace_back("packageHash", json::Value::string(entry.package_hash));
    fields.emplace_back("runtimeState", json::Value::string(entry.runtime_state));
    fields.emplace_back("trustStatus", json::Value::string(entry.trust_status));
    fields.emplace_back("trustFingerprint", json::Value::string(entry.trust_fingerprint));
    fields.emplace_back("dependencies", dependencies_to_json(entry.dependencies));
    fields.emplace_back("objectIds", string_array_to_json(entry.object_ids));
    fields.emplace_back("relationshipIds", string_array_to_json(entry.relationship_ids));
    return json::Value::object(std::move(fields));
}

std::string read_string_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_string()) ? found->as_string() : std::string();
}

std::vector<std::string> read_string_array_field(const json::Value& value, const char* key) {
    std::vector<std::string> result;
    const json::Value* found = value.find(key);
    if (found == nullptr || !found->is_array()) {
        return result;
    }
    for (const json::Value& entry : found->as_array()) {
        if (entry.is_string()) {
            result.push_back(entry.as_string());
        }
    }
    return result;
}

bool read_bool_field(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return found != nullptr && found->is_bool() && found->as_bool();
}

std::vector<DependencyDeclaration> read_dependencies_field(const json::Value& value) {
    std::vector<DependencyDeclaration> result;
    const json::Value* found = value.find("dependencies");
    if (found == nullptr || !found->is_array()) {
        return result;
    }
    for (const json::Value& entry : found->as_array()) {
        if (!entry.is_object()) {
            continue;
        }
        DependencyDeclaration dependency;
        dependency.package_id = read_string_field(entry, "packageId");
        dependency.version_constraint = read_string_field(entry, "version");
        dependency.optional = read_bool_field(entry, "optional");
        if (!dependency.package_id.empty()) {
            result.push_back(std::move(dependency));
        }
    }
    return result;
}

struct ParsedRecord {
    bool success = false;
    std::string error;
    RepositoryRegistryEntry entry;
};

ParsedRecord read_registry_file(const std::filesystem::path& path) {
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

    RepositoryRegistryEntry entry;
    entry.package_id = read_string_field(parsed.value, "packageId");
    entry.version = read_string_field(parsed.value, "version");
    entry.title = read_string_field(parsed.value, "title");
    entry.summary = read_string_field(parsed.value, "summary");
    entry.category = read_string_field(parsed.value, "category");
    entry.schema_version = read_string_field(parsed.value, "schemaVersion");
    entry.engineering_domains = read_string_array_field(parsed.value, "engineeringDomains");
    entry.publisher_id = read_string_field(parsed.value, "publisherId");
    entry.publisher_name = read_string_field(parsed.value, "publisherName");
    entry.installed_utc = read_string_field(parsed.value, "installedUtc");
    entry.source = read_string_field(parsed.value, "source");
    entry.installation_path = read_string_field(parsed.value, "installationPath");
    entry.package_hash = read_string_field(parsed.value, "packageHash");
    entry.runtime_state = read_string_field(parsed.value, "runtimeState");
    entry.trust_status = read_string_field(parsed.value, "trustStatus");
    entry.trust_fingerprint = read_string_field(parsed.value, "trustFingerprint");
    entry.dependencies = read_dependencies_field(parsed.value);
    entry.object_ids = read_string_array_field(parsed.value, "objectIds");
    entry.relationship_ids = read_string_array_field(parsed.value, "relationshipIds");
    return {true, "", entry};
}

std::string to_lower(const std::string& value) {
    std::string result = value;
    std::transform(result.begin(), result.end(), result.begin(),
                    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return result;
}

bool contains_case_insensitive(const std::string& haystack, const std::string& needle_lower) {
    return to_lower(haystack).find(needle_lower) != std::string::npos;
}

bool matches_query(const RepositoryRegistryEntry& entry, const std::string& query_lower) {
    if (contains_case_insensitive(entry.package_id, query_lower) ||
        contains_case_insensitive(entry.title, query_lower) ||
        contains_case_insensitive(entry.summary, query_lower) ||
        contains_case_insensitive(entry.category, query_lower) ||
        contains_case_insensitive(entry.version, query_lower) ||
        contains_case_insensitive(entry.publisher_id, query_lower) ||
        contains_case_insensitive(entry.publisher_name, query_lower)) {
        return true;
    }
    for (const std::string& domain : entry.engineering_domains) {
        if (contains_case_insensitive(domain, query_lower)) {
            return true;
        }
    }
    return false;
}

} // namespace

RepositoryRegistry::RepositoryRegistry(std::filesystem::path packages_root) : packages_root_(std::move(packages_root)) {}

std::filesystem::path RepositoryRegistry::path_for(const std::string& package_id) const {
    return packages_root_ / package_id / "registry.json";
}

RegistryResult RepositoryRegistry::record_install(const RepositoryRegistryEntry& entry) const {
    if (entry.package_id.empty()) {
        return {false, "cannot record an installed package with an empty packageId"};
    }

    const std::filesystem::path path = path_for(entry.package_id);

    std::error_code error_code;
    if (std::filesystem::exists(path, error_code)) {
        return {false, "package '" + entry.package_id + "' is already recorded as installed"};
    }

    std::filesystem::create_directories(path.parent_path(), error_code);
    if (error_code) {
        return {false, "could not create '" + path.parent_path().string() + "': " + error_code.message()};
    }

    const std::string serialized = json::serialize(to_json(entry));
    const std::filesystem::path temp_path = path.string() + ".tmp";
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file) {
            return {false, "could not open '" + temp_path.string() + "' for writing"};
        }
        file << serialized;
    }
    std::filesystem::rename(temp_path, path, error_code);
    if (error_code) {
        std::filesystem::remove(temp_path, error_code);
        return {false, "could not finalize '" + path.string() + "': " + error_code.message()};
    }

    return {true, ""};
}

RegistryResult RepositoryRegistry::remove_record(const std::string& package_id) const {
    const std::filesystem::path path = path_for(package_id);

    std::error_code error_code;
    if (!std::filesystem::exists(path, error_code)) {
        return {false, "package '" + package_id + "' has no Repository Registry record"};
    }

    std::filesystem::remove(path, error_code);
    if (error_code) {
        return {false, "could not remove '" + path.string() + "': " + error_code.message()};
    }
    // Best-effort: remove the now-empty <packages_root>/<packageId>/
    // directory too. Not an error if it fails or isn't empty (it
    // shouldn't be anything else, but a stray file left by a future
    // Work Package should never turn a successful uninstall into a
    // reported failure).
    std::filesystem::remove(path.parent_path(), error_code);

    return {true, ""};
}

IsInstalledResult RepositoryRegistry::is_installed(const std::string& package_id) const {
    const std::filesystem::path path = path_for(package_id);

    std::error_code error_code;
    if (!std::filesystem::exists(path, error_code)) {
        return {true, "", false, {}};
    }

    const ParsedRecord parsed = read_registry_file(path);
    if (!parsed.success) {
        return {false, parsed.error, false, {}};
    }
    return {true, "", true, parsed.entry};
}

ListInstalledResult RepositoryRegistry::list_installed() const {
    std::vector<RepositoryRegistryEntry> packages;

    std::error_code error_code;
    if (!std::filesystem::exists(packages_root_, error_code)) {
        return {true, "", packages};
    }

    for (const std::filesystem::directory_entry& dir_entry :
         std::filesystem::directory_iterator(packages_root_, error_code)) {
        if (!dir_entry.is_directory()) {
            continue;
        }
        const std::filesystem::path registry_file = dir_entry.path() / "registry.json";
        if (!std::filesystem::exists(registry_file)) {
            continue;
        }
        const ParsedRecord parsed = read_registry_file(registry_file);
        if (parsed.success) {
            packages.push_back(parsed.entry);
        }
    }

    if (error_code) {
        return {false, "could not enumerate '" + packages_root_.string() + "': " + error_code.message(), {}};
    }

    return {true, "", packages};
}

FindOwnerResult RepositoryRegistry::find_owner(const std::string& entity_id) const {
    const ListInstalledResult listed = list_installed();
    if (!listed.success) {
        return {false, listed.error, OwnedEntityKind::None, {}};
    }

    for (const RepositoryRegistryEntry& entry : listed.packages) {
        if (std::find(entry.object_ids.begin(), entry.object_ids.end(), entity_id) != entry.object_ids.end()) {
            return {true, "", OwnedEntityKind::Object, entry};
        }
        if (std::find(entry.relationship_ids.begin(), entry.relationship_ids.end(), entity_id) !=
            entry.relationship_ids.end()) {
            return {true, "", OwnedEntityKind::Relationship, entry};
        }
    }

    return {true, "", OwnedEntityKind::None, {}};
}

SearchPackagesResult RepositoryRegistry::search_packages(const std::string& query) const {
    const ListInstalledResult listed = list_installed();
    if (!listed.success) {
        return {false, listed.error, {}};
    }

    const std::string query_lower = to_lower(query);
    std::vector<RepositoryRegistryEntry> matches;
    for (const RepositoryRegistryEntry& entry : listed.packages) {
        if (matches_query(entry, query_lower)) {
            matches.push_back(entry);
        }
    }
    return {true, "", matches};
}

} // namespace oep::installer
