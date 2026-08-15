#include "oep/installer/oep_package_manifest.hpp"

#include "oep/repository/json_value.hpp"

namespace oep::installer {

namespace {

namespace json = oep::repository::json;

bool has_field(const json::Value& value, const char* key) {
    return value.find(key) != nullptr;
}

bool is_non_empty_string(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return found != nullptr && found->is_string() && !found->as_string().empty();
}

bool is_array(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return found != nullptr && found->is_array();
}

bool is_object(const json::Value& value, const char* key) {
    const json::Value* found = value.find(key);
    return found != nullptr && found->is_object();
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

bool read_bool_field(const json::Value& value, const char* key, bool default_value) {
    const json::Value* found = value.find(key);
    return (found != nullptr && found->is_bool()) ? found->as_bool() : default_value;
}

// Parses the `dependencies` array (already confirmed present and array-
// typed by the required-field/array-field checks above). Each entry
// shall be an object with a non-empty `packageId`; `version` and
// `optional` are themselves optional (an absent `version` constrains
// nothing, matching PKG-004 §7's "installation cannot proceed without
// it" for a *package*, independent of version). A malformed entry
// (not an object, or missing packageId) is reported as an error rather
// than silently skipped, per PKG-002 §20 "a manifest either
// implementation accepts, the other does too" — a manifest good enough
// to install should not have silently-ignored dependency entries.
bool parse_dependencies(const json::Value& root, std::vector<DependencyDeclaration>& out_dependencies,
                         std::vector<std::string>& out_errors) {
    const json::Value* found = root.find("dependencies");
    if (found == nullptr || !found->is_array()) {
        return true; // presence/type already reported by the caller's own checks
    }
    bool all_valid = true;
    for (const json::Value& entry : found->as_array()) {
        if (!entry.is_object()) {
            out_errors.push_back("manifest field 'dependencies' contains a non-object entry");
            all_valid = false;
            continue;
        }
        if (!is_non_empty_string(entry, "packageId")) {
            out_errors.push_back("manifest field 'dependencies' contains an entry missing a non-empty 'packageId'");
            all_valid = false;
            continue;
        }
        DependencyDeclaration dependency;
        dependency.package_id = read_string_field(entry, "packageId");
        dependency.version_constraint = read_string_field(entry, "version");
        dependency.optional = read_bool_field(entry, "optional", false);
        out_dependencies.push_back(std::move(dependency));
    }
    return all_valid;
}

} // namespace

ParseManifestResult parse_oep_package_manifest(const std::string& manifest_json) {
    ParseManifestResult result;

    const json::ParseResult parsed = json::parse(manifest_json);
    if (!parsed.success) {
        result.errors.push_back("the manifest is not valid JSON: " + parsed.error);
        return result;
    }
    if (!parsed.value.is_object()) {
        result.errors.push_back("the manifest must be a JSON object");
        return result;
    }
    const json::Value& root = parsed.value;

    // PKG-002 §5's sixteen required top-level fields.
    static const char* kRequiredFields[] = {
        "schemaVersion", "packageId",   "version",     "publisher",   "title",     "summary",
        "description",   "category",    "engineeringDomains", "license", "dependencies",
        "capabilities",  "repository",  "statistics",  "signatures",  "build",
    };
    for (const char* field : kRequiredFields) {
        if (!has_field(root, field)) {
            result.errors.push_back(std::string("manifest is missing required field '") + field + "'");
        }
    }

    // String fields (PKG-002 §5) must be non-empty strings.
    static const char* kStringFields[] = {
        "schemaVersion", "packageId", "version", "title", "summary", "description", "category",
    };
    for (const char* field : kStringFields) {
        if (has_field(root, field) && !is_non_empty_string(root, field)) {
            result.errors.push_back(std::string("manifest field '") + field + "' must be a non-empty string");
        }
    }

    // Array fields.
    static const char* kArrayFields[] = {"engineeringDomains", "dependencies", "capabilities"};
    for (const char* field : kArrayFields) {
        if (has_field(root, field) && !is_array(root, field)) {
            result.errors.push_back(std::string("manifest field '") + field + "' must be an array");
        }
    }

    // Object fields.
    static const char* kObjectFields[] = {"publisher", "license", "repository", "statistics", "signatures", "build"};
    for (const char* field : kObjectFields) {
        if (has_field(root, field) && !is_object(root, field)) {
            result.errors.push_back(std::string("manifest field '") + field + "' must be an object");
        }
    }

    // publisher.id / publisher.name (PKG-002 §9).
    std::string publisher_id;
    std::string publisher_name;
    if (is_object(root, "publisher")) {
        const json::Value& publisher = *root.find("publisher");
        if (!is_non_empty_string(publisher, "id")) {
            result.errors.push_back("manifest field 'publisher.id' must be a non-empty string");
        } else {
            publisher_id = read_string_field(publisher, "id");
        }
        if (!is_non_empty_string(publisher, "name")) {
            result.errors.push_back("manifest field 'publisher.name' must be a non-empty string");
        } else {
            publisher_name = read_string_field(publisher, "name");
        }
    }

    std::vector<DependencyDeclaration> dependencies;
    parse_dependencies(root, dependencies, result.errors);

    if (!result.errors.empty()) {
        return result;
    }

    result.success = true;
    result.manifest.schema_version = read_string_field(root, "schemaVersion");
    result.manifest.package_id = read_string_field(root, "packageId");
    result.manifest.version = read_string_field(root, "version");
    result.manifest.publisher_id = publisher_id;
    result.manifest.publisher_name = publisher_name;
    result.manifest.title = read_string_field(root, "title");
    result.manifest.summary = read_string_field(root, "summary");
    result.manifest.description = read_string_field(root, "description");
    result.manifest.category = read_string_field(root, "category");
    result.manifest.engineering_domains = read_string_array_field(root, "engineeringDomains");
    result.manifest.dependencies = std::move(dependencies);
    return result;
}

} // namespace oep::installer
