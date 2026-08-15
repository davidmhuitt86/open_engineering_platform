#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace oep::installer {

// One record of an installed .oep package in the Repository Registry
// (WP-REP-002.md §4) — "the authoritative inventory of installed
// engineering packages" within one Foundation Repository, per PKG-008's
// framing. Renamed and expanded from WP-REP-001's minimal
// InstalledPackageRecord: this is the same on-disk concept (still one
// JSON file per package under <repository>/packages/<packageId>/), now
// tracking every field WP-REP-002.md §4 lists.
struct RepositoryRegistryEntry {
    std::string package_id;
    std::string version;

    // Manifest Metadata (WP-REP-002.md §4) — captured from the archive's
    // PKG-002 manifest at install time. Never re-read from the archive
    // afterward; the archive itself may no longer exist on disk (see
    // installation_path below).
    std::string title;
    std::string summary;
    std::string category;
    std::string schema_version;
    std::vector<std::string> engineering_domains;

    // Publisher (WP-REP-002.md §4).
    std::string publisher_id;
    std::string publisher_name;

    std::string installed_utc;      // Installation Date
    std::string source;             // Install Source -- "local" for WP-REP-001/002, see OEP-ARCH-002 §3 item 8
    std::string installation_path;  // absolute path to the source .oep archive at install time

    // Package Hash (WP-REP-002.md §4): a SHA-256 hex digest of the
    // archive's bytes at install time. An integrity fingerprint only --
    // NOT a trust or signature mechanism (see sha256.hpp's own doc
    // comment, and PKG-005 / WP-REP-004 for real signature verification).
    std::string package_hash;

    // Runtime State (WP-REP-002.md §4). Always "Installed" while a
    // record exists: PKG-008 §6 defines many other lifecycle states
    // (Active, Inactive, Deprecated, Superseded, Pending Removal,
    // Removed, Corrupted, Repair Required, ...), but reaching most of
    // them still requires update/activation functionality, out of scope
    // through WP-REP-005. Uninstall (WP-REP-005) removes the record
    // outright rather than transitioning it to a "Removed" state -- the
    // field exists so a future Work Package implementing the remaining
    // transitions does not need a schema migration to add it.
    std::string runtime_state;

    // Trust Status (PKG-008 §12, WP-REP-004): the TrustState
    // (trust_state's to_string — "Trusted"/"Unsigned"/"UnknownPublisher"/
    // "ExpiredCertificate"/"RevokedCertificate") the package resolved to
    // at install time, plus the trusted certificate's fingerprint when
    // one was matched. Recorded once, at install; WP-REP-004 does not
    // implement re-verification on demand for already-installed packages
    // (PKG-005 §16's "Repository audits may revalidate ... at any time"
    // is deferred) — `oep package verify`'s existing hash/contribution
    // checks (WP-REP-002) are unrelated to trust and are unaffected.
    std::string trust_status;
    std::string trust_fingerprint;

    // Repository Contributions (WP-REP-002.md §4 "Object Count" /
    // "Relationship Count"): the Engineering Object / Relationship IDs
    // this package created. Counts are derived from these lists' sizes
    // rather than stored separately, so a count can never drift from the
    // list it describes.
    std::vector<std::string> object_ids;
    std::vector<std::string> relationship_ids;
};

struct RegistryResult {
    bool success = false;
    std::string error;
};

struct ListInstalledResult {
    bool success = false;
    std::string error;
    std::vector<RepositoryRegistryEntry> packages;
};

struct IsInstalledResult {
    bool success = false;
    std::string error;
    bool installed = false;
    RepositoryRegistryEntry record; // meaningful only when installed is true
};

// The kind of entity a Repository Registry entity ID resolved to, for
// find_owner()'s reverse "query package ownership" lookup
// (WP-REP-002.md §5).
enum class OwnedEntityKind {
    None,
    Object,
    Relationship,
};

struct FindOwnerResult {
    bool success = false;
    std::string error;
    OwnedEntityKind kind = OwnedEntityKind::None;
    RepositoryRegistryEntry owner; // meaningful only when kind != OwnedEntityKind::None
};

struct SearchPackagesResult {
    bool success = false;
    std::string error;
    std::vector<RepositoryRegistryEntry> packages;
};

// Persists installed-package records as one JSON file per package under
// `<repository>/packages/<packageId>/registry.json` — inside the same
// top-level `packages/` directory OEP-SPEC-002 §6 already reserves for
// "locally installed OEP packages", but never named `package.json`, so
// `oep::packages::PackageManager::discover_packages` (which only looks for
// that exact filename) never sees or misinterprets it. See OEP-ARCH-002
// §4.1 for why this stays a class distinct from
// `oep::packages::PackageManager` rather than overloading it.
//
// One record per packageId, ever: `record_install` fails if a package with
// the same `package_id` is already recorded, regardless of version --
// update/reinstall remains out of scope through WP-REP-002 (see
// package_installer.hpp), and this is the honest reflection of that limit
// rather than silent overwrite or partial update support.
class RepositoryRegistry {
public:
    explicit RepositoryRegistry(std::filesystem::path packages_root);

    RegistryResult record_install(const RepositoryRegistryEntry& entry) const;

    // Removes `package_id`'s Repository Registry record (the on-disk
    // `packages/<packageId>/registry.json`, and its now-empty parent
    // directory when possible). Fails with an error if no record exists
    // for `package_id` -- mirroring record_install's own "exactly one
    // record per packageId" contract, uninstalling a package that was
    // never (or no longer) recorded is a caller error, not a silent
    // no-op. Does not touch the Engineering Objects/Relationships the
    // package contributed -- FoundationRuntime::uninstall_package is
    // responsible for deleting those through ObjectStore/
    // RelationshipStore before removing the registry record.
    RegistryResult remove_install(const std::string& package_id) const;

    // "Query package metadata" / "Locate installed package"
    // (WP-REP-002.md §5): does `package_id` have a Repository Registry
    // record, and if so, what is it. Always succeeds for a well-formed
    // registry regardless of whether the package is installed --
    // "not installed" is a normal result, not an error.
    IsInstalledResult is_installed(const std::string& package_id) const;

    // "Enumerate installed packages" (WP-REP-002.md §5).
    ListInstalledResult list_installed() const;

    // "Query package ownership" (WP-REP-002.md §5): does any installed
    // package's contribution list contain `entity_id` (as either an
    // Engineering Object ID or a Relationship ID). Scans every recorded
    // package -- there is no separate reverse index, since the Repository
    // Registry is not expected to hold enough packages for a linear scan
    // to matter.
    FindOwnerResult find_owner(const std::string& entity_id) const;

    // Repository Index (WP-REP-002.md §8): case-insensitive substring
    // match against package_id, title, summary, category,
    // publisher_id/name, version, and engineering_domains. Matching
    // against a package's *installed objects* (also listed in §8) is
    // deliberately not implemented here -- object names are not
    // duplicated into the registry (CLAUDE.md: "Never duplicate
    // Engineering Object data"); FoundationRuntime::search_packages
    // layers that cross-reference on top of this function using the
    // already-open repository's own ObjectStore.
    SearchPackagesResult search_packages(const std::string& query) const;

private:
    std::filesystem::path packages_root_;
    std::filesystem::path path_for(const std::string& package_id) const;
};

} // namespace oep::installer
