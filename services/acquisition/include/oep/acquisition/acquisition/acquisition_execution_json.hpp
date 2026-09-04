#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/acquisition/acquisition_execution.hpp"

namespace oep::acquisition::acquisition {

/// `GET /jobs/{id}/status` response body: the job's id/status/timing
/// fields plus its full execution history, ordered oldest first.
[[nodiscard]] nlohmann::json to_json(const ExecutionStatus& status);

}  // namespace oep::acquisition::acquisition
