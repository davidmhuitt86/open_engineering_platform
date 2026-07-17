#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace oep::acquisition::test_support {

/// Ensures `official_sources` (V1+V2), `acquisition_jobs` (V3),
/// `download_sessions` (V5), `integrity_verifications` (V6), and
/// `artifact_metadata` (V7) all exist -- applying the migration files
/// verbatim from disk the first time this runs against a given database,
/// mirroring `reset_integrity_schema` -- then truncates them so every test
/// starts from an empty database. Returns an error message if the
/// database is unreachable, in which case the caller should `SKIP` rather
/// than fail.
[[nodiscard]] std::optional<std::string> reset_metadata_schema();

/// A Verification seeded directly via `PostgresVerificationRepository`
/// (bypassing `IntegrityVerificationService`), backed by a real Download
/// Session with a real file written to disk containing `file_contents`,
/// named `file_name` -- so Repository/API/migration tests for
/// WORK_PACKAGE-008 can extract metadata from a real artifact without
/// needing the full Downloader + Integrity Verification pipeline to run.
/// The Verification's `sha256_hash` is the real SHA-256 of the written
/// file (via `integrity::hash_file_sha256`), and its `status` is always
/// `Verified`.
struct SeededVerification {
  std::string id;
  std::string download_session_id;
  std::string local_storage_path;
  std::uint64_t file_size_bytes = 0;
  std::string sha256_hash;
};

[[nodiscard]] SeededVerification seed_verified_download(
    const std::string& file_contents = "test artifact contents", const std::string& file_name = "artifact.txt");

}  // namespace oep::acquisition::test_support
