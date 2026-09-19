#pragma once

#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/database/resilient_connection.hpp"
#include "oep/acquisition/provenance/acquisition_record_repository.hpp"

namespace oep::acquisition::provenance {

/// `IAcquisitionRecordRepository` backed by PostgreSQL via `libpqxx`
/// (WP-018), mirroring `vault::PostgresVaultRepository`.
class PostgresAcquisitionRecordRepository : public IAcquisitionRecordRepository {
 public:
  explicit PostgresAcquisitionRecordRepository(const common::DatabaseConfig& config);
  ~PostgresAcquisitionRecordRepository() override;

  PostgresAcquisitionRecordRepository(const PostgresAcquisitionRecordRepository&) = delete;
  PostgresAcquisitionRecordRepository& operator=(const PostgresAcquisitionRecordRepository&) = delete;

  AcquisitionRecord create(const AcquisitionRecord& record) override;
  std::optional<AcquisitionRecord> find_by_id(const std::string& id) override;
  std::optional<AcquisitionRecord> find_by_download_session_id(const std::string& download_session_id) override;
  std::vector<AcquisitionRecord> list(const AcquisitionRecordFilter& filter) override;
  std::optional<AcquisitionRecord> update_status(const std::string& id, AcquisitionRecordStatus status,
                                                  const std::optional<std::string>& error_message) override;

 private:
  database::ResilientConnection connection_;
};

}  // namespace oep::acquisition::provenance
