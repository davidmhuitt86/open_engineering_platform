#include "oep/repository/relationship.hpp"

#include <unordered_map>

#include "oep/repository/uuid.hpp"

namespace oep::repository {

std::string to_string(RelationshipType type) {
    switch (type) {
        case RelationshipType::References: return "References";
        case RelationshipType::Contains: return "Contains";
        case RelationshipType::DependsOn: return "DependsOn";
        case RelationshipType::ConnectedTo: return "ConnectedTo";
        case RelationshipType::Documents: return "Documents";
        case RelationshipType::Implements: return "Implements";
    }
    return "References";
}

std::optional<RelationshipType> relationship_type_from_string(const std::string& value) {
    static const std::unordered_map<std::string, RelationshipType> kTypesByName = {
        {"References", RelationshipType::References},
        {"Contains", RelationshipType::Contains},
        {"DependsOn", RelationshipType::DependsOn},
        {"ConnectedTo", RelationshipType::ConnectedTo},
        {"Documents", RelationshipType::Documents},
        {"Implements", RelationshipType::Implements},
    };
    const auto it = kTypesByName.find(value);
    if (it == kTypesByName.end()) {
        return std::nullopt;
    }
    return it->second;
}

std::vector<std::string> validate_relationship(const Relationship& relationship) {
    std::vector<std::string> errors;

    if (relationship.relationship_id.empty()) {
        errors.push_back("relationshipId is required");
    } else if (!is_valid_uuid_v4(relationship.relationship_id)) {
        errors.push_back("relationshipId is not a valid UUIDv4");
    }

    if (relationship.source_object_id.empty()) {
        errors.push_back("sourceObjectId is required");
    } else if (!is_valid_uuid_v4(relationship.source_object_id)) {
        errors.push_back("sourceObjectId is not a valid UUIDv4");
    }

    if (relationship.target_object_id.empty()) {
        errors.push_back("targetObjectId is required");
    } else if (!is_valid_uuid_v4(relationship.target_object_id)) {
        errors.push_back("targetObjectId is not a valid UUIDv4");
    }

    if (!relationship.source_object_id.empty() && !relationship.target_object_id.empty() &&
        relationship.source_object_id == relationship.target_object_id) {
        errors.push_back("sourceObjectId and targetObjectId must differ");
    }

    if (relationship.created_utc.empty()) {
        errors.push_back("createdUtc is required");
    }

    return errors;
}

} // namespace oep::repository
