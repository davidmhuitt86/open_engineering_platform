#pragma once

#include <optional>
#include <string>

namespace oep::acquisition::test_support {

/// Ensures `official_sources` (V1+V2), `acquisition_jobs` (V3), and
/// `download_sessions` (V5) all exist -- applying the migration files
/// verbatim from disk the first time this runs against a given database,
/// mirroring `reset_execution_schema` -- then truncates them so every
/// test starts from an empty database. Returns an error message if the
/// database is unreachable, in which case the caller should `SKIP`
/// rather than fail.
[[nodiscard]] std::optional<std::string> reset_downloads_schema();

}  // namespace oep::acquisition::test_support
