#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/installer/oep_package_manifest.hpp"

namespace oep::installer {

// The Dependency Resolution Engine (DRE), implementing the
// package-identity subset of PKG-004 (WP-REP-005). Per PKG-004 §2, the
// DRE is deterministic, stateless, and side-effect free: it is a pure
// function of its inputs, never touches a repository, and never
// downloads or fetches anything (PKG-004 §17: "The DRE shall never
// download packages directly"). It is also provider-agnostic (PKG-004
// §1/§2): nothing here knows or cares whether a package came from the
// Engineering Exchange, a local file, or any other source -- it reasons
// only about package IDs, versions, and the already-installed set it is
// given.
//
// Deliberately out of scope (see oep_package_manifest.hpp's
// DependencyDeclaration doc comment for why): Virtual Capability
// resolution (PKG-004 §9/§14), Studio compatibility (§13), platform/OS/
// architecture compatibility (§12, beyond what PackageManager's existing
// Foundation-version check already does), and license/specification
// conflict detection (§15's non-package-identity items). Also
// deliberately excluded, per this Work Package's own instructions:
// automatic downloads, update, uninstall, merge, federation, and remote
// repositories.

enum class DependencyState {
    Satisfied,   // installed, and its version satisfies the constraint
    Missing,     // required, but not installed
    Optional,    // not installed, but the dependency itself is optional
    Conflicting, // installed, but its version does not satisfy the constraint
    Cyclic,      // participates in a circular dependency chain
    Unknown,     // the dependency or an installed package's own declaration could not be evaluated (e.g. malformed constraint)
};

std::string to_string(DependencyState state);

struct DependencyResolutionEntry {
    std::string package_id;
    std::string version_constraint;
    bool optional = false;
    DependencyState state = DependencyState::Unknown;
    std::string installed_version; // empty iff not installed
    std::string detail;            // human-readable explanation (PKG-004 §2 "Explainable")
};

// The exact chain of package IDs forming a circular dependency (PKG-004
// §10), e.g. {"A", "B", "C", "A"} for "A requires B requires C requires
// A" -- the first and last entries are always the same package ID,
// making the cycle unambiguous without a separate "closes back to"
// field.
struct DependencyCycle {
    std::vector<std::string> chain;
};

enum class DependencyResolutionResult {
    Resolved,
    Failed,
};

std::string to_string(DependencyResolutionResult result);

// Immutable once produced (PKG-004 §16 "The report is immutable") --
// nothing in this module ever mutates a DependencyResolutionReport
// after resolve_dependencies returns it.
struct DependencyResolutionReport {
    DependencyResolutionResult result = DependencyResolutionResult::Failed;
    std::string candidate_package_id;
    std::string candidate_version;

    // One entry per candidate dependency, in declaration order
    // (deterministic -- PKG-004 §2).
    std::vector<DependencyResolutionEntry> entries;

    // Convenience views over `entries`, for callers that only need the
    // package IDs (e.g. CLI/API summaries) without re-deriving them.
    std::vector<std::string> missing_required;
    std::vector<std::string> conflicting;

    std::optional<DependencyCycle> cycle;

    // The deterministic installation order (PKG-004 §16 "Package Tree"):
    // a topological ordering of the candidate and every ALREADY-
    // INSTALLED package it transitively, required-ly depends on, tie-
    // broken by ascending package ID at every choice point so the same
    // inputs always produce the same order. The candidate is always
    // last. Left empty when `result == Failed` (a cyclic or otherwise
    // unresolved graph has no well-defined topological order). Packages
    // this candidate requires but that are NOT installed appear in
    // `missing_required`, never here -- the DRE never invents an order
    // for content it would have to download, since it never downloads
    // anything.
    std::vector<std::string> install_order;

    std::vector<std::string> warnings;
    std::vector<std::string> errors;
};

// The subset of an installed package's identity the DRE needs: its own
// declared dependencies, so transitive/circular checks can see past the
// immediate candidate. Deliberately not `RepositoryRegistryEntry`
// itself, so this module stays independently testable without a
// dependency on `repository_registry.hpp`'s JSON-persistence concerns;
// `FoundationRuntime` adapts registry entries into this shape.
struct InstalledPackageSnapshot {
    std::string package_id;
    std::string version;
    std::vector<DependencyDeclaration> dependencies;
};

// Resolves `candidate_dependencies` (a package about to be installed,
// identified by `candidate_package_id`/`candidate_version`, not itself
// present in `installed_packages`) against the given snapshot of
// already-installed packages. Never mutates its inputs; never touches a
// repository, the filesystem, or the network.
DependencyResolutionReport resolve_dependencies(const std::string& candidate_package_id,
                                                  const std::string& candidate_version,
                                                  const std::vector<DependencyDeclaration>& candidate_dependencies,
                                                  const std::vector<InstalledPackageSnapshot>& installed_packages);

} // namespace oep::installer
