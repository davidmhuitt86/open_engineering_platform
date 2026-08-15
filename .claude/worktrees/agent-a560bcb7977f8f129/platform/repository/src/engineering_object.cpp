#include "oep/repository/engineering_object.hpp"

#include <regex>
#include <unordered_map>

#include "oep/repository/uuid.hpp"

namespace oep::repository {

namespace {
const std::regex kSemanticVersionPattern("^[0-9]+\\.[0-9]+\\.[0-9]+$");
}

std::string to_string(ObjectType type) {
    switch (type) {
        case ObjectType::Document: return "Document";
        case ObjectType::Diagram: return "Diagram";
        case ObjectType::Component: return "Component";
        case ObjectType::Procedure: return "Procedure";
        case ObjectType::Project: return "Project";
        case ObjectType::Image: return "Image";
    }
    return "Document";
}

std::optional<ObjectType> object_type_from_string(const std::string& value) {
    static const std::unordered_map<std::string, ObjectType> kTypesByName = {
        {"Document", ObjectType::Document},
        {"Diagram", ObjectType::Diagram},
        {"Component", ObjectType::Component},
        {"Procedure", ObjectType::Procedure},
        {"Project", ObjectType::Project},
        {"Image", ObjectType::Image},
    };
    const auto it = kTypesByName.find(value);
    if (it == kTypesByName.end()) {
        return std::nullopt;
    }
    return it->second;
}

std::vector<std::string> validate_object(const EngineeringObject& object) {
    std::vector<std::string> errors;

    if (object.object_id.empty()) {
        errors.push_back("objectId is required");
    } else if (!is_valid_uuid_v4(object.object_id)) {
        errors.push_back("objectId is not a valid UUIDv4");
    }

    if (object.name.empty()) {
        errors.push_back("name is required");
    }

    if (object.created_utc.empty()) {
        errors.push_back("createdUtc is required");
    }

    if (object.last_modified_utc.empty()) {
        errors.push_back("lastModifiedUtc is required");
    }

    if (!std::regex_match(object.version, kSemanticVersionPattern)) {
        errors.push_back("version must be in the form major.minor.patch");
    }

    return errors;
}

} // namespace oep::repository
