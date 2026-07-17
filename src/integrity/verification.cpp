#include "oep/acquisition/integrity/verification.hpp"

namespace oep::acquisition::integrity {

std::string to_string(VerificationStatus status) {
  switch (status) {
    case VerificationStatus::Pending:
      return "pending";
    case VerificationStatus::Verified:
      return "verified";
    case VerificationStatus::Failed:
      return "failed";
  }
  return "pending";
}

std::optional<VerificationStatus> verification_status_from_string(const std::string& text) {
  if (text == "pending") return VerificationStatus::Pending;
  if (text == "verified") return VerificationStatus::Verified;
  if (text == "failed") return VerificationStatus::Failed;
  return std::nullopt;
}

}  // namespace oep::acquisition::integrity
