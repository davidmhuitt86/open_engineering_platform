#pragma once

#include <unordered_map>
#include <unordered_set>

#include "oep/acquisition/registry/official_source_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IOfficialSourceRepository` so Service-layer tests exercise
/// validation and orchestration without a live PostgreSQL instance.
class FakeOfficialSourceRepository : public registry::IOfficialSourceRepository {
 public:
  registry::OfficialSource create(const registry::OfficialSource& source) override {
    registry::OfficialSource stored = source;
    stored.id = "fake-id-" + std::to_string(++next_id_);
    stored.created_at = "2026-01-01T00:00:00Z";
    stored.updated_at = stored.created_at;
    rows_[stored.id] = stored;
    return stored;
  }

  std::optional<registry::OfficialSource> find_by_id(const std::string& id) override {
    if (deleted_.contains(id)) {
      return std::nullopt;
    }
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    return it->second;
  }

  std::vector<registry::OfficialSource> list(const registry::SourceFilter& filter) override {
    std::vector<registry::OfficialSource> result;
    for (const auto& [id, source] : rows_) {
      if (deleted_.contains(id)) {
        continue;
      }
      if (filter.status.has_value() && source.status != *filter.status) {
        continue;
      }
      if (filter.trust_level.has_value() && source.trust_level != *filter.trust_level) {
        continue;
      }
      if (filter.category.has_value() && source.category != *filter.category) {
        continue;
      }
      if (filter.country.has_value() && source.country != *filter.country) {
        continue;
      }
      result.push_back(source);
    }
    return result;
  }

  std::optional<registry::OfficialSource> update(const std::string& id,
                                                   const registry::OfficialSource& source) override {
    if (deleted_.contains(id) || !rows_.contains(id)) {
      return std::nullopt;
    }
    registry::OfficialSource updated = source;
    updated.id = id;
    updated.created_at = rows_.at(id).created_at;
    updated.updated_at = "2026-01-02T00:00:00Z";
    rows_[id] = updated;
    return updated;
  }

  bool soft_delete(const std::string& id) override {
    if (deleted_.contains(id) || !rows_.contains(id)) {
      return false;
    }
    deleted_.insert(id);
    return true;
  }

 private:
  std::unordered_map<std::string, registry::OfficialSource> rows_;
  std::unordered_set<std::string> deleted_;
  int next_id_ = 0;
};

}  // namespace oep::acquisition::test_support
