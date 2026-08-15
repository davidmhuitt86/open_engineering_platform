#include "oep/archive/repository_template.hpp"

#include <algorithm>
#include <fstream>
#include <sstream>
#include <system_error>

#include "archive_codec.hpp"
#include "oep/repository/audit_store.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

namespace oep::archive {

namespace {

namespace json = oep::repository::json;

std::string join_errors(const std::vector<std::string>& errors) {
    std::string message;
    for (std::size_t i = 0; i < errors.size(); ++i) {
        message += errors[i];
        if (i + 1 != errors.size()) message += "; ";
    }
    return message;
}

template <typename T, typename KeyFn>
void sort_by_key(std::vector<T>& items, KeyFn key_fn) {
    std::sort(items.begin(), items.end(), [&key_fn](const T& a, const T& b) { return key_fn(a) < key_fn(b); });
}

struct ParsedTemplate {
    bool success = false;
    std::string error;
    TemplateManifest manifest;
    std::vector<oep::repository::EngineeringObject> objects;
    std::vector<oep::repository::Relationship> relationships;
    std::vector<oep::packages::PackageManifest> packages;
};

ParsedTemplate read_template_file(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {false, "could not open '" + path.string() + "'", {}, {}, {}, {}};
    }

    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();

    const json::ParseResult parsed = json::parse(contents_stream.str());
    if (!parsed.success) {
        return {false, "invalid JSON in '" + path.string() + "': " + parsed.error, {}, {}, {}, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "'" + path.string() + "' must contain a JSON object", {}, {}, {}, {}};
    }

    const json::Value* manifest_value = parsed.value.find("templateManifest");
    if (manifest_value == nullptr) {
        return {false, "'" + path.string() + "' is missing templateManifest", {}, {}, {}, {}};
    }
    const TemplateManifest manifest = archive_codec::template_manifest_from_json(*manifest_value);
    const std::vector<std::string> manifest_errors = validate_template_manifest(manifest);
    if (!manifest_errors.empty()) {
        return {false, "'" + path.string() + "' has an invalid manifest: " + join_errors(manifest_errors),
                manifest, {}, {}, {}};
    }

    ParsedTemplate result;
    result.manifest = manifest;

    if (const json::Value* objects_value = parsed.value.find("objects");
        objects_value != nullptr && objects_value->is_array()) {
        for (const json::Value& entry : objects_value->as_array()) {
            bool ok = false;
            oep::repository::EngineeringObject object = archive_codec::object_from_json(entry, ok);
            if (!ok) {
                return {false, "'" + path.string() + "' contains an object with an unrecognized objectType",
                        manifest, {}, {}, {}};
            }
            result.objects.push_back(std::move(object));
        }
    }

    if (const json::Value* relationships_value = parsed.value.find("relationships");
        relationships_value != nullptr && relationships_value->is_array()) {
        for (const json::Value& entry : relationships_value->as_array()) {
            bool ok = false;
            oep::repository::Relationship relationship = archive_codec::relationship_from_json(entry, ok);
            if (!ok) {
                return {false,
                        "'" + path.string() + "' contains a relationship with an unrecognized relationshipType",
                        manifest, {}, {}, {}};
            }
            result.relationships.push_back(std::move(relationship));
        }
    }

    if (const json::Value* packages_value = parsed.value.find("packages");
        packages_value != nullptr && packages_value->is_array()) {
        for (const json::Value& entry : packages_value->as_array()) {
            bool ok = false;
            oep::packages::PackageManifest package_manifest = archive_codec::package_manifest_from_json(entry, ok);
            if (!ok) {
                return {false, "'" + path.string() + "' contains a package with an unrecognized packageType",
                        manifest, {}, {}, {}};
            }
            result.packages.push_back(std::move(package_manifest));
        }
    }

    result.success = true;
    return result;
}

} // namespace

TemplateStore::TemplateStore(std::filesystem::path root) : root_(std::move(root)) {}

std::filesystem::path TemplateStore::path_for(const std::string& template_id) const {
    return root_ / (template_id + ".json");
}

