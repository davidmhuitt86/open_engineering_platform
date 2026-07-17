#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/acquisition/acquisition_job.hpp"

namespace oep::acquisition::acquisition {

/// Full JSON representation used for REST API responses. `deleted_at` is
/// intentionally never serialized -- it is an internal soft-delete marker,
/// not part of the public Job Model (WORK_PACKAGE-003). `started_at`,
/// `completed_at`, and `error_message` serialize as JSON `null` when unset.
[[nodiscard]] nlohmann::json to_json(const AcquisitionJob& job);

}  // namespace oep::acquisition::acquisition
