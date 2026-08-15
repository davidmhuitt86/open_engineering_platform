#include "oep/installer/zip_reader.hpp"

#include <algorithm>
#include <cstring>
#include <fstream>

namespace oep::installer {

namespace {

constexpr std::uint32_t kEndOfCentralDirectorySignature = 0x06054b50;
constexpr std::uint32_t kCentralDirectorySignature = 0x02014b50;
constexpr std::uint32_t kLocalFileHeaderSignature = 0x04034b50;

constexpr std::size_t kEndOfCentralDirectoryFixedSize = 22;
constexpr std::size_t kCentralDirectoryFixedSize = 46;
constexpr std::size_t kLocalFileHeaderFixedSize = 30;

// Ordinary ZIP "Stored" method — no compression. Any other value is
// rejected by read_bytes; see zip_reader.hpp's own class-level comment.
constexpr std::uint16_t kStoredMethod = 0;

std::uint16_t read_u16(const std::vector<std::uint8_t>& data, std::size_t offset) {
    return static_cast<std::uint16_t>(data[offset]) | (static_cast<std::uint16_t>(data[offset + 1]) << 8);
}

std::uint32_t read_u32(const std::vector<std::uint8_t>& data, std::size_t offset) {
    return static_cast<std::uint32_t>(data[offset]) | (static_cast<std::uint32_t>(data[offset + 1]) << 8) |
           (static_cast<std::uint32_t>(data[offset + 2]) << 16) |
           (static_cast<std::uint32_t>(data[offset + 3]) << 24);
}

bool signature_at(const std::vector<std::uint8_t>& data, std::size_t offset, std::uint32_t expected) {
    return offset + 4 <= data.size() && read_u32(data, offset) == expected;
}

std::optional<std::vector<std::uint8_t>> read_whole_file(const std::filesystem::path& path, std::string& out_error) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file) {
        out_error = "could not open '" + path.string() + "'";
        return std::nullopt;
    }
    const std::streamsize size = file.tellg();
    if (size < 0) {
        out_error = "could not determine the size of '" + path.string() + "'";
        return std::nullopt;
    }
    file.seekg(0, std::ios::beg);
    std::vector<std::uint8_t> data(static_cast<std::size_t>(size));
    if (size > 0 && !file.read(reinterpret_cast<char*>(data.data()), size)) {
        out_error = "could not read '" + path.string() + "'";
        return std::nullopt;
    }
    return data;
}

// Scans backward from the end of `data` for the End Of Central Directory
// signature, within the maximum possible comment length (65535 bytes) —
// the standard technique for locating the EOCD in a ZIP that may carry a
// trailing comment.
std::optional<std::size_t> find_end_of_central_directory(const std::vector<std::uint8_t>& data) {
    if (data.size() < kEndOfCentralDirectoryFixedSize) {
        return std::nullopt;
    }
    constexpr std::size_t kMaxCommentLength = 65535;
    const std::size_t search_window = std::min(data.size(), kEndOfCentralDirectoryFixedSize + kMaxCommentLength);
    const std::size_t earliest = data.size() - search_window;
    const std::size_t latest = data.size() - kEndOfCentralDirectoryFixedSize;

    // Scans backward from the latest possible position to `earliest`,
    // inclusive, without ever decrementing an unsigned offset past 0:
    // the loop tests `offset - 1` each time rather than decrementing
    // `offset` itself below `earliest`.
    for (std::size_t offset = latest + 1; offset > earliest; --offset) {
        if (signature_at(data, offset - 1, kEndOfCentralDirectorySignature)) {
            return offset - 1;
        }
    }
    return std::nullopt;
}

} // namespace

ZipReader::ZipReader(std::filesystem::path archive_path, std::vector<CentralDirectoryEntry> entries)
    : archive_path_(std::move(archive_path)), entries_(std::move(entries)) {}

