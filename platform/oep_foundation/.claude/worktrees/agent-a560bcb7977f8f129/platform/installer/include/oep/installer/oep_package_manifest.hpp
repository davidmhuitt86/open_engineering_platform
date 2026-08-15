#pragma once

#include <string>
#include <vector>

namespace oep::installer {

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
