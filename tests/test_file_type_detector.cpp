#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>

#include "oep/acquisition/metadata/file_type_detector.hpp"

using namespace oep::acquisition::metadata;

namespace {

std::filesystem::path make_scratch_dir() {
  static std::atomic<int> counter{0};
  auto path =
      std::filesystem::temp_directory_path() / ("oep_file_type_detector_test_" + std::to_string(++counter));
  std::filesystem::create_directories(path);
  return path;
}

std::filesystem::path write_file(const std::string& name, const std::string& contents) {
  const auto path = make_scratch_dir() / name;
  std::ofstream stream(path, std::ios::binary);
  stream << contents;
  return path;
}

std::filesystem::path write_binary_file(const std::string& name, std::initializer_list<int> bytes) {
  const auto path = make_scratch_dir() / name;
  std::ofstream stream(path, std::ios::binary);
  for (int b : bytes) {
    stream.put(static_cast<char>(b));
  }
  return path;
}

}  // namespace

TEST_CASE("detect_file_type identifies PDF by magic bytes", "[metadata][file_type]") {
  const auto path = write_file("document.bin", "%PDF-1.7\n%rest of file");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "PDF");
  CHECK(info.mime_type == "application/pdf");
}

TEST_CASE("detect_file_type identifies PNG by magic bytes", "[metadata][file_type]") {
  const auto path =
      write_binary_file("image.bin", {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00});
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "PNG");
  CHECK(info.mime_type == "image/png");
}

TEST_CASE("detect_file_type identifies JPEG by magic bytes", "[metadata][file_type]") {
  const auto path = write_binary_file("photo.bin", {0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10});
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "JPEG");
}

TEST_CASE("detect_file_type identifies ZIP by magic bytes", "[metadata][file_type]") {
  const auto path = write_binary_file("archive.bin", {0x50, 0x4B, 0x03, 0x04, 0x14, 0x00});
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "ZIP");
  CHECK(info.mime_type == "application/zip");
}

TEST_CASE("detect_file_type identifies 7Z by magic bytes", "[metadata][file_type]") {
  const auto path = write_binary_file("archive.bin", {0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04});
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "7Z");
}

TEST_CASE("detect_file_type identifies GZIP by magic bytes", "[metadata][file_type]") {
  const auto path = write_binary_file("archive.bin", {0x1F, 0x8B, 0x08, 0x00});
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "GZIP");
}

TEST_CASE("detect_file_type identifies TAR by the ustar magic at offset 257", "[metadata][file_type]") {
  const auto path = make_scratch_dir() / "archive.tar";
  std::ofstream stream(path, std::ios::binary);
  std::string header(512, '\0');
  header.replace(257, 5, "ustar");
  stream.write(header.data(), static_cast<std::streamsize>(header.size()));
  stream.close();

  const auto info = detect_file_type(path);
  CHECK(info.type_name == "TAR");
}

TEST_CASE("detect_file_type identifies XML by content prefix", "[metadata][file_type]") {
  const auto path = write_file("data.bin", "<?xml version=\"1.0\"?><root/>");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "XML");
}

TEST_CASE("detect_file_type identifies SVG by content even without the .svg extension", "[metadata][file_type]") {
  const auto path = write_file("image.bin", "<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "SVG");
}

TEST_CASE("detect_file_type identifies HTML by content prefix", "[metadata][file_type]") {
  const auto path = write_file("page.bin", "<!DOCTYPE html><html><body></body></html>");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "HTML");
}

TEST_CASE("detect_file_type falls back to extension for JSON", "[metadata][file_type]") {
  const auto path = write_file("data.json", "{\"key\":\"value\"}");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "JSON");
  CHECK(info.mime_type == "application/json");
}

TEST_CASE("detect_file_type falls back to extension for YAML", "[metadata][file_type]") {
  const auto path = write_file("data.yaml", "key: value");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "YAML");
}

TEST_CASE("detect_file_type falls back to extension for CSV", "[metadata][file_type]") {
  const auto path = write_file("data.csv", "a,b,c\n1,2,3");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "CSV");
}

TEST_CASE("detect_file_type falls back to extension for TXT", "[metadata][file_type]") {
  const auto path = write_file("notes.txt", "just some plain text");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "TXT");
}

TEST_CASE("detect_file_type falls back to extension for Markdown", "[metadata][file_type]") {
  const auto path = write_file("readme.md", "# Heading\n\nSome text.");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "Markdown");
}

TEST_CASE("detect_file_type returns Unknown for an unrecognized type",
          "[metadata][file_type][unsupported]") {
  const auto path = write_file("mystery.xyz", "some content that matches nothing");
  const auto info = detect_file_type(path);
  CHECK(info.type_name == "Unknown");
  CHECK(info.mime_type == "application/octet-stream");
}

TEST_CASE("detect_file_type returns Unknown for a missing file", "[metadata][file_type][missing-file]") {
  const auto dir = make_scratch_dir();
  const auto info = detect_file_type(dir / "does-not-exist.xyz");
  CHECK(info.type_name == "Unknown");
}
