#pragma once

#include <optional>
#include <string>

namespace oep::acquisition::test_support {

/// Ensures `official_sources` (V1+V2) and `acquisition_jobs` (V3) exist --
/// applying the migration files verbatim from disk the first time this
/// runs against a given database, mirroring `reset_official_sources_table`
/// -- then truncates both tables so every test starts from an empty
/// database. Returns an error message if the database is unreachable, in
/// which case the caller should `SKIP` rather than fail.
[[nodiscard]] std::optional<std::string> reset_acquisition_jobs_schema();

/// Inserts a minimal valid Official Source directly (bypassing the
/// Sources Repository) and returns its `uuid`, for use as a Job's
/// `source_id` in tests that need one to exist to satisfy the foreign key
/// (migrations/V3__acquisition_jobs.sql).
[[nodiscard]] std::string seed_official_source();

}  // namespace oep::acquisition::test_support
