#pragma once

#include <filesystem>
#include <string>

#include "oep/archive/export_manifest.hpp"
#include "oep/packages/package_manager.hpp"
#include "oep/repository/audit_store.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/object_store.hpp"
#include "oep/repository/relationship_store.hpp"

namespace oep::archive {

struct ExportResult {
    bool success = false;
    std::string error;
    ExportManifest manifest;
};

// Exports repository metadata, Engineering Objects, Relationships, and
// the Audit Log (and, if `packages` is non-null, every currently
// Loaded package's manifest) into a single deterministic JSON archive
// at `output_file`, per OEP-SPEC-017-REPOSITORY_EXPORT. Gathers data
// exclusively through the existing Foundation enumeration APIs
// (list_all/list_events/list_packages); never reads repository files
// directly. The write is atomic.
ExportResult export_repository(const oep::repository::RepositoryMetadata& metadata,
                                const oep::repository::ObjectStore& objects,
                                const oep::repository::RelationshipStore& relationships,
                                const oep::repository::AuditStore& audit,
                                const oep::packages::PackageManager* packages,
                                const std::filesystem::path& output_file);

} // namespace oep::archive
