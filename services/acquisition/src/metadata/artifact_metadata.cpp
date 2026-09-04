#include "oep/acquisition/metadata/artifact_metadata.hpp"

namespace oep::acquisition::metadata {

std::string to_string(ExtractionStatus status) {
  switch (status) {
    case ExtractionStatus::Pending:
      return "pending";
    case ExtractionStatus::Extracted:
      return "extracted";
    case ExtractionStatus::Failed:
      return "failed";
  }
  return "pending";
}

std::optional<ExtractionStatus> extraction_status_from_string(const std::string& text) {
  if (text == "pending") return ExtractionStatus::Pending;
  if (text == "extracted") return ExtractionStatus::Extracted;
  if (text == "failed") return ExtractionStatus::Failed;
  return std::nullopt;
}

}  // namespace oep::acquisition::metadata
