#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

#include "oep/engine/intelligence_types.hpp"

namespace oep::engine {

// WP-EKE-007's Knowledge Session Manager: Create/Resume/Clone/Close/
// Export Summary over in-memory KnowledgeSessions -- pure bookkeeping,
// no persistence, no Foundation access (mirrors WP-EKE-004's
// RuleRegistry and WP-EKE-005's ValidationEngine session-map pattern).
// EngineeringIntelligencePlatform owns the one instance of this class
// and is the only thing that mutates session history/statistics
// (via the package-private append_* methods) as it dispatches
// workflows on a session's behalf.
class KnowledgeSessionManager {
public:
    std::string create_session();

    // "Resume": marks `session_id` as the most recently active session
    // (updates last_active_utc) and returns true. Fails for an unknown
    // or already-closed session_id.
    bool resume_session(const std::string& session_id);

    // "Clone": creates a new session with the same history/active-set
    // snapshot as `session_id` (statistics reset to zero for the new
    // session -- a clone starts a fresh measurement window, but
    // inherits the CONTENT of what was already investigated). Returns
    // the new session_id, or nullopt if `session_id` is unknown.
    std::optional<std::string> clone_session(const std::string& session_id);

    bool close_session(const std::string& session_id);

    std::optional<KnowledgeSession> get_session(const std::string& session_id) const;

    // Every session ever created (including closed ones), sorted by
    // session_id -- determinism.
    std::vector<std::string> list_sessions() const;

    // A short, human-readable text summary of `session_id` (history
    // counts, active object/package counts, statistics) -- "Export
    // Summary." Returns nullopt if `session_id` is unknown.
    std::optional<std::string> export_summary(const std::string& session_id) const;

    std::size_t active_session_count() const;
    std::size_t total_session_count() const { return sessions_.size(); }

    // Package-private mutation surface: only
    // EngineeringIntelligencePlatform calls these, as it dispatches a
    // workflow on `session_id`'s behalf. Silently no-ops if
    // `session_id` is unknown or closed (the platform itself is
    // responsible for checking session validity before dispatching;
    // these exist purely to keep KnowledgeSession's own fields
    // append-only and centrally maintained).
    void append_query(const std::string& session_id, const std::string& description);
    void append_validation(const std::string& session_id, const std::string& description);
    void append_analysis(const std::string& session_id, const std::string& description);
    void append_reasoning(const std::string& session_id, const std::string& description);
    void append_recommendation(const std::string& session_id, const std::string& description);
    void touch_active_object(const std::string& session_id, const std::string& object_id);
    void touch_active_package(const std::string& session_id, const std::string& package_id);
    void add_execution_time(const std::string& session_id, double execution_time_ms);

private:
    struct MutableSession {
        std::string created_utc;
        std::string last_active_utc;
        bool closed = false;
        std::vector<std::string> query_history;
        std::vector<std::string> validation_history;
        std::vector<std::string> analysis_history;
        std::vector<std::string> reasoning_history;
        std::vector<std::string> recommendations;
        std::vector<std::string> active_objects;
        std::vector<std::string> active_packages;
        SessionStatistics statistics;
    };
    std::map<std::string, MutableSession> sessions_;

    KnowledgeSession to_immutable(const std::string& session_id, const MutableSession& session) const;
};

} // namespace oep::engine
