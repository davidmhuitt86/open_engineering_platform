#pragma once

#include <filesystem>
#include <string>

#include "oep/archive/export_manifest.hpp"

namespace oep::archive {

struct ImportResult {
    bool success = false;
    std::string error;
    ExportManifest manifest;
};

// Reconstructs a repository at `destination` from a previously
// exported archive, per OEP-SPEC-018-REPOSITORY_IMPORT. Validates the
// export manifest (including that its exportVersion is one this
// build supports) and the repository metadata before restoring
// anything. Rejects an existing non-empty `destination` unless
// `overwrite` is set, in which case `destination`'s existing contents
// are removed first. Restoration uses ObjectStore/RelationshipStore/
// AuditStore's `restore` operations, so every identifier and
// timestamp is preserved exactly as exported — nothing is
// regenerated. A validation failure never partially writes `destination`.
ImportResult import_repository(const std::filesystem::path& archive_file, const std::filesystem::path& destination,
                                bool overwrite);

} // namespace oep::archive
