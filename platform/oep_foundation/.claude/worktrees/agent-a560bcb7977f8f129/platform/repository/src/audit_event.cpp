#include "oep/repository/audit_event.hpp"

#include <unordered_map>

#include "oep/repository/uuid.hpp"

namespace oep::repository {

std::string to_string(AuditEventType type) {
    switch (type) {
        case AuditEventType::RepositoryCreated: return "RepositoryCreated";
        case AuditEventType::ObjectCreated: return "ObjectCreated";
        case AuditEventType::ObjectUpdated: return "ObjectUpdated";
        case AuditEventType::ObjectDeleted: return "ObjectDeleted";
        case AuditEventType::RelationshipCreated: return "RelationshipCreated";
        case AuditEventType::RelationshipUpdated: return "RelationshipUpdated";
        case AuditEventType::RelationshipDeleted: return "RelationshipDeleted";
    }
    return "ObjectCreated";
}

std::optional<AuditEventType> audit_event_type_from_string(const std::string& value) {
    static const std::unordered_map<std::string, AuditEventType> kTypesByName = {
        {"RepositoryCreated", AuditEventType::RepositoryCreated},
        {"ObjectCreated", AuditEventType::ObjectCreated},
        {"ObjectUpdated", AuditEventType::ObjectUpdated},
        {"ObjectDeleted", AuditEventType::ObjectDeleted},
        {"RelationshipCreated", AuditEventType::RelationshipCreated},
        {"RelationshipUpdated", AuditEventType::RelationshipUpdated},
        {"RelationshipDeleted", AuditEventType::RelationshipDeleted},
    };
    const auto it = kTypesByName.find(value);
    if (it == kTypesByName.end()) {
        return std::nullopt;
    }
    return it->second;
}

std::vector<std::string> validate_audit_event(const AuditEvent& event) {
    std::vector<std::string> errors;

    if (event.event_id.empty()) {
        errors.push_back("eventId is required");
    } else if (!is_valid_uuid_v4(event.event_id)) {
        errors.push_back("eventId is not a valid UUIDv4");
    }

    if (event.timestamp_utc.empty()) {
        errors.push_back("timestampUtc is required");
    }

    if (!event.object_id.empty() && !is_valid_uuid_v4(event.object_id)) {
        errors.push_back("objectId is not a valid UUIDv4");
    }

    return errors;
}

} // namespace oep::repository
