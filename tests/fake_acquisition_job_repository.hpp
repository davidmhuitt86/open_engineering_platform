#pragma once

#include <unordered_map>
#include <unordered_set>

#include "oep/acquisition/acquisition/acquisition_job_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IAcquisitionJobRepository` so Service-layer tests exercise
/// validation and orchestration without a live PostgreSQL instance,
/// mirroring `FakeOfficialSourceRepository`. Does not enforce that
/// `source_id` references a real source -- WORK_PACKAGE-003's Repository
/// layer does that via a real database foreign key, which this fake has
/// no equivalent for; Service-layer tests are not concerned with it.
class FakeAcquisitionJobRepository : public acquisition::IAcquisitionJobRepository {
 public:
  acquisition::AcquisitionJob create(const acquisition::AcquisitionJob& job) override {
    acquisition::AcquisitionJob stored = job;
    stored.id = "fake-id-" + std::to_string(++next_id_);
    stored.created_at = "2026-01-01T00:00:00Z";
    stored.updated_at = stored.created_at;
    rows_[stored.id] = stored;
    return stored;
  }

  std::optional<acquisition::AcquisitionJob> find_by_id(const std::string& id) override {
    if (deleted_.contains(id)) {
      return std::nullopt;
    }
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    return it->second;
  }

  std::vector<acquisition::AcquisitionJob> list(const acquisition::JobFilter& filter) override {
    std::vector<acquisition::AcquisitionJob> result;
    for (const auto& [id, job] : rows_) {
      if (deleted_.contains(id)) {
        continue;
      }
      if (filter.status.has_value() && job.status != *filter.status) {
        continue;
      }
      if (filter.priority.has_value() && job.priority != *filter.priority) {
        continue;
      }
      if (filter.source_id.has_value() && job.source_id != *filter.source_id) {
        continue;
      }
      if (filter.requested_by.has_value() && job.requested_by != *filter.requested_by) {
        continue;
      }
      result.push_back(job);
    }
    return result;
  }

  std::optional<acquisition::AcquisitionJob> update(const std::string& id,
                                                       const acquisition::AcquisitionJob& job) override {
    if (deleted_.contains(id) || !rows_.contains(id)) {
      return std::nullopt;
    }
    acquisition::AcquisitionJob updated = job;
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
  std::unordered_map<std::string, acquisition::AcquisitionJob> rows_;
  std::unordered_set<std::string> deleted_;
  int next_id_ = 0;
};

}  // namespace oep::acquisition::test_support
