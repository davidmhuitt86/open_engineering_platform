#pragma once

#include <unordered_map>

#include "oep/acquisition/provenance/acquisition_record_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IAcquisitionRecordRepository` so `AcquisitionRecordService`
/// tests exercise orchestration without a live PostgreSQL instance,
/// mirroring `FakeDownloadRepository`. Unlike most other fake repositories
/// in this test suite, `create` DOES enforce the `download_session_id`
/// uniqueness constraint (throwing `DuplicateAcquisitionRecordError`) --
/// that invariant is central enough to WP-018 (exactly one Acquisition
/// Record per Download Session) that Service-layer tests need to exercise
/// it without a live database, mirroring `FakeVaultRepository`'s handling
/// of `metadata_id` uniqueness.
class FakeAcquisitionRecordRepository : public provenance::IAcquisitionRecordRepository {
 public:
  provenance::AcquisitionRecord create(const provenance::AcquisitionRecord& record) override {
    for (const auto& [id, existing] : rows_) {
      if (existing.download_session_id == record.download_session_id) {
        throw provenance::DuplicateAcquisitionRecordError(record.download_session_id);
      }
    }
    provenance::AcquisitionRecord stored = record;
    stored.id = "fake-acquisition-record-" + std::to_string(++next_id_);
    stored.created_at = "2026-01-01T00:00:00Z";
    stored.updated_at = stored.created_at;
    rows_[stored.id] = stored;
    return stored;
  }

  std::optional<provenance::AcquisitionRecord> find_by_id(const std::string& id) override {
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    return it->second;
  }

  std::optional<provenance::AcquisitionRecord> find_by_download_session_id(
      const std::string& download_session_id) override {
    for (const auto& [id, existing] : rows_) {
      if (existing.download_session_id == download_session_id) {
        return existing;
      }
    }
    return std::nullopt;
  }

  std::vector<provenance::AcquisitionRecord> list(const provenance::AcquisitionRecordFilter& filter) override {
    std::vector<provenance::AcquisitionRecord> result;
    for (const auto& [id, record] : rows_) {
      if (filter.status.has_value() && record.status != *filter.status) {
        continue;
      }
      result.push_back(record);
    }
    return result;
  }

  std::optional<provenance::AcquisitionRecord> update_status(
      const std::string& id, provenance::AcquisitionRecordStatus status,
      const std::optional<std::string>& error_message) override {
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    it->second.status = status;
    it->second.error_message = error_message;
    it->second.updated_at = "2026-01-02T00:00:00Z";
    return it->second;
  }

 private:
  std::unordered_map<std::string, provenance::AcquisitionRecord> rows_;
  int next_id_ = 0;
};

}  // namespace oep::acquisition::test_support
