#pragma once

#include <unordered_map>

#include "oep/acquisition/downloads/download_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IDownloadRepository` so `DownloadService` tests exercise
/// validation and orchestration without a live PostgreSQL instance,
/// mirroring `FakeAcquisitionJobRepository`. Does not enforce that
/// `job_id` references a real job -- the real database's foreign key
/// does that; Service-layer tests are not concerned with it.
class FakeDownloadRepository : public downloads::IDownloadRepository {
 public:
  downloads::Download create(const downloads::Download& download) override {
    downloads::Download stored = download;
    stored.id = "fake-download-" + std::to_string(++next_id_);
    stored.created_at = "2026-01-01T00:00:00Z";
    stored.updated_at = stored.created_at;
    rows_[stored.id] = stored;
    return stored;
  }

  std::optional<downloads::Download> find_by_id(const std::string& id) override {
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    return it->second;
  }

  std::vector<downloads::Download> list(const downloads::DownloadFilter& filter) override {
    std::vector<downloads::Download> result;
    for (const auto& [id, download] : rows_) {
      if (filter.status.has_value() && download.status != *filter.status) {
        continue;
      }
      if (filter.job_id.has_value() && download.job_id != *filter.job_id) {
        continue;
      }
      if (filter.connector_id.has_value() && download.connector_id != *filter.connector_id) {
        continue;
      }
      result.push_back(download);
    }
    return result;
  }

  std::optional<downloads::Download> update(const std::string& id,
                                              const downloads::Download& download) override {
    if (!rows_.contains(id)) {
      return std::nullopt;
    }
    downloads::Download updated = download;
    updated.id = id;
    updated.created_at = rows_.at(id).created_at;
    updated.updated_at = "2026-01-02T00:00:00Z";
    rows_[id] = updated;
    return updated;
  }

 private:
  std::unordered_map<std::string, downloads::Download> rows_;
  int next_id_ = 0;
};

}  // namespace oep::acquisition::test_support
