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
    return result;
}

} // namespace oep::installer
