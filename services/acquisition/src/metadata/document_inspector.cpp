#include "oep/acquisition/metadata/document_inspector.hpp"

#include <cctype>
#include <exception>
#include <fstream>
#include <string>

namespace oep::acquisition::metadata {

namespace {

// Bounds how much of a PDF this best-effort inspector reads -- large
// enough for the small, non-linearized test/demo artifacts this pipeline
// deals with today, without loading an arbitrarily large file wholly into
// memory for what is explicitly "basic" inspection, not a real PDF
// parser.
constexpr std::size_t kMaxInspectBytes = 2 * 1024 * 1024;

std::optional<std::string> read_pdf_version(const std::string& content) {
  const auto marker = content.find("%PDF-");
  if (marker == std::string::npos) {
    return std::nullopt;
  }
  const std::size_t version_start = marker + 5;
  std::size_t version_end = version_start;
  while (version_end < content.size() &&
         (std::isdigit(static_cast<unsigned char>(content[version_end])) || content[version_end] == '.')) {
    ++version_end;
  }
  if (version_end == version_start) {
    return std::nullopt;
  }
  return content.substr(version_start, version_end - version_start);
}

// Locates the document's `/Pages` object and reads the integer following
// its `/Count` entry -- the standard low-level trick minimal PDF readers
// use to get a total page count without walking the full page tree.
std::optional<int> read_pdf_page_count(const std::string& content) {
  const auto pages_marker = content.find("/Pages");
  if (pages_marker == std::string::npos) {
    return std::nullopt;
  }

  const auto count_marker = content.find("/Count", pages_marker);
  if (count_marker == std::string::npos) {
    return std::nullopt;
  }

  std::size_t digit_start = count_marker + 6;
  while (digit_start < content.size() && std::isspace(static_cast<unsigned char>(content[digit_start]))) {
    ++digit_start;
  }
  std::size_t digit_end = digit_start;
  while (digit_end < content.size() && std::isdigit(static_cast<unsigned char>(content[digit_end]))) {
    ++digit_end;
  }
  if (digit_end == digit_start) {
    return std::nullopt;
  }

  try {
    return std::stoi(content.substr(digit_start, digit_end - digit_start));
  } catch (const std::exception&) {
    return std::nullopt;
  }
}

}  // namespace

PdfProperties inspect_pdf(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream.is_open()) {
    return PdfProperties{};
  }

  std::string content(kMaxInspectBytes, '\0');
  stream.read(content.data(), static_cast<std::streamsize>(content.size()));
  content.resize(static_cast<std::size_t>(stream.gcount()));

  PdfProperties properties;
  properties.version = read_pdf_version(content);
  properties.page_count = read_pdf_page_count(content);
  return properties;
}

}  // namespace oep::acquisition::metadata
