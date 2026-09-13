#include "oep/acquisition/provenance/acquisition_record_service.hpp"

#include "oep/acquisition/acquisition/acquisition_job_json.hpp"
#include "oep/acquisition/downloads/download_json.hpp"
#include "oep/acquisition/integrity/verification_json.hpp"
#include "oep/acquisition/metadata/artifact_metadata_json.hpp"
#include "oep/acquisition/provenance/acquisition_record_json.hpp"
#include "oep/acquisition/registry/official_source_json.hpp"
#include "oep/acquisition/vault/vault_entry_json.hpp"

namespace oep::acquisition::provenance {

namespace {

nlohmann::json execution_history_entry_to_json(const acquisition::JobExecutionHistoryEntry& entry) {
  return nlohmann::json{
      {"from_status", entry.from_status},
      {"to_status", entry.to_status},
      {"occurred_at", entry.occurred_at},
      {"message", entry.message},
  };
}

}  // namespace

AcquisitionRecordService::AcquisitionRecordService(IAcquisitionRecordRepository& records,
                                                     downloads::IDownloadRepository& downloads,
                                                     acquisition::IAcquisitionJobRepository& jobs,
                                                     acquisition::IJobExecutionHistoryRepository& job_history,
                                                     integrity::IVerificationRepository& verifications,
                                                     metadata::IMetadataRepository& metadata_repository,
                                                     vault::IVaultRepository& vault,
                                                     registry::IOfficialSourceRepository& sources)
    : records_(records),
      downloads_(downloads),
      jobs_(jobs),
      job_history_(job_history),
      verifications_(verifications),
      metadata_repository_(metadata_repository),
      vault_(vault),
      sources_(sources) {}

AcquisitionRecord AcquisitionRecordService::record_download_outcome(const downloads::Download& download) {
  AcquisitionRecord record;
  record.download_session_id = download.id;
  switch (download.status) {
    case downloads::DownloadStatus::Completed:
      record.status = AcquisitionRecordStatus::Acquired;
      break;
    case downloads::DownloadStatus::Failed:
      record.status = AcquisitionRecordStatus::Failed;
      record.error_message = download.error_message;
      break;
    case downloads::DownloadStatus::Pending:
    case downloads::DownloadStatus::Downloading:
    case downloads::DownloadStatus::Cancelled:
      record.status = AcquisitionRecordStatus::Pending;
      break;
  }
  return records_.create(record);
}

std::optional<AcquisitionRecord> AcquisitionRecordService::record_verification_outcome(
    const integrity::Verification& verification) {
  const auto existing = records_.find_by_download_session_id(verification.download_session_id);
  if (!existing.has_value()) {
    return std::nullopt;
  }
  if (verification.status == integrity::VerificationStatus::Verified) {
    return records_.update_status(existing->id, AcquisitionRecordStatus::Verified, std::nullopt);
  }
  return records_.update_status(existing->id, AcquisitionRecordStatus::Failed, verification.error_message);
}

std::optional<AcquisitionRecord> AcquisitionRecordService::record_metadata_outcome(
    const metadata::ArtifactMetadata& item) {
  if (item.status != metadata::ExtractionStatus::Failed) {
    return std::nullopt;
  }
  const auto verification = verifications_.find_by_id(item.verification_id);
  if (!verification.has_value()) {
    return std::nullopt;
  }
  const auto existing = records_.find_by_download_session_id(verification->download_session_id);
  if (!existing.has_value()) {
    return std::nullopt;
  }
  return records_.update_status(existing->id, AcquisitionRecordStatus::Failed, item.error_message);
}

std::optional<AcquisitionRecord> AcquisitionRecordService::record_vault_publication(const vault::VaultEntry& entry) {
  const auto existing = records_.find_by_download_session_id(entry.download_session_id);
  if (!existing.has_value()) {
    return std::nullopt;
  }
  return records_.update_status(existing->id, AcquisitionRecordStatus::Published, std::nullopt);
}

std::optional<AcquisitionRecord> AcquisitionRecordService::get(const std::string& id) {
  return records_.find_by_id(id);
}

std::vector<AcquisitionRecord> AcquisitionRecordService::list(const AcquisitionRecordFilter& filter) {
  return records_.list(filter);
}

std::optional<nlohmann::json> AcquisitionRecordService::get_provenance(const std::string& id) {
  const auto record = records_.find_by_id(id);
  if (!record.has_value()) {
    return std::nullopt;
  }

  nlohmann::json body;
  body["acquisition_record"] = to_json(*record);

  const auto download = downloads_.find_by_id(record->download_session_id);
  if (download.has_value()) {
    body["download"] = downloads::to_json(*download);

    const auto job = jobs_.find_by_id(download->job_id);
    if (job.has_value()) {
      body["job"] = acquisition::to_json(*job);

      const auto source = sources_.find_by_id(job->source_id);
      if (source.has_value()) {
        body["source"] = registry::to_json(*source);
      }

      nlohmann::json history = nlohmann::json::array();
      for (const auto& entry : job_history_.list_for_job(job->id)) {
        history.push_back(execution_history_entry_to_json(entry));
      }
      body["execution_history"] = history;
    }
  }

  nlohmann::json verifications_json = nlohmann::json::array();
  nlohmann::json metadata_json = nlohmann::json::array();
  std::optional<vault::VaultEntry> vault_entry;
  for (const auto& verification :
       verifications_.list(integrity::VerificationFilter{.download_session_id = record->download_session_id})) {
    verifications_json.push_back(integrity::to_json(verification));

    for (const auto& item :
         metadata_repository_.list(metadata::MetadataFilter{.verification_id = verification.id})) {
      metadata_json.push_back(metadata::to_json(item));

      if (!vault_entry.has_value()) {
        const auto published = vault_.list(vault::VaultFilter{.metadata_id = item.id});
        if (!published.empty()) {
          vault_entry = published.front();
        }
      }
    }
  }
  body["verifications"] = verifications_json;
  body["metadata"] = metadata_json;
  body["vault_entry"] = vault_entry.has_value() ? vault::to_json(*vault_entry) : nlohmann::json(nullptr);

  return body;
}

}  // namespace oep::acquisition::provenance
