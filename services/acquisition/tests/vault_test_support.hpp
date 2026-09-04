#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace oep::acquisition::test_support {

/// Ensures `official_sources` (V1+V2), `acquisition_jobs` (V3),
/// `download_sessions` (V5), `integrity_verifications` (V6),
/// `artifact_metadata` (V7), and `reference_vault` (V8) all exist --
/// applying the migration files verbatim from disk the first time this
/// runs against a given database, mirroring `reset_metadata_schema` --
/// then truncates them so every test starts from an empty database.
/// Returns an error message if the database is unreachable, in which
/// case the caller should `SKIP` rather than fail.
[[nodiscard]] std::optional<std::string> reset_vault_schema();

/// A successfully-extracted ArtifactMetadata record seeded directly via
/// the Postgres repositories (bypassing every Service layer), backed by a
/// real Verified Verification, a real Completed Download Session, and a
/// real file written to disk containing `file_contents`, named
/// `file_name` -- so Repository/API/migration tests for WORK_PACKAGE-009
/// can publish a real artifact without needing the full
/// Downloader/Integrity/Metadata pipeline to run.
struct SeededMetadata {
  std::string id;
  std::string verification_id;
  std::string download_session_id;
  std::string source_id;
  std::string local_storage_path;
  std::string sha256_hash;
  std::uint64_t file_size_bytes = 0;
  std::string mime_type;
};

[[nodiscard]] SeededMetadata seed_extracted_metadata(
    const std::string& file_contents = "test artifact contents", const std::string& file_name = "artifact.txt");

}  // namespace oep::acquisition::test_support
