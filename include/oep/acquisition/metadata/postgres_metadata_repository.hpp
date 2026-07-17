#pragma once

#include <memory>

#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/metadata/metadata_repository.hpp"

namespace pqxx {
class connection;
}

namespace oep::acquisition::metadata {

/// `IMetadataRepository` backed by PostgreSQL via `libpqxx`
/// (WORK_PACKAGE-008), mirroring `integrity::PostgresVerificationRepository`.
class PostgresMetadataRepository : public IMetadataRepository {
 public:
  explicit PostgresMetadataRepository(const common::DatabaseConfig& config);
  ~PostgresMetadataRepository() override;

  PostgresMetadataRepository(const PostgresMetadataRepository&) = delete;
  PostgresMetadataRepository& operator=(const PostgresMetadataRepository&) = delete;

  ArtifactMetadata create(const ArtifactMetadata& metadata) override;
  std::optional<ArtifactMetadata> find_by_id(const std::string& id) override;
  std::vector<ArtifactMetadata> list(const MetadataFilter& filter) override;
  std::optional<ArtifactMetadata> update(const std::string& id, const ArtifactMetadata& metadata) override;

 private:
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::acquisition::metadata
