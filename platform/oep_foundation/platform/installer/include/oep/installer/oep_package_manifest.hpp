#pragma once

#include <string>
#include <vector>

namespace oep::installer {

// One entry of a manifest's `dependencies` array (PKG-002 §5, PKG-004 §7):
// a required-or-optional dependency on another package, by Package ID and
// a version constraint (PKG-004 §8). Deliberately package-ID dependencies
// only — PKG-004 §7's "Virtual Capability" dependencies (targeting a
// capability rather than a specific package) require a Capability
// primitive/registry that does not exist anywhere in this codebase
// (CLAUDE.md's Five Primitive Rule: "No additional primitive types shall
// be introduced without explicit architectural approval") and are
// therefore out of WP-REP-005's scope, not an oversight.
struct DependencyDeclaration {
    std::string package_id;
    std::string version_constraint; // e.g. ">=1.0.0", "^2.1", "1.0.0"; empty = any version
    bool optional = false;
};

// The Exchange marketplace's Package Manifest (PKG-002), read from
// `manifest/package.json` inside a `.oep` archive. Distinct from
// oep::packages::PackageManifest (OEP-SPEC-010's local, UUIDv4-identified
// extension-package concept, platform/packages) — these are two different
// manifest schemas for two different kinds of "package"; see OEP-ARCH-002
// §0 for why they must not be conflated. Only the fields WP-REP-001
// actually needs are modeled in detail; every other PKG-002 §5 required
// field is checked for presence (per §20 "contain every required field")
// without being deeply parsed, since nothing in this Work Package's scope
// (dependency resolution, licensing, signing) reads them yet.
struct OepPackageManifest {
    std::string schema_version;
    std::string package_id; // reverse-domain, e.g. "com.oep.demo.engineering-showcase"
    std::string version;    // semantic version
    std::string publisher_id;
    std::string publisher_name;
    std::string title;
    std::string summary;
    std::string description;
    std::string category;
    // engineeringDomains (PKG-002 §5) — captured starting WP-REP-002 for
    // the Repository Registry's "Manifest Metadata" field and package
    // search (WP-REP-002.md §8, "search by ... Engineering Domain").
    std::vector<std::string> engineering_domains;
    // dependencies (PKG-002 §5, WP-REP-005) — see DependencyDeclaration.
    std::vector<DependencyDeclaration> dependencies;
};

struct ParseManifestResult {
    bool success = false;
    std::vector<std::string> errors;
    OepPackageManifest manifest;
};

// Parses and validates `manifest_json` against PKG-002 §5's sixteen
// required top-level fields (schemaVersion, packageId, version, publisher,
// title, summary, description, category, engineeringDomains, license,
// dependencies, capabilities, repository, statistics, signatures, build)
// and §9's publisher.id/publisher.name. Mirrors
// `oep_exchange/packages/manifest/src/parse-manifest.ts`'s own
// required-field rule set exactly, so a manifest either implementation
// accepts, the other does too — cross-checked directly in this module's
// own tests against manifests `oep-package validate` (oep_exchange) also
// accepts. Returns an empty `errors` vector iff the manifest is valid.
ParseManifestResult parse_oep_package_manifest(const std::string& manifest_json);

} // namespace oep::installer
