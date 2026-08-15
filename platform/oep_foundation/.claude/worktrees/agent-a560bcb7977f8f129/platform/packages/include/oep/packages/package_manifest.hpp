#pragma once

#include <optional>
#include <string>
#include <vector>

namespace oep::packages {

// Initial package classification, per OEP-SPEC-010-PACKAGE_SYSTEM.
enum class PackageType {
    EngineeringContent,
    Studio,
    SDK,
    Extension,
    Theme,
};

std::string to_string(PackageType type);
std::optional<PackageType> package_type_from_string(const std::string& value);

// The authoritative description of a package, read from its
// package.json manifest. Foundation never infers package metadata
// from directory names.
struct PackageManifest {
    std::string package_id;
    std::string package_name;
    std::string package_version;
    PackageType package_type = PackageType::Extension;
    std::string author;
    std::string organization;
    std::string description;
    std::vector<std::string> tags;
    std::string foundation_version;
    std::string created_utc;
};

// Validates required fields, UUIDv4 packageId, and semantic-version
// format for packageVersion and foundationVersion. Does not check
// Foundation version *compatibility* — that depends on the Foundation
// version actually running, which is PackageManager's concern.
std::vector<std::string> validate_package_manifest(const PackageManifest& manifest);

} // namespace oep::packages
