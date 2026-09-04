#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace oep::acquisition::metadata {

/// WORK_PACKAGE-008's "Extraction Status". Not explicitly enumerated in
/// the work package text (unlike `downloads::DownloadStatus`/
/// `integrity::VerificationStatus`, which both had a dedicated "States"
/// section), but the three-state Pending/terminal-success/terminal-failure
/// shape is inferred by direct analogy with both -- "Invalid transitions
/// shall be rejected" is enforced the same structural way
/// `integrity::VerificationStatus` documents: the REST API exposes no
/// route that mutates an existing record, so the only transitions that
/// occur are the two `MetadataExtractionService::extract` performs
/// internally. See README.md "Implementation Decisions".
enum class ExtractionStatus {
  Pending,
  Extracted,
  Failed,
};

[[nodiscard]] std::string to_string(ExtractionStatus status);
[[nodiscard]] std::optional<ExtractionStatus> extraction_status_from_string(const std::string& text);

/// WORK_PACKAGE-008's "Metadata Model". `id` is the externally-visible
/// UUID, mirroring every prior domain model.
///
/// `file_size_bytes` and `sha256_hash` are copied from the referenced
/// Verification record (already computed by the Integrity Verification
/// Engine) rather than recomputed here -- recomputing a cryptographic
/// hash is Integrity Verification's responsibility, not Metadata
/// Extraction's (WORK_PACKAGE-008's Objective: "descriptive metadata,"
/// not re-verification). `file_name` is copied from the underlying
/// Download. `file_extension`, `mime_type`, `pdf_version`, and
/// `pdf_page_count` are populated by `MetadataExtractionService` from
/// File Type Detection / Basic Document Inspection, never supplied
/// directly by a REST client.
///
/// `pdf_version`/`pdf_page_count` are WORK_PACKAGE-008's own example of
/// "Basic container/document properties when readily available" --
/// implemented only for PDF today, the sole example the work package
/// gives; see README.md "Implementation Decisions" for why this stays
/// narrow rather than a generic properties bag.
struct ArtifactMetadata {
  std::string id;
  std::string verification_id;
  std::string file_name;
  std::string file_extension;
  std::string mime_type;
  std::uint64_t file_size_bytes = 0;
  std::string sha256_hash;
  std::optional<std::string> file_created_at;
  std::optional<std::string> file_modified_at;
  std::optional<std::string> pdf_version;
  std::optional<int> pdf_page_count;
  ExtractionStatus status = ExtractionStatus::Pending;
  // WORK_PACKAGE-008's "Extraction Timestamp" -- set once extraction
  // reaches a terminal state (Extracted or Failed), mirroring
  // `integrity::Verification::verified_at`.
  std::optional<std::string> extracted_at;
  std::optional<std::string> error_message;
  std::string created_at;
  std::string updated_at;
};

}  // namespace oep::acquisition::metadata
