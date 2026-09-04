#pragma once

#include <filesystem>
#include <optional>
#include <string>

namespace oep::acquisition::metadata {

struct PdfProperties {
  std::optional<std::string> version;
  std::optional<int> page_count;
};

/// WORK_PACKAGE-008's "Basic Document Inspection", implemented for PDF
/// only -- the sole example the work package text gives ("PDF version or
/// page count"). `version` is read directly from the mandatory
/// `%PDF-x.y` header. `page_count` is a best-effort heuristic: it looks
/// for the document's `/Pages` object and reads the integer following
/// its `/Count` entry -- the same low-level trick minimal PDF readers
/// use, without a real PDF parsing library (explicitly out of scope: "Do
/// not implement... Document parsing"). Either field is left empty if it
/// cannot be determined -- this is "inspection," not parsing, so a
/// non-conforming or unusual PDF simply yields less metadata rather than
/// an error (WORK_PACKAGE-008 Validation Rules: "Unsupported file types
/// shall still produce metadata when possible").
[[nodiscard]] PdfProperties inspect_pdf(const std::filesystem::path& path);

}  // namespace oep::acquisition::metadata
