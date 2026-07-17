#include "oep/acquisition/metadata/file_type_detector.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <optional>
#include <utility>
#include <vector>

namespace oep::acquisition::metadata {

namespace {

std::string lowercase(std::string text) {
  std::transform(text.begin(), text.end(), text.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return text;
}

std::string extension_of(const std::filesystem::path& path) {
  std::string extension = path.extension().string();
  if (!extension.empty() && extension.front() == '.') {
    extension.erase(0, 1);
  }
  return lowercase(extension);
}

bool header_starts_with(const std::vector<unsigned char>& header, std::initializer_list<int> bytes) {
  if (header.size() < bytes.size()) {
    return false;
  }
  std::size_t i = 0;
  for (int expected : bytes) {
    if (header[i] != static_cast<unsigned char>(expected)) {
      return false;
    }
    ++i;
  }
  return true;
}

std::string trimmed_lowercase_prefix(const std::vector<unsigned char>& header, std::size_t max_length) {
  std::size_t start = 0;
  while (start < header.size() &&
         (header[start] == ' ' || header[start] == '\t' || header[start] == '\r' || header[start] == '\n')) {
    ++start;
  }
  const std::size_t end = std::min(header.size(), start + max_length);
  std::string prefix(header.begin() + static_cast<std::ptrdiff_t>(start), header.begin() + static_cast<std::ptrdiff_t>(end));
  return lowercase(prefix);
}

// Extension-based fallback for formats with no reliable magic bytes (text
// formats), and a safety net for binary formats whose signature check
// might miss a truncated/empty file -- WORK_PACKAGE-008 Validation Rules:
// "Unsupported file types shall still produce metadata when possible."
std::optional<FileTypeInfo> detect_by_extension(const std::string& extension) {
  static const std::vector<std::pair<std::string, FileTypeInfo>> kExtensionMap = {
      {"pdf", {"PDF", "application/pdf"}},
      {"zip", {"ZIP", "application/zip"}},
      {"7z", {"7Z", "application/x-7z-compressed"}},
      {"tar", {"TAR", "application/x-tar"}},
      {"gz", {"GZIP", "application/gzip"}},
      {"gzip", {"GZIP", "application/gzip"}},
      {"png", {"PNG", "image/png"}},
      {"jpg", {"JPEG", "image/jpeg"}},
      {"jpeg", {"JPEG", "image/jpeg"}},
      {"svg", {"SVG", "image/svg+xml"}},
      {"xml", {"XML", "application/xml"}},
      {"json", {"JSON", "application/json"}},
      {"yaml", {"YAML", "application/x-yaml"}},
      {"yml", {"YAML", "application/x-yaml"}},
      {"csv", {"CSV", "text/csv"}},
      {"txt", {"TXT", "text/plain"}},
      {"html", {"HTML", "text/html"}},
      {"htm", {"HTML", "text/html"}},
      {"md", {"Markdown", "text/markdown"}},
      {"markdown", {"Markdown", "text/markdown"}},
  };

  for (const auto& [ext, info] : kExtensionMap) {
    if (ext == extension) {
      return info;
    }
  }
  return std::nullopt;
}

std::optional<FileTypeInfo> detect_by_signature(const std::vector<unsigned char>& header) {
  if (header.size() >= 5 && header[0] == '%' && header[1] == 'P' && header[2] == 'D' && header[3] == 'F' &&
      header[4] == '-') {
    return FileTypeInfo{"PDF", "application/pdf"};
  }
  if (header_starts_with(header, {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A})) {
    return FileTypeInfo{"PNG", "image/png"};
  }
  if (header_starts_with(header, {0xFF, 0xD8, 0xFF})) {
    return FileTypeInfo{"JPEG", "image/jpeg"};
  }
  if (header_starts_with(header, {0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C})) {
    return FileTypeInfo{"7Z", "application/x-7z-compressed"};
  }
  if (header_starts_with(header, {0x50, 0x4B, 0x03, 0x04}) ||
      header_starts_with(header, {0x50, 0x4B, 0x05, 0x06}) ||
      header_starts_with(header, {0x50, 0x4B, 0x07, 0x08})) {
    return FileTypeInfo{"ZIP", "application/zip"};
  }
  // GZIP checked after ZIP/7Z/PNG (all more specific multi-byte magic
  // sequences) since 0x1F 0x8B is only two bytes.
  if (header_starts_with(header, {0x1F, 0x8B})) {
    return FileTypeInfo{"GZIP", "application/gzip"};
  }
  // POSIX ustar magic sits at offset 257, not offset 0.
  if (header.size() >= 262 && header[257] == 'u' && header[258] == 's' && header[259] == 't' &&
      header[260] == 'a' && header[261] == 'r') {
    return FileTypeInfo{"TAR", "application/x-tar"};
  }

  const std::string prefix = trimmed_lowercase_prefix(header, 64);
  if (prefix.rfind("<?xml", 0) == 0) {
    if (prefix.find("<svg") != std::string::npos) {
      return FileTypeInfo{"SVG", "image/svg+xml"};
    }
    return FileTypeInfo{"XML", "application/xml"};
  }
  if (prefix.rfind("<svg", 0) == 0) {
    return FileTypeInfo{"SVG", "image/svg+xml"};
  }
  if (prefix.rfind("<!doctype html", 0) == 0 || prefix.rfind("<html", 0) == 0) {
    return FileTypeInfo{"HTML", "text/html"};
  }

  return std::nullopt;
}

}  // namespace

FileTypeInfo detect_file_type(const std::filesystem::path& path) {
  std::vector<unsigned char> header;
  std::ifstream stream(path, std::ios::binary);
  if (stream.is_open()) {
    header.resize(512);
    stream.read(reinterpret_cast<char*>(header.data()), static_cast<std::streamsize>(header.size()));
    header.resize(static_cast<std::size_t>(stream.gcount()));
  }

  if (const auto by_signature = detect_by_signature(header); by_signature.has_value()) {
    return *by_signature;
  }

  if (const auto by_extension = detect_by_extension(extension_of(path)); by_extension.has_value()) {
    return *by_extension;
  }

  return FileTypeInfo{"Unknown", "application/octet-stream"};
}

}  // namespace oep::acquisition::metadata
