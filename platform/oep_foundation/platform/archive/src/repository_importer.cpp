#include "oep/archive/repository_importer.hpp"

#include <fstream>
#include <sstream>
#include <system_error>

#include "archive_codec.hpp"
#include "oep/repository/audit_store.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship_store.hpp"

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

} // namespace

ImportResult import_repository(const std::filesystem::path& archive_file, const std::filesystem::path& destination,
                                bool overwrite) {
    std::ifstream file(archive_file, std::ios::binary);
    if (!file) {
        return {false, "could not open archive '" + archive_file.string() + "'", {}};
    }

    std::ostringstream contents_stream;
    contents_stream << file.rdbuf();

    const json::ParseResult parsed = json::parse(contents_stream.str());
    if (!parsed.success) {
        return {false, "archive '" + archive_file.string() + "' is not valid JSON: " + parsed.error, {}};
    }
    if (!parsed.value.is_object()) {
        return {false, "archive '" + archive_file.string() + "' must contain a JSON object", {}};
    }

    const json::Value* manifest_value = parsed.value.find("exportManifest");
    if (manifest_value == nullptr) {
        return {false, "archive is missing exportManifest", {}};
    }
    const ExportManifest manifest = archive_codec::export_manifest_from_json(*manifest_value);
    const std::vector<std::string> manifest_errors = validate_export_manifest(manifest);
    if (!manifest_errors.empty()) {
        return {false, "corrupted export manifest: " + join_errors(manifest_errors), {}};
    }
    if (manifest.export_version != kSupportedExportVersion) {
        return {false, "unsupported export version '" + manifest.export_version + "' (this build supports '" +
                           kSupportedExportVersion + "')",
                {}};
    }

    const json::Value* metadata_value = parsed.value.find("repositoryMetadata");
    if (metadata_value == nullptr) {
        return {false, "archive is missing repositoryMetadata", manifest};
    }
    const oep::repository::RepositoryMetadata metadata = archive_codec::metadata_from_json(*metadata_value);
    const std::vector<std::string> metadata_errors = oep::repository::validate_metadata(metadata);
    if (!metadata_errors.empty()) {
        return {false, "invalid repository metadata in archive: " + join_errors(metadata_errors), manifest};
    }

    // Parse (and validate the shape of) every record before writing
    // anything, so a corrupt archive never partially populates destination.
    std::vector<oep::repository::EngineeringObject> objects_to_restore;
    if (const json::Value* objects_value = parsed.value.find("objects");
        objects_value != nullptr && objects_value->is_array()) {
        for (const json::Value& entry : objects_value->as_array()) {
            bool ok = false;
            oep::repository::EngineeringObject object = archive_codec::object_from_json(entry, ok);
            if (!ok) {
                return {false, "archive contains an object with an unrecognized objectType", manifest};
            }
            objects_to_restore.push_back(std::move(object));
        }
    }

    std::vector<oep::repository::Relationship> relationships_to_restore;
    if (const json::Value* relationships_value = parsed.value.find("relationships");
        relationships_value != nullptr && relationships_value->is_array()) {
        for (const json::Value& entry : relationships_value->as_array()) {
            bool ok = false;
            oep::repository::Relationship relationship = archive_codec::relationship_from_json(entry, ok);
            if (!ok) {
                return {false, "archive contains a relationship with an unrecognized relationshipType", manifest};
            }
            relationships_to_restore.push_back(std::move(relationship));
        }
    }

    std::vector<oep::repository::AuditEvent> events_to_restore;
    if (const json::Value* events_value = parsed.value.find("auditEvents");
        events_value != nullptr && events_value->is_array()) {
        for (const json::Value& entry : events_value->as_array()) {
            bool ok = false;
            oep::repository::AuditEvent event = archive_codec::audit_event_from_json(entry, ok);
            if (!ok) {
                return {false, "archive contains an audit event with an unrecognized eventType", manifest};
            }
            events_to_restore.push_back(std::move(event));
        }
    }

    std::vector<oep::packages::PackageManifest> packages_to_restore;
    if (const json::Value* packages_value = parsed.value.find("packages");
        packages_value != nullptr && packages_value->is_array()) {
        for (const json::Value& entry : packages_value->as_array()) {
            bool ok = false;
            oep::packages::PackageManifest package_manifest = archive_codec::package_manifest_from_json(entry, ok);
            if (!ok) {
                return {false, "archive contains a package with an unrecognized packageType", manifest};
            }
            packages_to_restore.push_back(std::move(package_manifest));
        }
    }

    // Destination handling.
    std::error_code error_code;
    if (std::filesystem::exists(destination, error_code) && !std::filesystem::is_empty(destination, error_code)) {
        if (!overwrite) {
            return {false, "destination '" + destination.string() + "' already exists (use --overwrite)", manifest};
        }
        std::filesystem::remove_all(destination, error_code);
        if (error_code) {
            return {false, "could not clear existing destination '" + destination.string() + "': " +
                               error_code.message(),
                    manifest};
        }
    }
    std::filesystem::create_directories(destination, error_code);
    if (error_code) {
        return {false, "could not create destination '" + destination.string() + "': " + error_code.message(),
                manifest};
    }

    const oep::repository::SaveMetadataResult metadata_save =
        oep::repository::save_metadata(destination / "repository.json", metadata);
    if (!metadata_save.success) {
        return {false, "could not write repository metadata: " + metadata_save.error, manifest};
    }

    oep::repository::AuditStore audit(destination / "repository" / "audit");
    oep::repository::ObjectStore objects(destination / "repository" / "objects", audit);
    oep::repository::RelationshipStore relationships(destination / "repository" / "relationships", objects, audit);

    for (const oep::repository::EngineeringObject& object : objects_to_restore) {
        const oep::repository::LoadObjectResult result = objects.restore(object);
        if (!result.success) {
            return {false, "could not restore object '" + object.object_id + "': " + result.error, manifest};
        }
    }

    for (const oep::repository::Relationship& relationship : relationships_to_restore) {
        const oep::repository::LoadRelationshipResult result = relationships.restore(relationship);
        if (!result.success) {
            return {false, "could not restore relationship '" + relationship.relationship_id + "': " + result.error,
                    manifest};
        }
    }

    for (const oep::repository::AuditEvent& event : events_to_restore) {
        const oep::repository::RecordEventResult result = audit.restore(event);
        if (!result.success) {
            return {false, "could not restore audit event '" + event.event_id + "': " + result.error, manifest};
        }
    }

    for (const oep::packages::PackageManifest& package_manifest : packages_to_restore) {
        const std::filesystem::path package_dir = destination / "packages" / package_manifest.package_id;
        std::filesystem::create_directories(package_dir, error_code);
        if (error_code) {
            return {false, "could not create package directory '" + package_dir.string() + "': " +
                               error_code.message(),
                    manifest};
        }
        const std::string serialized_manifest = json::serialize(archive_codec::to_json(package_manifest));
        std::ofstream manifest_file(package_dir / "package.json", std::ios::binary | std::ios::trunc);
        if (!manifest_file) {
            return {false, "could not write package manifest to '" + package_dir.string() + "'", manifest};
        }
        manifest_file << serialized_manifest;
    }

    return {true, "", manifest};
}

} // namespace oep::archive
