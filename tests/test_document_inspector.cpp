#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <filesystem>
#include <fstream>

#include "oep/acquisition/metadata/document_inspector.hpp"

using namespace oep::acquisition::metadata;

namespace {

std::filesystem::path make_scratch_file(const std::string& contents) {
  static std::atomic<int> counter{0};
  const auto dir =
      std::filesystem::temp_directory_path() / ("oep_document_inspector_test_" + std::to_string(++counter));
  std::filesystem::create_directories(dir);
  const auto path = dir / "document.pdf";
  std::ofstream(path, std::ios::binary) << contents;
  return path;
}

}  // namespace

TEST_CASE("inspect_pdf reads the version from the %PDF- header", "[metadata][document_inspector]") {
  const auto path = make_scratch_file("%PDF-1.7\n%some binary junk\n1 0 obj\n<< /Type /Catalog >>\nendobj");
  const auto properties = inspect_pdf(path);
  REQUIRE(properties.version.has_value());
  CHECK(*properties.version == "1.7");
}

TEST_CASE("inspect_pdf reads the page count from the /Pages object's /Count entry",
          "[metadata][document_inspector]") {
  const auto path = make_scratch_file(
      "%PDF-1.4\n"
      "3 0 obj\n<< /Type /Pages /Kids [4 0 R 5 0 R 6 0 R] /Count 3 >>\nendobj\n");
  const auto properties = inspect_pdf(path);
  REQUIRE(properties.page_count.has_value());
  CHECK(*properties.page_count == 3);
}

TEST_CASE("inspect_pdf leaves both fields empty for a non-PDF file", "[metadata][document_inspector]") {
  const auto path = make_scratch_file("this is not a pdf at all");
  const auto properties = inspect_pdf(path);
  CHECK_FALSE(properties.version.has_value());
  CHECK_FALSE(properties.page_count.has_value());
}

TEST_CASE("inspect_pdf leaves page_count empty when no /Pages/Count is present",
          "[metadata][document_inspector]") {
  const auto path = make_scratch_file("%PDF-1.5\n1 0 obj\n<< /Type /Catalog >>\nendobj\n");
  const auto properties = inspect_pdf(path);
  REQUIRE(properties.version.has_value());
  CHECK(*properties.version == "1.5");
  CHECK_FALSE(properties.page_count.has_value());
}

TEST_CASE("inspect_pdf returns empty properties for a missing file", "[metadata][document_inspector]") {
  const auto dir = std::filesystem::temp_directory_path() / "oep_document_inspector_missing_test";
  std::filesystem::create_directories(dir);
  const auto properties = inspect_pdf(dir / "does-not-exist.pdf");
  CHECK_FALSE(properties.version.has_value());
  CHECK_FALSE(properties.page_count.has_value());
}
