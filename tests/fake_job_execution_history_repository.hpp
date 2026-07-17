#pragma once

#include <unordered_map>

#include "oep/acquisition/acquisition/job_execution_history_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IJobExecutionHistoryRepository` so
/// `AcquisitionExecutionService` tests exercise transition recording
/// without a live PostgreSQL instance, mirroring
/// `FakeAcquisitionJobRepository`.
class FakeJobExecutionHistoryRepository : public acquisition::IJobExecutionHistoryRepository {
 public:
  void record(const std::string& job_id, acquisition::JobStatus from, acquisition::JobStatus to,
              const std::string& message) override {
    entries_[job_id].push_back(acquisition::JobExecutionHistoryEntry{
        to_string(from), to_string(to), "2026-01-01T00:00:00Z", message});
  }

  std::vector<acquisition::JobExecutionHistoryEntry> list_for_job(const std::string& job_id) override {
    const auto it = entries_.find(job_id);
    if (it == entries_.end()) {
      return {};
    }
    return it->second;
  }

 private:
  std::unordered_map<std::string, std::vector<acquisition::JobExecutionHistoryEntry>> entries_;
};

}  // namespace oep::acquisition::test_support
