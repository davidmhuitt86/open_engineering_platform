#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "oep/packages/package_manifest.hpp"

namespace oep::packages {

enum class PackageState {
    Loaded,
    Invalid,
    Disabled,
};

std::string to_string(PackageState state);

// A package directory discovered under packages/, together with its
// resolved state. `manifest` is populated whenever a package.json was
// found and parsed, even if the package is ultimately Invalid (e.g.
// due to a Foundation-version mismatch) or Disabled; `message`
// explains why a package is Invalid, and is empty otherwise.
struct DiscoveredPackage {
    std::string directory_name;
    PackageState state = PackageState::Invalid;
    PackageManifest manifest;
    std::string message;
};

struct DiscoverPackagesResult {
    bool success = false;
    std::string error;
    // Names of packages/ subdirectories that contain a package.json,
    // in deterministic (sorted) order. Discovery does not parse or
    // validate manifests; see load_package/list_packages for that.
    std::vector<std::string> package_directory_names;
};

struct LoadPackageResult {
    bool success = false;
    std::string error;
    DiscoveredPackage package;
};

struct ListPackagesResult {
    bool success = false;
    std::string error;
    std::vector<DiscoveredPackage> packages;
};

// Discovers, loads, and validates packages under a repository's
// packages/ directory, per OEP-SPEC-010-PACKAGE_SYSTEM. Foundation
// never infers package metadata from directory names — every package
// must supply a package.json manifest. Packages extend Foundation;
// PackageManager never modifies a package's contents or Foundation's.
class PackageManager {
public:
    // `foundation_version` is the Foundation version currently running,
    // used to check each package's declared compatibility. It is
    // supplied by the caller rather than hardcoded, since Foundation has
    // no single canonical "current version" constant today.
    PackageManager(std::filesystem::path packages_root, std::string foundation_version);

    // Finds every immediate subdirectory of packages_root that contains
    // a package.json. Deterministic; does not parse or validate.
    DiscoverPackagesResult discover_packages() const;

    // Loads and validates a single package by its packages/ subdirectory
    // name. Succeeds (success = true) even when the package itself is
    // Invalid or Disabled — those are reported via DiscoveredPackage,
    // not treated as an operation failure. success = false only for
    // operational problems, e.g. the directory does not exist.
    LoadPackageResult load_package(const std::string& package_directory_name) const;

    // Discovers every package directory and loads each one. An
    // individual invalid package never prevents others from loading.
    // Additionally detects packageId collisions across the discovered
    // set: the first package to claim an ID is Loaded (if otherwise
    // valid); any later package reusing that ID is reported Invalid.
    ListPackagesResult list_packages() const;

private:
    std::filesystem::path packages_root_;
    std::string foundation_version_;
};

} // namespace oep::packages
