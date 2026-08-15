#include "oep/packages/package_manifest.hpp"

#include <regex>
#include <unordered_map>

#include "oep/repository/uuid.hpp"

namespace oep::packages {

namespace {
const std::regex kSemanticVersionPattern("^[0-9]+\\.[0-9]+\\.[0-9]+$");
}

std::string to_string(PackageType type) {
    switch (type) {
        case PackageType::EngineeringContent: return "EngineeringContent";
        case PackageType::Studio: return "Studio";
        case PackageType::SDK: return "SDK";
        case PackageType::Extension: return "Extension";
        case PackageType::Theme: return "Theme";
    }
    return "Extension";
}

std::optional<PackageType> package_type_from_string(const std::string& value) {
    static const std::unordered_map<std::string, PackageType> kTypesByName = {
        {"EngineeringContent", PackageType::EngineeringContent},
        {"Studio", PackageType::Studio},
        {"SDK", PackageType::SDK},
        {"Extension", PackageType::Extension},
        {"Theme", PackageType::Theme},
    };
    const auto it = kTypesByName.find(value);
    if (it == kTypesByName.end()) {
        return std::nullopt;
    }
    return it->second;
}

std::vector<std::string> validate_package_manifest(const PackageManifest& manifest) {
    std::vector<std::string> errors;

    if (manifest.package_id.empty()) {
        errors.push_back("packageId is required");
    } else if (!oep::repository::is_valid_uuid_v4(manifest.package_id)) {
        errors.push_back("packageId is not a valid UUIDv4");
    }

    if (manifest.package_name.empty()) {
        errors.push_back("packageName is required");
    }

    if (!std::regex_match(manifest.package_version, kSemanticVersionPattern)) {
        errors.push_back("packageVersion must be in the form major.minor.patch");
    }

    if (!std::regex_match(manifest.foundation_version, kSemanticVersionPattern)) {
        errors.push_back("foundationVersion must be in the form major.minor.patch");
    }

    if (manifest.created_utc.empty()) {
        errors.push_back("createdUtc is required");
    }

    return errors;
}

} // namespace oep::packages
