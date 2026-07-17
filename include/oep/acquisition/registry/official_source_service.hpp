#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/registry/official_source.hpp"
#include "oep/acquisition/registry/official_source_repository.hpp"

namespace oep::acquisition::registry {

/// Validation + orchestration for the Official Source Registry
/// (WORK-PACKAGE-002). Depends on `IOfficialSourceRepository` rather than a
/// concrete PostgreSQL type so it can be unit-tested against a fake
/// repository without a live database.
class OfficialSourceService {
 public:
  explicit OfficialSourceService(IOfficialSourceRepository& repository);

  /// Throws ValidationError if `body` fails WORK-PACKAGE-002's validation
  /// rules.
  OfficialSource create(const nlohmann::json& body);

  std::optional<OfficialSource> get(const std::string& id);

  std::vector<OfficialSource> list(const SourceFilter& filter);

  /// Empty optional if `id` does not exist. Throws ValidationError if
  /// `body` fails validation (including attempts to change immutable
  /// fields).
  std::optional<OfficialSource> update(const std::string& id, const nlohmann::json& body);

  bool remove(const std::string& id);

  /// Convenience wrappers over `update` for the "Enable Source" / "Disable
  /// Source" functional requirements -- WORK-PACKAGE-002's REST API section
  /// lists exactly five source routes plus /health with no dedicated
  /// enable/disable endpoints, so these are reachable today via the
  /// Service layer (and, over REST, a generic PUT status change).
  std::optional<OfficialSource> enable(const std::string& id);
  std::optional<OfficialSource> disable(const std::string& id);

 private:
  IOfficialSourceRepository& repository_;

  std::optional<OfficialSource> set_status(const std::string& id, SourceStatus status);
};

}  // namespace oep::acquisition::registry
