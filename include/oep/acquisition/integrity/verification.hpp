#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace oep::acquisition::integrity {

/// WORK_PACKAGE-007 "Verification States". "Invalid transitions shall be
/// rejected" -- enforced structurally rather than by an explicit guard: the
/// REST API (WORK_PACKAGE-007 "REST API") exposes no route that mutates an
/// existing Verification, so the only transitions that can ever occur are
/// the two `IntegrityVerificationService::verify` performs internally,
/// Pending -> Verified and Pending -> Failed, mirroring
/// `downloads::DownloadStatus`'s shape. See README.md "Implementation
/// Decisions" and "Architecture Validation".
enum class VerificationStatus {
  Pending,
  Verified,
  Failed,
};

[[nodiscard]] std::string to_string(VerificationStatus status);
[[nodiscard]] std::optional<VerificationStatus> verification_status_from_string(const std::string& text);

/// WORK_PACKAGE-007's "Verification Model". `id` is the externally-visible
/// UUID, mirroring every prior domain model -- distinct from the
/// database's internal surrogate primary key.
///
/// `sha256_hash`, `file_size_bytes`, `verified_at`, and `error_message` are
/// all populated by `IntegrityVerificationService` from the result of
/// hashing the artifact resolved via `download_session_id`, never supplied
/// directly by a REST client. No metadata fields exist here by design --
/// WORK_PACKAGE-007's Objective is explicit that "No metadata extraction or
/// engineering object creation shall be performed."
struct Verification {
  std::string id;
  std::string download_session_id;
  VerificationStatus status = VerificationStatus::Pending;
  std::string sha256_hash;
  std::uint64_t file_size_bytes = 0;
  // WORK_PACKAGE-007's "Verification Timestamp" -- set once the
  // verification reaches a terminal state (Verified or Failed), mirroring
  // `downloads::Download::completed_at`.
  std::optional<std::string> verified_at;
  std::optional<std::string> error_message;
  std::string created_at;
  std::string updated_at;
};

}  // namespace oep::acquisition::integrity
