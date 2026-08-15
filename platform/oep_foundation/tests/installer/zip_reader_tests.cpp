#include "oep/installer/zip_reader.hpp"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

int g_failures = 0;

void check(bool condition, const std::string& description) {
    if (!condition) {
        std::cerr << "FAIL: " << description << "\n";
        ++g_failures;
    }
}

void append_u16(std::vector<std::uint8_t>& out, std::uint16_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}

void append_u32(std::vector<std::uint8_t>& out, std::uint32_t value) {
    out.push_back(static_cast<std::uint8_t>(value & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 16) & 0xFF));
    out.push_back(static_cast<std::uint8_t>((value >> 24) & 0xFF));
}

void append_bytes(std::vector<std::uint8_t>& out, const std::string& text) {
    out.insert(out.end(), text.begin(), text.end());
}

// Builds a minimal, valid ZIP archive (Stored/uncompressed entries only)
// containing `entries`, mirroring the exact structure adm-zip (the tool
// oep_exchange's oep-package CLI uses) produces when compression is
// disabled — Local File Header + data per entry, then one Central
// Directory File Header per entry, then the End Of Central Directory
// record. Written by hand here (not via ZipReader itself) so these tests
// exercise ZipReader against an independently-constructed archive.
std::vector<std::uint8_t> build_stored_zip(const std::vector<std::pair<std::string, std::string>>& entries) {
    std::vector<std::uint8_t> out;
    std::vector<std::uint32_t> local_header_offsets;

    for (const auto& [name, content] : entries) {
        local_header_offsets.push_back(static_cast<std::uint32_t>(out.size()));
        append_u32(out, 0x04034b50); // local file header signature
        append_u16(out, 20);         // version needed
        append_u16(out, 0);          // flags
        append_u16(out, 0);          // method: Stored
        append_u16(out, 0);          // mod time
        append_u16(out, 0);          // mod date
        append_u32(out, 0);          // crc-32 (unchecked by ZipReader)
        append_u32(out, static_cast<std::uint32_t>(content.size())); // compressed size
        append_u32(out, static_cast<std::uint32_t>(content.size())); // uncompressed size
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0); // extra field length
        append_bytes(out, name);
        append_bytes(out, content);
    }

    const std::uint32_t central_directory_start = static_cast<std::uint32_t>(out.size());
    for (std::size_t i = 0; i < entries.size(); ++i) {
        const auto& [name, content] = entries[i];
        append_u32(out, 0x02014b50); // central directory signature
        append_u16(out, 20);         // version made by
        append_u16(out, 20);         // version needed
        append_u16(out, 0);          // flags
        append_u16(out, 0);          // method: Stored
        append_u16(out, 0);          // mod time
        append_u16(out, 0);          // mod date
        append_u32(out, 0);          // crc-32
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u32(out, static_cast<std::uint32_t>(content.size()));
        append_u16(out, static_cast<std::uint16_t>(name.size()));
        append_u16(out, 0); // extra field length
        append_u16(out, 0); // comment length
        append_u16(out, 0); // disk number start
        append_u16(out, 0); // internal attributes
        append_u32(out, 0); // external attributes
        append_u32(out, local_header_offsets[i]);
        append_bytes(out, name);
    }
    const std::uint32_t central_directory_size = static_cast<std::uint32_t>(out.size()) - central_directory_start;

    append_u32(out, 0x06054b50); // end of central directory signature
    append_u16(out, 0);          // disk number
    append_u16(out, 0);          // disk with central directory start
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u16(out, static_cast<std::uint16_t>(entries.size()));
    append_u32(out, central_directory_size);
    append_u32(out, central_directory_start);
    append_u16(out, 0); // comment length

    return out;
}

// A Central Directory entry declaring method 8 (DEFLATE) rather than 0
// (Stored) — used to test that ZipReader::read_bytes rejects unsupported
// compression rather than misreading it.
std::vector<std::uint8_t> build_deflate_zip(const std::string& name, const std::string& content) {
    std::vector<std::uint8_t> out = build_stored_zip({{name, content}});
    // Patch the compression method (offset 8 within each header) to 8 in
    // both the local file header (offset 0) and the central directory
    // entry, found by locating each header's signature.
    for (std::size_t i = 0; i + 4 <= out.size(); ++i) {
        const std::uint32_t signature = static_cast<std::uint32_t>(out[i]) |
                                         (static_cast<std::uint32_t>(out[i + 1]) << 8) |
                                         (static_cast<std::uint32_t>(out[i + 2]) << 16) |
                                         (static_cast<std::uint32_t>(out[i + 3]) << 24);
        if (signature == 0x04034b50 && i + 10 < out.size()) {
            out[i + 8] = 8;
        } else if (signature == 0x02014b50 && i + 10 < out.size()) {
            out[i + 10] = 8;
        }
    }
    return out;
}

