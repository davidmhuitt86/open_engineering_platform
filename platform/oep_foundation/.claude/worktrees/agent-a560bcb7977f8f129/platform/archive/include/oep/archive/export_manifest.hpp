#pragma once

#include <string>
#include <vector>

namespace oep::archive {

// The export archive format version this build produces and accepts.
// Import rejects any archive whose exportManifest.exportVersion does
// not exactly match this value.
constexpr const char* kSupportedExportVersion = "1.0";

// Describes an export archive, per OEP-SPEC-017-REPOSITORY_EXPORT.
struct ExportManifest {
    std::string export_version = kSupportedExportVersion;
    std::string export_timestamp_utc;
    std::string repository_id;
    std::string repository_version;
    int object_count = 0;
    int relationship_count = 0;
    int package_count = 0;
};

// Validates required fields. Does not check exportVersion
// compatibility — that is Import's concern (a manifest can be
// well-formed but still declare an unsupported version).
std::vector<std::string> validate_export_manifest(const ExportManifest& manifest);

} // namespace oep::archive
