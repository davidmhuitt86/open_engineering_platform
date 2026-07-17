#include "oep/acquisition/downloads/download.hpp"

#include <algorithm>

namespace oep::acquisition::downloads {

std::string to_string(DownloadStatus status) {
  switch (status) {
    case DownloadStatus::Pending:
      return "pending";
    case DownloadStatus::Downloading:
      return "downloading";
    case DownloadStatus::Completed:
      return "completed";
    case DownloadStatus::Failed:
      return "failed";
    case DownloadStatus::Cancelled:
      return "cancelled";
  }
  return "pending";
}

std::optional<DownloadStatus> download_status_from_string(const std::string& text) {
  if (text == "pending") return DownloadStatus::Pending;
  if (text == "downloading") return DownloadStatus::Downloading;
  if (text == "completed") return DownloadStatus::Completed;
  if (text == "failed") return DownloadStatus::Failed;
  if (text == "cancelled") return DownloadStatus::Cancelled;
  return std::nullopt;
}

int clamp_progress_percentage(std::uint64_t bytes_transferred, std::uint64_t total_bytes) {
  if (total_bytes == 0) {
    return 0;
  }
  const int percentage = static_cast<int>((bytes_transferred * 100) / total_bytes);
  return std::clamp(percentage, 0, 100);
}

}  // namespace oep::acquisition::downloads
