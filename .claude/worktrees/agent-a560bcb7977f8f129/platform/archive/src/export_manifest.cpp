#include "oep/archive/export_manifest.hpp"

namespace oep::archive {

std::vector<std::string> validate_export_manifest(const ExportManifest& manifest) {
    std::vector<std::string> errors;

    if (manifest.export_version.empty()) {
        errors.push_back("exportVersion is required");
    }
    if (manifest.export_timestamp_utc.empty()) {
        errors.push_back("exportTimestampUtc is required");
    }
    if (manifest.repository_id.empty()) {
        errors.push_back("repositoryId is required");
    }
    if (manifest.repository_version.empty()) {
        errors.push_back("repositoryVersion is required");
    }
    if (manifest.object_count < 0) {
        errors.push_back("objectCount must not be negative");
    }
    if (manifest.relationship_count < 0) {
        errors.push_back("relationshipCount must not be negative");
    }
    if (manifest.package_count < 0) {
        errors.push_back("packageCount must not be negative");
    }

    return errors;
}

} // namespace oep::archive
