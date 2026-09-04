#pragma once

#include <unordered_map>

#include "oep/acquisition/metadata/metadata_repository.hpp"

namespace oep::acquisition::test_support {

/// In-memory `IMetadataRepository` so `MetadataExtractionService` tests
/// exercise validation and orchestration without a live PostgreSQL
/// instance, mirroring `FakeVerificationRepository`. Does not enforce
/// that `verification_id` references a real verification -- the real
/// database's foreign key does that; Service-layer tests are not
/// concerned with it.
class FakeMetadataRepository : public metadata::IMetadataRepository {
 public:
  metadata::ArtifactMetadata create(const metadata::ArtifactMetadata& record) override {
    metadata::ArtifactMetadata stored = record;
    stored.id = "fake-metadata-" + std::to_string(++next_id_);
    stored.created_at = "2026-01-01T00:00:00Z";
    stored.updated_at = stored.created_at;
    rows_[stored.id] = stored;
    order_.push_back(stored.id);
    return stored;
  }

  std::optional<metadata::ArtifactMetadata> find_by_id(const std::string& id) override {
    const auto it = rows_.find(id);
    if (it == rows_.end()) {
      return std::nullopt;
    }
    return it->second;
  }

  std::vector<metadata::ArtifactMetadata> list(const metadata::MetadataFilter& filter) override {
    std::vector<metadata::ArtifactMetadata> result;
    for (const auto& id : order_) {
      const auto& record = rows_.at(id);
      if (filter.status.has_value() && record.status != *filter.status) {
        continue;
      }
      if (filter.verification_id.has_value() && record.verification_id != *filter.verification_id) {
        continue;
      }
      result.push_back(record);
    }
    return result;
  }

  std::optional<metadata::ArtifactMetadata> update(const std::string& id,
                                                       const metadata::ArtifactMetadata& record) override {
    if (!rows_.contains(id)) {
      return std::nullopt;
    }
    metadata::ArtifactMetadata updated = record;
    updated.id = id;
    updated.created_at = rows_.at(id).created_at;
    updated.updated_at = "2026-01-02T00:00:00Z";
    rows_[id] = updated;
    return updated;
  }

 private:
  std::unordered_map<std::string, metadata::ArtifactMetadata> rows_;
  std::vector<std::string> order_;
  int next_id_ = 0;
};

}  // namespace oep::acquisition::test_support
