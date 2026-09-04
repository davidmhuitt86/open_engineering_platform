#pragma once

#include <optional>
#include <string>
#include <vector>

#include "oep/acquisition/registry/official_source.hpp"

namespace oep::acquisition::registry {

/// Optional filters for "List Sources" / "Filter Sources" (WORK-PACKAGE-002
/// Functional Requirements). Every field is optional; unset fields impose
/// no constraint. Soft-deleted sources are always excluded.
struct SourceFilter {
  std::optional<SourceStatus> status;
  std::optional<TrustLevel> trust_level;
  std::optional<std::string> category;
  std::optional<std::string> country;
};

/// Abstracts persistence for OfficialSource so the Service layer can be
/// unit-tested against a fake without a live PostgreSQL instance, and so
/// the concrete PostgreSQL implementation stays isolated behind one
/// interface (Engineering Principle 10: Composability).
class IOfficialSourceRepository {
 public:
  virtual ~IOfficialSourceRepository() = default;

  /// Inserts `source` and returns the stored row (`id`/`created_at`/
  /// `updated_at` populated by the database).
  virtual OfficialSource create(const OfficialSource& source) = 0;

  /// Empty optional if `id` does not exist or is soft-deleted.
  virtual std::optional<OfficialSource> find_by_id(const std::string& id) = 0;

  /// Soft-deleted sources are always excluded.
  virtual std::vector<OfficialSource> list(const SourceFilter& filter) = 0;

  /// Empty optional if `id` does not exist or is soft-deleted. The row
  /// addressed by `id` is updated in place using every field of `source`
  /// except `id`/`created_at` (preserved) -- `updated_at` is refreshed by
  /// the database.
  virtual std::optional<OfficialSource> update(const std::string& id, const OfficialSource& source) = 0;

  /// Sets `deleted_at`. Returns false if `id` does not exist or is already
  /// soft-deleted. Historical rows are never hard-deleted (WORK-PACKAGE-002:
  /// "Soft deletes only").
  virtual bool soft_delete(const std::string& id) = 0;
};

}  // namespace oep::acquisition::registry
