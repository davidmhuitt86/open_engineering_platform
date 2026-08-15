#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "oep/repository/audit_event.hpp"

namespace oep::repository {

struct AuditResult {
    bool success = false;
    std::string error;
};

struct RecordEventResult {
    bool success = false;
    std::string error;
    AuditEvent event;
};

struct ListAuditEventsResult {
    bool success = false;
    std::string error;
    std::vector<AuditEvent> events;
};

// Stores Audit Events as individual JSON files within a directory, per
// OEP-SPEC-008-REPOSITORY_AUDIT_LOG. All writes are atomic; an invalid
// event is never recorded.
class AuditStore {
public:
    explicit AuditStore(std::filesystem::path root);

    // Assigns a new event_id and timestamp_utc if not already set, then
    // validates and persists the event.
    RecordEventResult record_event(AuditEvent event) const;

    // Every recorded event, ordered by timestamp then eventId for determinism.
    ListAuditEventsResult list_events() const;

    ListAuditEventsResult list_events_for_object(const std::string& object_id) const;

    // Deletes every recorded audit event. Does not affect Engineering
    // Objects or Relationships.
    AuditResult clear() const;

    // Writes `event` exactly as given — no field is regenerated — for
    // reconstructing a repository's audit log from an export archive
    // (OEP-SPEC-018-REPOSITORY_IMPORT), not for ordinary event
    // recording. Fails if an event with the same ID already exists.
    RecordEventResult restore(AuditEvent event) const;

private:
    std::filesystem::path root_;
    std::filesystem::path path_for(const std::string& event_id) const;
};

} // namespace oep::repository
