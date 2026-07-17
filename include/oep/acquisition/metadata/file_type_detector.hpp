#pragma once

#include <filesystem>
#include <string>

namespace oep::acquisition::metadata {

struct FileTypeInfo {
  // e.g. "PDF", "ZIP", "TXT" -- "Unknown" when nothing matches
  // (WORK_PACKAGE-008 Validation Rules: "Unsupported file types shall
  // still produce metadata when possible" -- an unrecognized type is not
  // a failure).
  std::string type_name;
  std::string mime_type;
};

/// WORK_PACKAGE-008's "File Type Detection": identifies `path`'s file
/// type via magic-byte signatures (for formats with a reliable binary
/// header -- PDF, PNG, JPEG, GZIP, ZIP, 7Z, TAR) falling back to
/// extension-based matching (for text formats with no reliable magic
/// bytes -- XML, JSON, YAML, CSV, TXT, HTML, Markdown, SVG), and finally
/// `{"Unknown", "application/octet-stream"}` if nothing matches.
///
/// "Architecture shall support future file type plugins" is satisfied by
/// an internal, ordered signature table (`file_type_detector.cpp`) that a
/// future file type is added to directly -- a full runtime plugin-loading
/// mechanism was not built, mirroring how WORK_PACKAGE-005 satisfied
/// "Capabilities shall be extensible" with a plain `std::set<std::string>`
/// rather than a dynamic plugin system. See README.md "Implementation
/// Decisions".
[[nodiscard]] FileTypeInfo detect_file_type(const std::filesystem::path& path);

}  // namespace oep::acquisition::metadata
