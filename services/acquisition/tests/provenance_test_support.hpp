#pragma once

#include <optional>
#include <string>

namespace oep::acquisition::test_support {

/// Ensures `official_sources` (V1+V2), `acquisition_jobs` (V3),
/// `download_sessions` (V5), `integrity_verifications` (V6),
/// `artifact_metadata` (V7), `reference_vault` (V8+V9), and
/// `acquisition_records` (V10) all exist -- applying the migration files
/// verbatim from disk the first time this runs against a given database,
/// mirroring `reset_vault_schema` -- then truncates them so every test
/// starts from an empty database. Returns an error message if the
/// database is unreachable, in which case the caller should `SKIP` rather
/// than fail.
[[nodiscard]] std::optional<std::string> reset_provenance_schema();

/// A real, Completed Download Session seeded directly via the Postgres
/// repositories (bypassing every Service layer) -- a real Official Source
/// and a real Acquisition Job behind it, mirroring `seed_extracted_metadata`
/// (vault_test_support.hpp) but stopping one stage earlier, since WP-018's
/// Acquisition Record is anchored on the Download Session rather than on
/// Metadata.
struct SeededDownload {
  std::string id;
  std::string job_id;
  std::string source_id;
};

[[nodiscard]] SeededDownload seed_completed_download();

}  // namespace oep::acquisition::test_support