CreateTemplateResult TemplateStore::create_template(const std::string& template_name, const std::string& description,
                                                     const std::string& author, const std::vector<std::string>& tags,
                                                     const std::string& foundation_version,
                                                     const oep::repository::ObjectStore& objects,
                                                     const oep::repository::RelationshipStore& relationships,
                                                     const oep::packages::PackageManager* packages) const {
    TemplateManifest manifest;
    manifest.template_id = oep::repository::generate_uuid_v4();
    manifest.template_name = template_name;
    manifest.description = description;
    manifest.author = author;
    manifest.tags = tags;
    manifest.foundation_version = foundation_version;

    const std::vector<std::string> manifest_errors = validate_template_manifest(manifest);
    if (!manifest_errors.empty()) {
        return {false, "refusing to create invalid template: " + join_errors(manifest_errors), {}};
    }

    const oep::repository::ListObjectsResult object_result = objects.list_all();
    if (!object_result.success) {
        return {false, "could not enumerate objects: " + object_result.error, {}};
    }
    const oep::repository::ListRelationshipsResult relationship_result = relationships.list_all();
    if (!relationship_result.success) {
        return {false, "could not enumerate relationships: " + relationship_result.error, {}};
    }

    std::vector<oep::packages::PackageManifest> package_manifests;
    if (packages != nullptr) {
        const oep::packages::ListPackagesResult package_result = packages->list_packages();
        if (!package_result.success) {
            return {false, "could not enumerate packages: " + package_result.error, {}};
        }
        for (const oep::packages::DiscoveredPackage& package : package_result.packages) {
            if (package.state == oep::packages::PackageState::Loaded) {
                package_manifests.push_back(package.manifest);
            }
        }
    }

    std::vector<oep::repository::EngineeringObject> sorted_objects = object_result.objects;
    sort_by_key(sorted_objects, [](const oep::repository::EngineeringObject& o) { return o.object_id; });
    std::vector<oep::repository::Relationship> sorted_relationships = relationship_result.relationships;
    sort_by_key(sorted_relationships, [](const oep::repository::Relationship& r) { return r.relationship_id; });
    sort_by_key(package_manifests, [](const oep::packages::PackageManifest& p) { return p.package_id; });

    json::Array objects_json;
    for (const oep::repository::EngineeringObject& object : sorted_objects) {
        objects_json.push_back(archive_codec::to_json(object));
    }
    json::Array relationships_json;
    for (const oep::repository::Relationship& relationship : sorted_relationships) {
        relationships_json.push_back(archive_codec::to_json(relationship));
    }
    json::Array packages_json;
    for (const oep::packages::PackageManifest& package_manifest : package_manifests) {
        packages_json.push_back(archive_codec::to_json(package_manifest));
    }

    json::Object root;
    root.emplace_back("templateManifest", archive_codec::to_json(manifest));
    root.emplace_back("objects", json::Value::array(std::move(objects_json)));
    root.emplace_back("relationships", json::Value::array(std::move(relationships_json)));
    root.emplace_back("packages", json::Value::array(std::move(packages_json)));

    const std::string serialized = json::serialize(json::Value::object(std::move(root)));

    std::error_code error_code;
    std::filesystem::create_directories(root_, error_code);
    if (error_code) {
        return {false, "could not create '" + root_.string() + "': " + error_code.message(), {}};
    }

    const std::filesystem::path path = path_for(manifest.template_id);
    const std::filesystem::path temp_path = path.string() + ".tmp";
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file) {
            return {false, "could not open '" + temp_path.string() + "' for writing", {}};
        }
        file << serialized;
    }
    std::filesystem::rename(temp_path, path, error_code);
    if (error_code) {
        std::filesystem::remove(temp_path, error_code);
        return {false, "could not finalize '" + path.string() + "': " + error_code.message(), {}};
    }

    return {true, "", manifest};
}

