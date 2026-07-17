#pragma once

#include <optional>
#include <string>

namespace oep::acquisition::test_support {

/// Ensures `official_sources` (V1+V2), `acquisition_jobs` (V3),
/// `download_sessions` (V5), and `integrity_verifications` (V6) all exist
/// -- applying the migration files verbatim from disk the first time this
/// runs against a given database, mirroring `reset_downloads_schema` --
/// then truncates them so every test starts from an empty database.
/// Returns an error message if the database is unreachable, in which case
/// the caller should `SKIP` rather than fail.
[[nodiscard]] std::optional<std::string> reset_integrity_schema();

/// A Download Session seeded directly via `PostgresDownloadRepository`
/// (bypassing `DownloadService`), with a real file written to
/// `local_storage_path` on disk containing `file_contents` -- so
/// Repository/API/migration tests for WORK_PACKAGE-007 can hash a real
/// artifact without needing the full Engineering Downloader pipeline to
/// run.
struct SeededDownload {
  std::string id;
  std::string local_storage_path;
};

/// Seeds an Official Source, Acquisition Job, and a Completed Download
/// Session (in that dependency order), writing `file_contents` to the
/// download's `local_storage_path`. Returns the download session's `uuid`
/// and the path of the file written for it.
[[nodiscard]] SeededDownload seed_completed_download(const std::string& file_contents = "test artifact contents");

}  // namespace oep::acquisition::test_support
