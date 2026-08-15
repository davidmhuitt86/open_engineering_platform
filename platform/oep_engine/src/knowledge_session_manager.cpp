#include "oep/engine/knowledge_session_manager.hpp"

#include "oep/repository/timestamp.hpp"
#include "oep/repository/uuid.hpp"

#include <algorithm>
#include <sstream>

namespace oep::engine {

std::string KnowledgeSessionManager::create_session() {
    const std::string session_id = oep::repository::generate_uuid_v4();
    MutableSession session;
    session.created_utc = oep::repository::current_timestamp_utc();
    session.last_active_utc = session.created_utc;
    sessions_.erase(session_id);
    sessions_.emplace(session_id, std::move(session));
    return session_id;
}

bool KnowledgeSessionManager::resume_session(const std::string& session_id) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return false;
    found->second.last_active_utc = oep::repository::current_timestamp_utc();
    return true;
}

std::optional<std::string> KnowledgeSessionManager::clone_session(const std::string& session_id) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end()) return std::nullopt;

    const std::string new_session_id = oep::repository::generate_uuid_v4();
    MutableSession clone;
    clone.created_utc = oep::repository::current_timestamp_utc();
    clone.last_active_utc = clone.created_utc;
    clone.query_history = found->second.query_history;
    clone.validation_history = found->second.validation_history;
    clone.analysis_history = found->second.analysis_history;
    clone.reasoning_history = found->second.reasoning_history;
    clone.recommendations = found->second.recommendations;
    clone.active_objects = found->second.active_objects;
    clone.active_packages = found->second.active_packages;
    // statistics deliberately left zero-valued -- see header doc comment.
    sessions_.erase(new_session_id);
    sessions_.emplace(new_session_id, std::move(clone));
    return new_session_id;
}

bool KnowledgeSessionManager::close_session(const std::string& session_id) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return false;
    found->second.closed = true;
    return true;
}

KnowledgeSession KnowledgeSessionManager::to_immutable(const std::string& session_id, const MutableSession& session) const {
    return KnowledgeSession(session_id, session.created_utc, session.last_active_utc, session.closed,
                             session.query_history, session.validation_history, session.analysis_history,
                             session.reasoning_history, session.recommendations, session.active_objects,
                             session.active_packages, session.statistics);
}

std::optional<KnowledgeSession> KnowledgeSessionManager::get_session(const std::string& session_id) const {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end()) return std::nullopt;
    return to_immutable(session_id, found->second);
}

std::vector<std::string> KnowledgeSessionManager::list_sessions() const {
    std::vector<std::string> ids;
    ids.reserve(sessions_.size());
    for (const auto& [id, session] : sessions_) {
        ids.push_back(id);
    }
    return ids; // std::map iteration is already sorted by key
}

std::optional<std::string> KnowledgeSessionManager::export_summary(const std::string& session_id) const {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end()) return std::nullopt;
    const MutableSession& session = found->second;

    std::ostringstream out;
    out << "Session " << session_id << (session.closed ? " (closed)" : " (active)") << "\n";
    out << "  created: " << session.created_utc << "\n";
    out << "  last active: " << session.last_active_utc << "\n";
    out << "  queries executed: " << session.query_history.size() << "\n";
    out << "  validations run: " << session.validation_history.size() << "\n";
    out << "  analyses run: " << session.analysis_history.size() << "\n";
    out << "  reasoning runs: " << session.reasoning_history.size() << "\n";
    out << "  recommendations: " << session.recommendations.size() << "\n";
    out << "  active objects: " << session.active_objects.size() << "\n";
    out << "  active packages: " << session.active_packages.size() << "\n";
    out << "  total execution time: " << session.statistics.total_execution_time_ms << " ms\n";
    return out.str();
}

std::size_t KnowledgeSessionManager::active_session_count() const {
    std::size_t count = 0;
    for (const auto& [id, session] : sessions_) {
        if (!session.closed) ++count;
    }
    return count;
}

namespace {
void append_unique(std::vector<std::string>& target, const std::string& value) {
    if (std::find(target.begin(), target.end(), value) == target.end()) target.push_back(value);
}
} // namespace

void KnowledgeSessionManager::append_query(const std::string& session_id, const std::string& description) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    found->second.query_history.push_back(description);
    ++found->second.statistics.query_count;
}

void KnowledgeSessionManager::append_validation(const std::string& session_id, const std::string& description) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    found->second.validation_history.push_back(description);
    ++found->second.statistics.validation_count;
}

void KnowledgeSessionManager::append_analysis(const std::string& session_id, const std::string& description) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    found->second.analysis_history.push_back(description);
    ++found->second.statistics.analysis_count;
}

void KnowledgeSessionManager::append_reasoning(const std::string& session_id, const std::string& description) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    found->second.reasoning_history.push_back(description);
    ++found->second.statistics.reasoning_count;
}

void KnowledgeSessionManager::append_recommendation(const std::string& session_id, const std::string& description) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    found->second.recommendations.push_back(description);
}

void KnowledgeSessionManager::touch_active_object(const std::string& session_id, const std::string& object_id) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    append_unique(found->second.active_objects, object_id);
}

void KnowledgeSessionManager::touch_active_package(const std::string& session_id, const std::string& package_id) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    append_unique(found->second.active_packages, package_id);
}

void KnowledgeSessionManager::add_execution_time(const std::string& session_id, double execution_time_ms) {
    const auto found = sessions_.find(session_id);
    if (found == sessions_.end() || found->second.closed) return;
    found->second.statistics.total_execution_time_ms += execution_time_ms;
}

} // namespace oep::engine
