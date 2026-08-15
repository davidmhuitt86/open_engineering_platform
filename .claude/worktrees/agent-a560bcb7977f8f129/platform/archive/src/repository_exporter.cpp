#include "oep/archive/repository_exporter.hpp"

#include <algorithm>
#include <fstream>
#include <system_error>

#include "archive_codec.hpp"
#include "oep/repository/timestamp.hpp"

namespace oep::archive {

namespace {

namespace json = oep::repository::json;

template <typename T, typename KeyFn>
void sort_by_key(std::vector<T>& items, KeyFn key_fn) {
    std::sort(items.begin(), items.end(), [&key_fn](const T& a, const T& b) { return key_fn(a) < key_fn(b); });
}

} // namespace

ExportResult export_repository(const oep::repository::RepositoryMetadata& metadata,
                                const oep::repository::ObjectStore& objects,
                                const oep::repository::RelationshipStore& relationships,
                                const oep::repository::AuditStore& audit,
                                const oep::packages::PackageManager* packages,
                                const std::filesystem::path& output_file) {
    const oep::repository::ListObjectsResult object_result = objects.list_all();
    if (!object_result.success) {
        return {false, "could not enumerate objects: " + object_result.error, {}};
    }
    const oep::repository::ListRelationshipsResult relationship_result = relationships.list_all();
    if (!relationship_result.success) {
        return {false, "could not enumerate relationships: " + relationship_result.error, {}};
    }
    const oep::repository::ListAuditEventsResult audit_result = audit.list_events();
    if (!audit_result.success) {
        return {false, "could not enumerate audit events: " + audit_result.error, {}};
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

    // Deterministic ordering: sort each section by its natural ID. Audit
    // events are already sorted by list_events() (timestamp then eventId).
    std::vector<oep::repository::EngineeringObject> sorted_objects = object_result.objects;
    sort_by_key(sorted_objects, [](const oep::repository::EngineeringObject& o) { return o.object_id; });

    std::vector<oep::repository::Relationship> sorted_relationships = relationship_result.relationships;
    sort_by_key(sorted_relationships, [](const oep::repository::Relationship& r) { return r.relationship_id; });

    sort_by_key(package_manifests, [](const oep::packages::PackageManifest& p) { return p.package_id; });

    ExportManifest manifest;
    manifest.export_version = kSupportedExportVersion;
    manifest.export_timestamp_utc = oep::repository::current_timestamp_utc();
    manifest.repository_id = metadata.repository_id;
    manifest.repository_version = metadata.repository_version;
    manifest.object_count = static_cast<int>(sorted_objects.size());
    manifest.relationship_count = static_cast<int>(sorted_relationships.size());
    manifest.package_count = static_cast<int>(package_manifests.size());

    json::Array objects_json;
    for (const oep::repository::EngineeringObject& object : sorted_objects) {
        objects_json.push_back(archive_codec::to_json(object));
    }

    json::Array relationships_json;
    for (const oep::repository::Relationship& relationship : sorted_relationships) {
        relationships_json.push_back(archive_codec::to_json(relationship));
    }

    json::Array audit_json;
    for (const oep::repository::AuditEvent& event : audit_result.events) {
        audit_json.push_back(archive_codec::to_json(event));
    }

    json::Object root;
    root.emplace_back("exportManifest", archive_codec::to_json(manifest));
    root.emplace_back("repositoryMetadata", archive_codec::to_json(metadata));
    root.emplace_back("objects", json::Value::array(std::move(objects_json)));
    root.emplace_back("relationships", json::Value::array(std::move(relationships_json)));
    root.emplace_back("auditEvents", json::Value::array(std::move(audit_json)));

    if (packages != nullptr) {
        json::Array packages_json;
        for (const oep::packages::PackageManifest& package_manifest : package_manifests) {
            packages_json.push_back(archive_codec::to_json(package_manifest));
        }
        root.emplace_back("packages", json::Value::array(std::move(packages_json)));
    }

    const std::string serialized = json::serialize(json::Value::object(std::move(root)));

    const std::filesystem::path temp_path = output_file.string() + ".tmp";
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file) {
            return {false, "could not open '" + temp_path.string() + "' for writing", {}};
        }
        file << serialized;
        if (!file) {
            return {false, "failed writing archive contents to '" + temp_path.string() + "'", {}};
        }
    }

    std::error_code error_code;
    std::filesystem::rename(temp_path, output_file, error_code);
    if (error_code) {
        std::filesystem::remove(temp_path, error_code);
        return {false, "could not finalize '" + output_file.string() + "': " + error_code.message(), {}};
    }

    return {true, "", manifest};
}

} // namespace oep::archive