std::optional<ZipReader> ZipReader::open(const std::filesystem::path& archive_path, std::string& out_error) {
    const std::optional<std::vector<std::uint8_t>> data = read_whole_file(archive_path, out_error);
    if (!data.has_value()) {
        return std::nullopt;
    }

    const std::optional<std::size_t> eocd_offset = find_end_of_central_directory(*data);
    if (!eocd_offset.has_value()) {
        out_error = "'" + archive_path.string() + "' is not a valid ZIP archive (no End Of Central Directory record)";
        return std::nullopt;
    }

    const std::size_t eocd = *eocd_offset;
    const std::uint16_t total_entries = read_u16(*data, eocd + 10);
    const std::uint32_t central_directory_offset = read_u32(*data, eocd + 16);

    if (central_directory_offset >= data->size()) {
        out_error = "'" + archive_path.string() + "' has a corrupt Central Directory offset";
        return std::nullopt;
    }

    std::vector<CentralDirectoryEntry> entries;
    entries.reserve(total_entries);

    std::size_t cursor = central_directory_offset;
    for (std::uint16_t i = 0; i < total_entries; ++i) {
        if (!signature_at(*data, cursor, kCentralDirectorySignature) ||
            cursor + kCentralDirectoryFixedSize > data->size()) {
            out_error = "'" + archive_path.string() + "' has a corrupt Central Directory entry";
            return std::nullopt;
        }

        CentralDirectoryEntry entry;
        entry.compression_method = read_u16(*data, cursor + 10);
        entry.compressed_size = read_u32(*data, cursor + 20);
        entry.uncompressed_size = read_u32(*data, cursor + 24);
        const std::uint16_t name_length = read_u16(*data, cursor + 28);
        const std::uint16_t extra_length = read_u16(*data, cursor + 30);
        const std::uint16_t comment_length = read_u16(*data, cursor + 32);
        entry.local_header_offset = read_u32(*data, cursor + 42);

        const std::size_t name_start = cursor + kCentralDirectoryFixedSize;
        if (name_start + name_length > data->size()) {
            out_error = "'" + archive_path.string() + "' has a corrupt Central Directory entry name";
            return std::nullopt;
        }
        entry.name.assign(reinterpret_cast<const char*>(data->data() + name_start), name_length);

        entries.push_back(std::move(entry));
        cursor = name_start + name_length + extra_length + comment_length;
    }

    return ZipReader(archive_path, std::move(entries));
}

bool ZipReader::has_entry(const std::string& entry_name) const {
    return find(entry_name) != nullptr;
}

std::vector<std::string> ZipReader::entry_names() const {
    std::vector<std::string> names;
    names.reserve(entries_.size());
    for (const CentralDirectoryEntry& entry : entries_) {
        names.push_back(entry.name);
    }
    return names;
}

const ZipReader::CentralDirectoryEntry* ZipReader::find(const std::string& entry_name) const {
    for (const CentralDirectoryEntry& entry : entries_) {
        if (entry.name == entry_name) {
            return &entry;
        }
    }
    return nullptr;
}

std::optional<std::vector<std::uint8_t>> ZipReader::read_bytes(const std::string& entry_name,
                                                                 std::string& out_error) const {
    const CentralDirectoryEntry* entry = find(entry_name);
    if (entry == nullptr) {
        out_error = "no entry named '" + entry_name + "' in '" + archive_path_.string() + "'";
        return std::nullopt;
    }
    if (entry->compression_method != kStoredMethod) {
        out_error = "entry '" + entry_name +
                     "' uses an unsupported compression method (only Stored/uncompressed entries are supported — "
                     "see ZipReader's own documented limitation)";
        return std::nullopt;
    }

    std::string read_error;
    const std::optional<std::vector<std::uint8_t>> whole_file = read_whole_file(archive_path_, read_error);
    if (!whole_file.has_value()) {
        out_error = read_error;
        return std::nullopt;
    }
    const std::vector<std::uint8_t>& data = *whole_file;

    const std::size_t local_header = entry->local_header_offset;
    if (!signature_at(data, local_header, kLocalFileHeaderSignature) ||
        local_header + kLocalFileHeaderFixedSize > data.size()) {
        out_error = "entry '" + entry_name + "' has a corrupt Local File Header";
        return std::nullopt;
    }

    const std::uint16_t name_length = read_u16(data, local_header + 26);
    const std::uint16_t extra_length = read_u16(data, local_header + 28);
    const std::size_t data_start = local_header + kLocalFileHeaderFixedSize + name_length + extra_length;

    if (data_start + entry->compressed_size > data.size()) {
        out_error = "entry '" + entry_name + "' extends past the end of '" + archive_path_.string() + "'";
        return std::nullopt;
    }

    return std::vector<std::uint8_t>(data.begin() + static_cast<std::ptrdiff_t>(data_start),
                                      data.begin() + static_cast<std::ptrdiff_t>(data_start + entry->compressed_size));
}

std::optional<std::string> ZipReader::read_text(const std::string& entry_name, std::string& out_error) const {
    const std::optional<std::vector<std::uint8_t>> bytes = read_bytes(entry_name, out_error);
    if (!bytes.has_value()) {
        return std::nullopt;
    }
    return std::string(bytes->begin(), bytes->end());
}

} // namespace oep::installer
