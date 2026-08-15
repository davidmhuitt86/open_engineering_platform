#pragma once

#include <cstddef>
#include <string>
#include <vector>

namespace oep::runtime {

// Repository Events infrastructure (WP-REP-006). This is deliberately
// infrastructure ONLY: RepositoryEvent/EventBus exist so RuntimeService
// can record what it sequenced, and so a future work package can add
// subscribers. No subscription mechanism exists yet (per WP-REP-006's
// "No event subscribers yet" constraint) — EventBus only supports
// publishing and reading back the in-memory event log. Nothing in this
// repository currently reacts to a published event.

enum class EventType {
    ObjectCreated,
    ObjectUpdated,
    ObjectDeleted,
    RelationshipCreated,
    RelationshipUpdated,
    RelationshipDeleted,
    TransactionBegun,
    TransactionCommitted,
    TransactionRolledBack,
    PackageInstalled,
    PackageInstallFailed,
    DependencyResolutionCompleted,
    PackageUninstalled,
    PackageUpdated,
    RepositoryMerged,
};

std::string to_string(EventType type);

// Immutable: every field is set at construction, exposed only through
// const accessors, and never modified afterward — there are
// deliberately no setters. `subject_id` is whatever the event is about
// (object id, relationship id, transaction id, package id) — empty
// when not applicable. `sequence` is the event's 1-based position in
// publication order, assigned by EventBus::publish.
//
// Fields are private (rather than public `const` members, as used by
// the Request/Response types in runtime_service.hpp) specifically so
// RepositoryEvent stays storable in std::vector, which requires its
// element type to be move-assignable; a class with public `const`
// members cannot be. Immutability is enforced identically either way —
// through the absence of any mutating member — this is purely a
// storage-compatibility detail.
class RepositoryEvent {
public:
    RepositoryEvent(EventType event_type, std::string subject_id, std::string detail, std::string occurred_at_utc,
                     std::size_t event_sequence)
        : type_(event_type),
          subject_id_(std::move(subject_id)),
          detail_(std::move(detail)),
          occurred_at_utc_(std::move(occurred_at_utc)),
          sequence_(event_sequence) {}

    EventType type() const { return type_; }
    const std::string& subject_id() const { return subject_id_; }
    const std::string& detail() const { return detail_; }
    const std::string& occurred_at_utc() const { return occurred_at_utc_; }
    std::size_t sequence() const { return sequence_; }

private:
    EventType type_;
    std::string subject_id_;
    std::string detail_;
    std::string occurred_at_utc_;
    std::size_t sequence_;
};

// A single-process, in-memory publication log. Thread-unsafe by design
// (FoundationRuntime and RuntimeService are not thread-safe today, per
// the existing codebase's own conventions — see FoundationRuntime's
// class doc). Bounded to `max_retained` most recent events so long-lived
// processes don't grow the log unboundedly; older events are dropped
// silently, since nothing yet depends on the full history (WP-REP-006
// has no subscribers, and the Transaction Journal remains the durable
// audit trail).
class EventBus {
public:
    explicit EventBus(std::size_t max_retained = 1000);

    // Appends an event to the log, assigning it the next sequence
    // number. Never fails.
    void publish(EventType type, const std::string& subject_id, const std::string& detail);

    // The most recently published events, oldest first, capped at
    // `limit` (0 means "no limit", subject to max_retained).
    std::vector<RepositoryEvent> recent_events(std::size_t limit = 0) const;

    std::size_t published_count() const;

private:
    std::size_t max_retained_;
    std::size_t published_count_ = 0;
    std::vector<RepositoryEvent> log_;
};

} // namespace oep::runtime
