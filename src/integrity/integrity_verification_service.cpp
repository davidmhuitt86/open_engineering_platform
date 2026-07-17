#include "oep/acquisition/integrity/integrity_verification_service.hpp"

#include <filesystem>

#include "oep/acquisition/common/time.hpp"
#include "oep/acquisition/integrity/hashing.hpp"
#include "oep/acquisition/integrity/validation.hpp"
#include "oep/acquisition/integrity/verification_errors.hpp"

namespace oep::acquisition::integrity {

namespace {

// WORK_PACKAGE-007 lists "Verify Existing Hashes" and "Detect Corrupt
// Files" as distinct capabilities from "Generate Cryptographic Hashes",
// but defines only one creation route (`POST /verifications`) and no
// client-supplied "expected hash" field. The self-consistent reading used
// here: re-verifying a download session that already has a prior Verified
// hash on record recomputes the hash and compares it against that prior
// value, flagging a mismatch as corruption. See README.md "Implementation
// Decisions".
std::optional<std::string> latest_verified_hash(IVerificationRepository& verifications,
                                                   const std::string& download_session_id) {
  VerificationFilter filter;
  filter.download_session_id = download_session_id;
  filter.status = VerificationStatus::Verified;
  const auto matches = verifications.list(filter);
  if (matches.empty()) {
    return std::nullopt;
  }
  return matches.back().sha256_hash;
}

}  // namespace

IntegrityVerificationService::IntegrityVerificationService(IVerificationRepository& verifications,
                                                              downloads::IDownloadRepository& downloads)
    : verifications_(verifications), downloads_(downloads) {}

Verification IntegrityVerificationService::verify(const nlohmann::json& body) {
  const CreateVerificationRequest request = parse_and_validate_create(body);

  const auto download = downloads_.find_by_id(request.download_session_id);
  if (!download.has_value()) {
    throw UnknownDownloadSessionError(request.download_session_id);
  }

  const auto previous_hash = latest_verified_hash(verifications_, request.download_session_id);

  Verification verification;
  verification.download_session_id = request.download_session_id;
  verification.status = VerificationStatus::Pending;
  Verification created = verifications_.create(verification);

  const std::filesystem::path artifact_path = download->local_storage_path;

  Verification finalized = created;
  finalized.verified_at = common::current_timestamp_utc();

  if (!std::filesystem::exists(artifact_path)) {
    finalized.status = VerificationStatus::Failed;
    finalized.error_message = "Downloaded artifact does not exist: " + artifact_path.string();
  } else {
    const auto hash_result = hash_file_sha256(artifact_path);
    if (!hash_result.has_value()) {
      finalized.status = VerificationStatus::Failed;
      finalized.error_message =
          "Downloaded artifact could not be read (corrupt or inaccessible): " + artifact_path.string();
    } else {
      finalized.sha256_hash = hash_result->sha256_hex;
      finalized.file_size_bytes = hash_result->file_size_bytes;

      if (hash_result->file_size_bytes == 0) {
        finalized.status = VerificationStatus::Failed;
        finalized.error_message = "Downloaded artifact is empty: " + artifact_path.string();
      } else if (previous_hash.has_value() && *previous_hash != hash_result->sha256_hex) {
        finalized.status = VerificationStatus::Failed;
        finalized.error_message = "Computed SHA-256 does not match previously verified hash "
                                   "(artifact may be corrupt): expected " +
                                   *previous_hash + ", got " + hash_result->sha256_hex;
      } else {
        finalized.status = VerificationStatus::Verified;
      }
    }
  }

  return verifications_.update(created.id, finalized).value_or(finalized);
}

std::optional<Verification> IntegrityVerificationService::get(const std::string& id) {
  return verifications_.find_by_id(id);
}

std::vector<Verification> IntegrityVerificationService::list(const VerificationFilter& filter) {
  return verifications_.list(filter);
}

}  // namespace oep::acquisition::integrity