ListTemplatesResult TemplateStore::list_templates() const {
    std::vector<TemplateManifest> manifests;

    std::error_code error_code;
    if (!std::filesystem::exists(root_, error_code)) {
        return {true, "", manifests};
    }

    for (const std::filesystem::directory_entry& entry :
         std::filesystem::directory_iterator(root_, error_code)) {
        if (!entry.is_regular_file() || entry.path().extension() != ".json") {
            continue;
        }
        const ParsedTemplate parsed = read_template_file(entry.path());
        if (!parsed.success) {
            continue; // invalid templates are excluded from listing, not reported as a fatal error
        }
        manifests.push_back(parsed.manifest);
    }

    if (error_code) {
        return {false, "could not enumerate '" + root_.string() + "': " + error_code.message(), {}};
    }

    sort_by_key(manifests, [](const TemplateManifest& m) { return m.template_id; });
    return {true, "", manifests};
}

InstantiateTemplateResult TemplateStore::instantiate_template(const std::string& template_id,
                                                                const std::filesystem::path& destination,
                                                                const std::string& new_repository_name) const {
    const std::filesystem::path path = path_for(template_id);
    if (!std::filesystem::exists(path)) {
        return {false, "no template with id '" + template_id + "'"};
    }

    const ParsedTemplate parsed = read_template_file(path);
    if (!parsed.success) {
        return {false, "template '" + template_id + "' is invalid and cannot be instantiated: " + parsed.error};
    }

    std::error_code error_code;
    if (std::filesystem::exists(destination, error_code) && !std::filesystem::is_empty(destination, error_code)) {
        return {false, "destination '" + destination.string() + "' already exists and is not empty"};
    }
    std::filesystem::create_directories(destination, error_code);
    if (error_code) {
        return {false, "could not create destination '" + destination.string() + "': " + error_code.message()};
    }

    oep::repository::RepositoryMetadata metadata;
    metadata.repository_id = oep::repository::generate_uuid_v4();
    metadata.repository_name = new_repository_name;
    metadata.repository_version = "1.0.0";
    metadata.foundation_version = parsed.manifest.foundation_version;
    metadata.template_version = parsed.manifest.version;
    metadata.created_utc = oep::repository::current_timestamp_utc();
    metadata.description = "Instantiated from template '" + parsed.manifest.template_name + "'";

    const oep::repository::SaveMetadataResult metadata_save =
        oep::repository::save_metadata(destination / "repository.json", metadata);
    if (!metadata_save.success) {
        return {false, "could not write repository metadata: " + metadata_save.error};
    }

    oep::repository::AuditStore audit(destination / "repository" / "audit");
    oep::repository::ObjectStore objects(destination / "repository" / "objects", audit);
    oep::repository::RelationshipStore relationships(destination / "repository" / "relationships", objects, audit);

    for (const oep::repository::EngineeringObject& object : parsed.objects) {
        const oep::repository::LoadObjectResult result = objects.restore(object);
        if (!result.success) {
            return {false, "could not instantiate object '" + object.object_id + "': " + result.error};
        }
    }
    for (const oep::repository::Relationship& relationship : parsed.relationships) {
        const oep::repository::LoadRelationshipResult result = relationships.restore(relationship);
        if (!result.success) {
            return {false,
                    "could not instantiate relationship '" + relationship.relationship_id + "': " + result.error};
        }
    }
    for (const oep::packages::PackageManifest& package_manifest : parsed.packages) {
        const std::filesystem::path package_dir = destination / "packages" / package_manifest.package_id;
        std::filesystem::create_directories(package_dir, error_code);
        if (error_code) {
            return {false, "could not create package directory '" + package_dir.string() + "': " +
                               error_code.message()};
        }
        std::ofstream manifest_file(package_dir / "package.json", std::ios::binary | std::ios::trunc);
        if (!manifest_file) {
            return {false, "could not write package manifest to '" + package_dir.string() + "'"};
        }
        manifest_file << json::serialize(archive_codec::to_json(package_manifest));
    }

    return {true, ""};
}

} // namespace oep::archive