std::filesystem::path write_temp_archive(const std::vector<std::uint8_t>& bytes, const std::string& file_name) {
    const std::filesystem::path path = std::filesystem::temp_directory_path() / "oep_zip_reader_tests" / file_name;
    std::filesystem::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    file.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    return path;
}

void test_reads_entries_from_a_valid_archive() {
    const std::filesystem::path path = write_temp_archive(
        build_stored_zip({{"manifest/package.json", "{\"a\":1}"}, {"repository/objects/x.json", "{}"}}),
        "valid.zip");

    std::string error;
    const std::optional<oep::installer::ZipReader> reader = oep::installer::ZipReader::open(path, error);
    check(reader.has_value(), "opens a valid archive: " + error);
    if (!reader.has_value()) return;

    check(reader->has_entry("manifest/package.json"), "has_entry finds the manifest");
    check(!reader->has_entry("does/not/exist.json"), "has_entry returns false for a missing entry");
    check(reader->entry_names().size() == 2, "entry_names reports both entries");

    std::string read_error;
    const std::optional<std::string> text = reader->read_text("manifest/package.json", read_error);
    check(text.has_value() && *text == "{\"a\":1}", "read_text returns the entry's exact content");
}

void test_open_fails_for_a_non_zip_file() {
    const std::string content = "not a zip";
    const std::filesystem::path path = write_temp_archive(std::vector<std::uint8_t>(content.begin(), content.end()),
                                                            "not-a-zip.txt");
    std::string error;
    const std::optional<oep::installer::ZipReader> reader = oep::installer::ZipReader::open(path, error);
    check(!reader.has_value(), "open fails for a non-ZIP file");
    check(!error.empty(), "open reports a non-empty error for a non-ZIP file");
}

void test_open_fails_for_a_missing_file() {
    std::string error;
    const std::optional<oep::installer::ZipReader> reader =
        oep::installer::ZipReader::open("/no/such/archive.oep", error);
    check(!reader.has_value(), "open fails for a nonexistent file");
}

void test_read_bytes_fails_for_a_missing_entry() {
    const std::filesystem::path path = write_temp_archive(build_stored_zip({{"a.json", "{}"}}), "missing-entry.zip");
    std::string error;
    const std::optional<oep::installer::ZipReader> reader = oep::installer::ZipReader::open(path, error);
    check(reader.has_value(), "opens the archive");
    if (!reader.has_value()) return;

    std::string read_error;
    const std::optional<std::string> text = reader->read_text("b.json", read_error);
    check(!text.has_value(), "read_text fails for a missing entry");
}

void test_read_bytes_rejects_deflate_entries() {
    const std::filesystem::path path = write_temp_archive(build_deflate_zip("manifest/package.json", "{}"), "deflate.zip");
    std::string error;
    const std::optional<oep::installer::ZipReader> reader = oep::installer::ZipReader::open(path, error);
    check(reader.has_value(), "opens an archive whose Central Directory declares DEFLATE");
    if (!reader.has_value()) return;

    std::string read_error;
    const std::optional<std::string> text = reader->read_text("manifest/package.json", read_error);
    check(!text.has_value(), "read_text rejects a DEFLATE-compressed entry rather than misreading it");
    check(read_error.find("unsupported compression") != std::string::npos,
          "the rejection error names the unsupported-compression reason");
}

} // namespace

int main() {
    test_reads_entries_from_a_valid_archive();
    test_open_fails_for_a_non_zip_file();
    test_open_fails_for_a_missing_file();
    test_read_bytes_fails_for_a_missing_entry();
    test_read_bytes_rejects_deflate_entries();

    std::filesystem::remove_all(std::filesystem::temp_directory_path() / "oep_zip_reader_tests");

    if (g_failures == 0) {
        std::cout << "All ZipReader tests passed.\n";
        return 0;
    }
    std::cerr << g_failures << " ZipReader test(s) failed.\n";
    return 1;
}
