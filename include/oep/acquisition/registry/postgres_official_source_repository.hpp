#pragma once

#include <memory>

#include "oep/acquisition/common/config.hpp"
#include "oep/acquisition/registry/official_source_repository.hpp"

namespace pqxx {
class connection;
}

namespace oep::acquisition::registry {

/// `IOfficialSourceRepository` backed by PostgreSQL via `libpqxx`
/// (WORK-PACKAGE-002 -- see README.md "Implementation Decisions" for why
/// libpqxx now sits alongside WORK_PACKAGE_001's connection-only raw
/// `libpq` wrapper: the Repository layer needs real parameterized CRUD
/// queries, which is exactly the reassessment WORK_PACKAGE_001's README
/// flagged as a future consideration).
///
/// The constructor connects immediately and throws if the connection
/// fails -- unlike `database::DatabaseConnection`, a Repository with no
/// working connection cannot do anything useful, so there is no
/// "unconnected but valid" state to model. Callers that want
/// WORK_PACKAGE_001's non-fatal startup behavior should catch the
/// exception themselves (see src/app/main.cpp).
class PostgresOfficialSourceRepository : public IOfficialSourceRepository {
 public:
  explicit PostgresOfficialSourceRepository(const common::DatabaseConfig& config);
  ~PostgresOfficialSourceRepository() override;

  PostgresOfficialSourceRepository(const PostgresOfficialSourceRepository&) = delete;
  PostgresOfficialSourceRepository& operator=(const PostgresOfficialSourceRepository&) = delete;

  OfficialSource create(const OfficialSource& source) override;
  std::optional<OfficialSource> find_by_id(const std::string& id) override;
  std::vector<OfficialSource> list(const SourceFilter& filter) override;
  std::optional<OfficialSource> update(const std::string& id, const OfficialSource& source) override;
  bool soft_delete(const std::string& id) override;

 private:
  std::unique_ptr<pqxx::connection> connection_;
};

}  // namespace oep::acquisition::registry
