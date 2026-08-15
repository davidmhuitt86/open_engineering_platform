#include "oep/installer/package_installer.hpp"

#include <algorithm>
#include <optional>

#include "oep/installer/zip_reader.hpp"
#include "oep/repository/json_value.hpp"

namespace oep::installer {

namespace {

namespace json = oep::repository::json;
using oep::repository::EngineeringObject;
using oep::repository::ObjectType;
using oep::repository::Relationship;
using oep::repository::RelationshipType;

constexpr const char* kManifestEntryPath = "manifest/package.json";

// PKG-001 §5's in-archive Repository Fragment directory, ratified as
// `fragment/` in WP-REP-002 (OEP-ARCH-002 §0.2(b)) — "the package
// contains a Repository Fragment, not an entire Repository". A `.oep`
// archive built before this rename still uses the legacy `repository/`
// name; extract_package() below accepts either, preferring `fragment/`
// when both are somehow present, so already-published archives remain
// installable (least-disruptive migration path, per WP-REP-002's own
// backward-compatibility requirement) without this module ever having to
// guess which convention a given archive used.
constexpr const char* kFragmentObjectsPrefix = "fragment/objects/";
constexpr const char* kFragmentRelationshipsPrefix = "fragment/relationships/";
constexpr const char* kLegacyObjectsPrefix = "repository/objects/";
constexpr const char* kLegacyRelationshipsPrefix = "repository/relationships/";
constexpr const char* kJsonSuffix = ".json";

bool has_prefix(const std::string& value, const std::string& prefix) {
    return value.size() >= prefix.size() && value.compare(0, prefix.size(), prefix) == 0;
}

bool has_suffix(const std::string& value, const std::string& suffix) {
    return value.size() >= suffix.size() && value.compare(value.size() - suffix.size(), suffix.size(), suffix) == 0;
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

// Reads one Repository Fragment object entry, in the exact camelCase JSON
// convention ObjectStore::create/list_all already read and write on disk
// (objectId, objectType, name, description, createdUtc, lastModifiedUtc,
// version, author, tags). object_id/created_utc/last_modified_utc may be
// blank — ObjectStore::create fills in whatever is missing, exactly as it
// already does for an ordinary create() call; that's why this function
// does not itself enforce UUIDv4/timestamp presence (see
// package_installer.hpp's own doc comment).
std::optional<EngineeringObject> parse_object_entry(const std::string& entry_name, const std::string& text,
                                                      std::string& out_error) {
    const json::ParseResult parsed = json::parse(text);
    if (!parsed.success) {
        out_error = "'" + entry_name + "' is not valid JSON: " + parsed.error;
        return std::nullopt;
    }
    if (!parsed.value.is_object()) {
        out_error = "'" + entry_name + "' must contain a JSON object";
        return std::nullopt;
    }

    const std::string type_name = read_string_field(parsed.value, "objectType");
    const std::optional<ObjectType> object_type = oep::repository::object_type_from_string(type_name);
    if (!object_type.has_value()) {
        out_error = "'" + entry_name + "' has an unrecognized objectType '" + type_name + "'";
        return std::nullopt;
    }

    EngineeringObject object;
    object.object_id = read_string_field(parsed.value, "objectId");
    object.object_type = *object_type;
    object.name = read_string_field(parsed.value, "name");
    object.description = read_string_field(parsed.value, "description");
    object.created_utc = read_string_field(parsed.value, "createdUtc");
    object.last_modified_utc = read_string_field(parsed.value, "lastModifiedUtc");
    object.version = read_string_field(parsed.value, "version");
    object.author = read_string_field(parsed.value, "author");
    object.tags = read_string_array_field(parsed.value, "tags");

    if (object.name.empty()) {
        out_error = "'" + entry_name + "' is missing a required 'name'";
        return std::nullopt;
    }
    if (object.version.empty()) {
        object.version = "1.0.0";
    }

    return object;
}

// Reads one Repository Fragment relationship entry (relationshipId,
// sourceObjectId, targetObjectId, relationshipType, createdUtc, author,
// description). relationship_id/created_utc may be blank — same reasoning
// as parse_object_entry.
std::optional<Relationship> parse_relationship_entry(const std::string& entry_name, const std::string& text,
                                                        std::string& out_error) {
    const json::ParseResult parsed = json::parse(text);
    if (!parsed.success) {
        out_error = "'" + entry_name + "' is not valid JSON: " + parsed.error;
        return std::nullopt;
    }
    if (!parsed.value.is_object()) {
        out_error = "'" + entry_name + "' must contain a JSON object";
        return std::nullopt;
    }

    const std::string type_name = read_string_field(parsed.value, "relationshipType");
    const std::optional<RelationshipType> relationship_type =
        oep::repository::relationship_type_from_string(type_name);
    if (!relationship_type.has_value()) {
        out_error = "'" + entry_name + "' has an unrecognized relationshipType '" + type_name + "'";
        return std::nullopt;
    }

    Relationship relationship;
    relationship.relationship_id = read_string_field(parsed.value, "relationshipId");
    relationship.source_object_id = read_string_field(parsed.value, "sourceObjectId");
    relationship.target_object_id = read_string_field(parsed.value, "targetObjectId");
    relationship.relationship_type = *relationship_type;
    relationship.created_utc = read_string_field(parsed.value, "createdUtc");
    relationship.author = read_string_field(parsed.value, "author");
    relationship.description = read_string_field(parsed.value, "description");

    if (relationship.source_object_id.empty() || relationship.target_object_id.empty()) {
        out_error = "'" + entry_name + "' must specify both sourceObjectId and targetObjectId";
        return std::nullopt;
    }

    return relationship;
}

} // namespace

ExtractPackageResult extract_package(const std::filesystem::path& archive_path) {
    ExtractPackageResult result;

    std::string error;
    std::optional<ZipReader> reader = ZipReader::open(archive_path, error);
    if (!reader.has_value()) {
        result.error = error;
        return result;
    }

    if (!reader->has_entry(kManifestEntryPath)) {
        result.error =
            "'" + archive_path.string() + "' does not contain a manifest at '" + std::string(kManifestEntryPath) + "'";
        return result;
    }
    const std::optional<std::string> manifest_json = reader->read_text(kManifestEntryPath, error);
    if (!manifest_json.has_value()) {
        result.error = error;
        return result;
    }

    const ParseManifestResult parsed_manifest = parse_oep_package_manifest(*manifest_json);
    if (!parsed_manifest.success) {
        result.error = "manifest is invalid: ";
        for (std::size_t i = 0; i < parsed_manifest.errors.size(); ++i) {
            result.error += parsed_manifest.errors[i];
            if (i + 1 != parsed_manifest.errors.size()) result.error += "; ";
        }
        return result;
    }

    ExtractedPackage package;
    package.manifest = parsed_manifest.manifest;

    // Repository Fragment (PKG-001 §7) — collected in sorted (deterministic,
    // PKG-001 §2) filename order, not archive Central Directory order.
    // Prefer the ratified `fragment/` directory; fall back to the legacy
    // `repository/` directory only if no `fragment/` entries exist at all,
    // so an archive cannot accidentally mix the two conventions.
    const std::vector<std::string> entry_names = reader->entry_names();
    const bool uses_fragment_naming =
        std::any_of(entry_names.begin(), entry_names.end(),
                    [](const std::string& name) { return has_prefix(name, "fragment/"); });
    const std::string objects_prefix = uses_fragment_naming ? kFragmentObjectsPrefix : kLegacyObjectsPrefix;
    const std::string relationships_prefix =
        uses_fragment_naming ? kFragmentRelationshipsPrefix : kLegacyRelationshipsPrefix;

    std::vector<std::string> object_entries;
    std::vector<std::string> relationship_entries;
    for (const std::string& name : entry_names) {
        if (has_prefix(name, objects_prefix) && has_suffix(name, kJsonSuffix)) {
            object_entries.push_back(name);
        } else if (has_prefix(name, relationships_prefix) && has_suffix(name, kJsonSuffix)) {
            relationship_entries.push_back(name);
        }
    }
    std::sort(object_entries.begin(), object_entries.end());
    std::sort(relationship_entries.begin(), relationship_entries.end());

    for (const std::string& entry_name : object_entries) {
        const std::optional<std::string> text = reader->read_text(entry_name, error);
        if (!text.has_value()) {
            result.error = error;
            return result;
        }
        const std::optional<EngineeringObject> object = parse_object_entry(entry_name, *text, error);
        if (!object.has_value()) {
            result.error = error;
            return result;
        }
        package.objects.push_back(*object);
    }

    for (const std::string& entry_name : relationship_entries) {
        const std::optional<std::string> text = reader->read_text(entry_name, error);
        if (!text.has_value()) {
            result.error = error;
            return result;
        }
        const std::optional<Relationship> relationship = parse_relationship_entry(entry_name, *text, error);
        if (!relationship.has_value()) {
            result.error = error;
            return result;
        }
        package.relationships.push_back(*relationship);
    }

    result.success = true;
    result.package = std::move(package);
    return result;
}

} // namespace oep::installer
