#pragma once

#include <string>

namespace oep::installer {

// A minimal semantic-version comparator and constraint evaluator for
// PKG-004 §8 ("Version Constraints"). Deliberately simplified relative
// to full Semantic Versioning 2.0.0: only the `major.minor.patch`
// numeric core is compared (a missing component defaults to 0; e.g.
// "1.2" means "1.2.0"); pre-release/build-metadata suffixes
// (`-beta.1`, `+build.5`) are accepted syntactically but not compared,
// since every version this Work Package's tests and demo content use
// is a plain numeric triple, and a full SemVer 2.0.0 precedence
// algorithm is materially more code for no exercised benefit. This
// limitation is deliberate scope, not an oversight — documented here so
// a future work package extending it does not have to rediscover it.
struct SemanticVersion {
    int major = 0;
    int minor = 0;
    int patch = 0;
};

struct ParseVersionResult {
    bool success = false;
    std::string error;
    SemanticVersion version;
};

// Parses "major[.minor[.patch]]", optionally followed by a
// `-prerelease` and/or `+build` suffix (accepted but ignored). Fails
// for anything that doesn't start with a numeric major component.
ParseVersionResult parse_semantic_version(const std::string& text);

// -1, 0, or 1 per usual comparator convention, comparing only
// major/minor/patch (see SemanticVersion's own doc comment).
int compare_semantic_versions(const SemanticVersion& a, const SemanticVersion& b);

struct ConstraintCheckResult {
    // false only when `constraint` itself is malformed and could not be
    // evaluated at all -- never used to mean "not satisfied" (that is
    // `satisfied == false` with `success == true`).
    bool success = false;
    std::string error;
    bool satisfied = false;
};

// Evaluates `version` (a plain "major.minor.patch" string, e.g. an
// installed package's recorded version) against `constraint` (PKG-004
// §8: `=`, `!=`, `>`, `>=`, `<`, `<=`, `~` compatible, `^` caret, or a
// space-separated list of such atoms, ANDed together — e.g.
// ">=1.0.0 <2.0.0`). An empty `constraint` is always satisfied (PKG-002
// dependency entries may omit `version` to mean "any version").
// `~X.Y.Z` allows patch-level changes only (`>=X.Y.Z <X.(Y+1).0`).
// `^X.Y.Z` allows changes that do not modify the left-most nonzero
// component (standard npm-style caret semantics, including the `0.x`
// special cases).
ConstraintCheckResult version_satisfies(const std::string& version, const std::string& constraint);

} // namespace oep::installer
