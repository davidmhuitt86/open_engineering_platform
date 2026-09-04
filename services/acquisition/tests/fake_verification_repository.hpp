#pragma once

#include <unordered_map>

#include "oep/acquisition/integrity/verification_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IVerificationRepository` so `IntegrityVerificationService`
/// tests exercise validation and orchestration without a live PostgreSQL
/// instance, mirroring `FakeDownloadRepository`. Does not enforce that
/// `download_session_id` references a real download session -- the real
/// database's foreign key does that; Service-layer tests are not concerned
/// with it.
class FakeVerificationRepository : public integrity::IVerificationRepository {
 public:
  integrity::Verification create(const integrity::Verification& verification) override {
    integrity::Verification stored = verification;
    stored.id = "fake-verification-" + std::to_string(++next_id_);
    stored.created_at = "2026-01-01T00:00:00Z";
    stored.updated_at = stored.created_at;
    rows_[stored.id] = stored;
    order_.push_back(stored.id);
    return stored;
  }

  std::optional<integrity::Verification> find_by_id(const std::string& id) override {
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    return it->second;
  }

  std::vector<integrity::Verification> list(const integrity::VerificationFilter& filter) override {
    std::vector<integrity::Verification> result;
    for (const auto& id : order_) {
      const auto& verification = rows_.at(id);
      if (filter.status.has_value() && verification.status != *filter.status) {
        continue;
      }
      if (filter.download_session_id.has_value() &&
          verification.download_session_id != *filter.download_session_id) {
        continue;
      }
      result.push_back(verification);
    }
    return result;
  }

  std::optional<integrity::Verification> update(const std::string& id,
                                                    const integrity::Verification& verification) override {
    if (!rows_.contains(id)) {
      return std::nullopt;
    }
    integrity::Verification updated = verification;
    updated.id = id;
    updated.created_at = rows_.at(id).created_at;
    updated.updated_at = "2026-01-02T00:00:00Z";
    rows_[id] = updated;
    return updated;
  }

 private:
  std::unordered_map<std::string, integrity::Verification> rows_;
  std::vector<std::string> order_;
  int next_id_ = 0;
};

}  // namespace oep::acquisition::test_support
