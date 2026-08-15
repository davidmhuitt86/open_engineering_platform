#include "oep/runtime/repository_events.hpp"

#include "oep/repository/timestamp.hpp"

namespace oep::runtime {

std::string to_string(EventType type) {
    switch (type) {
        case EventType::ObjectCreated: return "ObjectCreated";
        case EventType::ObjectUpdated: return "ObjectUpdated";
        case EventType::ObjectDeleted: return "ObjectDeleted";
        case EventType::RelationshipCreated: return "RelationshipCreated";
        case EventType::RelationshipUpdated: return "RelationshipUpdated";
        case EventType::RelationshipDeleted: return "RelationshipDeleted";
        case EventType::TransactionBegun: return "TransactionBegun";
        case EventType::TransactionCommitted: return "TransactionCommitted";
        case EventType::TransactionRolledBack: return "TransactionRolledBack";
        case EventType::PackageInstalled: return "PackageInstalled";
        case EventType::PackageInstallFailed: return "PackageInstallFailed";
        case EventType::DependencyResolutionCompleted: return "DependencyResolutionCompleted";
        case EventType::PackageUninstalled: return "PackageUninstalled";
        case EventType::PackageUpdated: return "PackageUpdated";
        case EventType::RepositoryMerged: return "RepositoryMerged";
    }
    return "Unknown";
}

EventBus::EventBus(std::size_t max_retained) : max_retained_(max_retained) {}

void EventBus::publish(EventType type, const std::string& subject_id, const std::string& detail) {
    ++published_count_;
    log_.emplace_back(type, subject_id, detail, oep::repository::current_timestamp_utc(), published_count_);
    if (max_retained_ > 0 && log_.size() > max_retained_) {
        log_.erase(log_.begin(), log_.begin() + static_cast<std::ptrdiff_t>(log_.size() - max_retained_));
    }
}

std::vector<RepositoryEvent> EventBus::recent_events(std::size_t limit) const {
    if (limit == 0 || limit >= log_.size()) {
        return log_;
    }
    return std::vector<RepositoryEvent>(log_.end() - static_cast<std::ptrdiff_t>(limit), log_.end());
}

std::size_t EventBus::published_count() const {
    return published_count_;
}

} // namespace oep::runtime
