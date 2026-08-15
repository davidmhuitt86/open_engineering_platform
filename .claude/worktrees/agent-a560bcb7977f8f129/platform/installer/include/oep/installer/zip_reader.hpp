#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace oep::installer {

// A minimal reader for `.oep` package archives (PKG-001 §14: "deterministic
// ZIP encoding"). Supports only the ZIP "Stored" (uncompressed, method 0)
// entry format — DEFLATE-compressed entries are rejected with a clear
// error rather than silently misread.
//
// This is a deliberate scope limit for WP-REP-001, not a general-purpose
// ZIP implementation: implementing a correct DEFLATE decompressor is a
// meaningfully larger, higher-risk undertaking (RFC 1951 Huffman/LZ77
// decoding of externally-supplied, potentially-malformed input) than this
// Work Package's "smallest possible implementation" mandate justifies.
// This codebase's own established convention — platform/repository's own
// hand-rolled JSON parser rather than a third-party dependency — argues
// against closing the gap with a compression-library dependency instead.
// DEFLATE support is explicitly deferred; see platform/installer/README.md
// and OEP-ARCH-002.
class ZipReader {
public:
    // Opens `archive_path` and parses its End Of Central Directory and
    // Central Directory records. Returns std::nullopt (with `out_error`
    // populated) if the file cannot be read, is not a ZIP archive, or the
    // Central Directory cannot be parsed structurally. Does not itself
    // reject DEFLATE entries — that is only detected when read_bytes/
    // read_text is called for a specific entry.
    static std::optional<ZipReader> open(const std::filesystem::path& archive_path, std::string& out_error);

    bool has_entry(const std::string& entry_name) const;
    std::vector<std::string> entry_names() const;

    // Reads and returns `entry_name`'s uncompressed bytes. Returns
    // std::nullopt (with `out_error` populated) if the entry does not
    // exist, or exists but is compressed with a method other than Stored
    // (method 0) — see the class-level comment.
    std::optional<std::vector<std::uint8_t>> read_bytes(const std::string& entry_name, std::string& out_error) const;

    // Convenience: read_bytes, interpreted as UTF-8 text.
    std::optional<std::string> read_text(const std::string& entry_name, std::string& out_error) const;

private:
    struct CentralDirectoryEntry {
        std::string name;
        std::uint16_t compression_method = 0;
        std::uint32_t compressed_size = 0;
        std::uint32_t uncompressed_size = 0;
        std::uint32_t local_header_offset = 0;
    };

    ZipReader(std::filesystem::path archive_path, std::vector<CentralDirectoryEntry> entries);

    std::filesystem::path archive_path_;
    std::vector<CentralDirectoryEntry> entries_;

    const CentralDirectoryEntry* find(const std::string& entry_name) const;
};

} // namespace oep::installer
