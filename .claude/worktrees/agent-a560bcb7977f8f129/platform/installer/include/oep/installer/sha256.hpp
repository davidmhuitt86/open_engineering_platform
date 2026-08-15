#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace oep::installer {

// A hand-rolled SHA-256 (FIPS 180-4), consistent with this codebase's own
// no-third-party-dependency convention (platform/repository's hand-rolled
// JSON parser, hand-rolled UUID generation). Used by the Repository
// Registry (WP-REP-002) purely as a local integrity fingerprint for an
// installed package's source archive ("Package Hash", WP-REP-002.md §4) —
// this is NOT a trust or authentication mechanism. It proves a file's
// bytes match what was recorded at install time; it says nothing about
// who produced those bytes or whether they should be trusted. Real
// signature verification is PKG-005 / WP-REP-004, explicitly out of scope
// here.
std::string sha256_hex(const std::vector<std::uint8_t>& data);

// Convenience: reads `path` fully into memory and hashes it. Returns
// std::nullopt if the file cannot be opened for reading.
std::optional<std::string> sha256_hex_file(const std::filesystem::path& path);

} // namespace oep::installer
