#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "oep/installer/oep_package_manifest.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/relationship.hpp"

namespace oep::installer {

// The Repository Fragment (PKG-001 §7) extracted from a validated .oep
// archive: every Engineering Object and Relationship it contains, ready to
// be created via ObjectStore::create/RelationshipStore::create.
//
// This module only parses and validates — it never touches a live
// repository (mirrors platform/exchange's repository_exporter: "gathers
// data... never reading repository files directly", applied to the
// install direction instead). FoundationRuntime::install_package is the
// only caller that mutates anything, per OEP-SPEC-011 §6 "subsystems
// shall not locate each other directly."
//
// Deliberately excluded from this module (WP-REP-001 scope; see
// OEP-ARCH-002 §5): dependency resolution (PKG-004), cross-package
// identity/ownership merge logic (PKG-006), signature verification
// (PKG-005), and any transactional wrapping (PKG-003) — the caller
// (FoundationRuntime) is responsible for atomicity, if and when it
// chooses to add it; this Work Package deliberately does not.
struct ExtractedPackage {
    OepPackageManifest manifest;
    std::vector<oep::repository::EngineeringObject> objects;
    std::vector<oep::repository::Relationship> relationships;
};

struct ExtractPackageResult {
    bool success = false;
    std::string error;
    ExtractedPackage package;
};

// Opens `archive_path` (PKG-001 §14 ZIP container; see ZipReader's own
// documented Stored-only limitation), reads and validates
// `manifest/package.json` (PKG-002), then reads every
// `fragment/objects/*.json` and `fragment/relationships/*.json` entry
// (PKG-001 §7's Repository Fragment, renamed from `repository/` in
// WP-REP-002 — see OEP-ARCH-002 §0.2(b)) into Foundation's own
// EngineeringObject/Relationship shape — the exact JSON convention
// ObjectStore/RelationshipStore already read and write on disk (camelCase
// keys), so a Repository Fragment file is valid input under precisely the
// same rule an already-open repository's own object file would be. An
// archive still using the legacy `repository/` directory name (built
// before the rename) is also accepted, for backward compatibility — see
// this function's implementation.
//
// Performs structural/presence validation only (well-formed JSON, a
// recognized objectType/relationshipType, a non-empty name/source/target)
// — it deliberately does NOT enforce UUIDv4 format on object_id/
// relationship_id (ObjectStore::create/RelationshipStore::create already
// do, via validate_object/validate_relationship, once an ID is either
// preserved from the archive or auto-assigned; duplicating that check
// here would be the kind of premature "merge logic" this module excludes).
//
// Fails fast on the first structural problem — nothing is partially
// extracted; `package` is only populated on success.
ExtractPackageResult extract_package(const std::filesystem::path& archive_path);

} // namespace oep::installer
