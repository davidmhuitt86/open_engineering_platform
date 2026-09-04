#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>

namespace oep::acquisition::integrity {

struct FileHashResult {
  std::string sha256_hex;
  std::uint64_t file_size_bytes = 0;
};

/// Streams `path` through PicoSHA2 in fixed-size chunks rather than loading
/// the whole file into memory (WORK_PACKAGE-007's "File validation" may run
/// against large engineering artifacts). Returns std::nullopt if `path` is
/// not a regular file or a read error occurs mid-stream -- both collapse to
/// the same "could not be read" outcome; `IntegrityVerificationService`
/// distinguishes this from "does not exist at all" by checking
/// `std::filesystem::exists` itself first (see README.md "Implementation
/// Decisions" for why: a path pointing at a directory or otherwise
/// unreadable entry is WORK_PACKAGE-007's "Corrupt Files" case, distinct
/// from its "Missing Files" case).
[[nodiscard]] std::optional<FileHashResult> hash_file_sha256(const std::filesystem::path& path);

}  // namespace oep::acquisition::integrity
