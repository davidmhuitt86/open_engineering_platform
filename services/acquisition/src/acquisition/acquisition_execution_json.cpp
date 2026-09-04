#include "oep/acquisition/acquisition/acquisition_execution_json.hpp"

namespace oep::acquisition::acquisition {

nlohmann::json to_json(const ExecutionStatus& status) {
  nlohmann::json history = nlohmann::json::array();
  for (const auto& entry : status.history) {
    history.push_back(nlohmann::json{
        {"from_status", entry.from_status},
        {"to_status", entry.to_status},
        {"occurred_at", entry.occurred_at},
        {"message", entry.message},
    });
  }

  return nlohmann::json{
      {"id", status.job.id},
      {"status", to_string(status.job.status)},
      {"started_at", status.job.started_at.has_value() ? nlohmann::json(*status.job.started_at) : nullptr},
      {"completed_at", status.job.completed_at.has_value() ? nlohmann::json(*status.job.completed_at) : nullptr},
      {"error_message",
       status.job.error_message.has_value() ? nlohmann::json(*status.job.error_message) : nullptr},
      {"history", history},
  };
}

}  // namespace oep::acquisition::acquisition
