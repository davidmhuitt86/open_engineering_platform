#pragma once

#include <optional>
#include <string>
#include <vector>

namespace oep::repository {

// Initial audit event classification, per OEP-SPEC-008-REPOSITORY_AUDIT_LOG.
enum class AuditEventType {
    RepositoryCreated,
    ObjectCreated,
    ObjectUpdated,
    ObjectDeleted,
    RelationshipCreated,
    RelationshipUpdated,
    RelationshipDeleted,
};

std::string to_string(AuditEventType type);
std::optional<AuditEventType> audit_event_type_from_string(const std::string& value);

// A historical record of a significant engineering operation. The
// Audit Log is a historical record, not the source of truth: an
// AuditEvent never modifies the Engineering Object or Relationship it
// describes.
struct AuditEvent {
    std::string event_id;
    std::string timestamp_utc;
    AuditEventType event_type = AuditEventType::ObjectCreated;
    std::string object_id; // may be empty for repository-level events
    std::string user;
    std::string description;
};

// Validates required fields (eventId, timestampUtc), UUIDv4 format for
// eventId, and UUIDv4 format for objectId when it is not empty.
std::vector<std::string> validate_audit_event(const AuditEvent& event);

} // namespace oep::repository
