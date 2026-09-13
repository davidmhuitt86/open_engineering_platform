#include "oep/acquisition/provenance/acquisition_record.hpp"

namespace oep::acquisition::provenance {

std::string to_string(AcquisitionRecordStatus status) {
  switch (status) {
    case AcquisitionRecordStatus::Pending:
      return "pending";
    case AcquisitionRecordStatus::Acquired:
      return "acquired";
    case AcquisitionRecordStatus::Verified:
      return "verified";
    case AcquisitionRecordStatus::Published:
      return "published";
    case AcquisitionRecordStatus::Failed:
      return "failed";
    case AcquisitionRecordStatus::Archived:
      return "archived";
  }
  return "pending";
}

std::optional<AcquisitionRecordStatus> acquisition_record_status_from_string(const std::string& text) {
  if (text == "pending") return AcquisitionRecordStatus::Pending;
  if (text == "acquired") return AcquisitionRecordStatus::Acquired;
  if (text == "verified") return AcquisitionRecordStatus::Verified;
  if (text == "published") return AcquisitionRecordStatus::Published;
  if (text == "failed") return AcquisitionRecordStatus::Failed;
  if (text == "archived") return AcquisitionRecordStatus::Archived;
  return std::nullopt;
}

}  // namespace oep::acquisition::provenance
