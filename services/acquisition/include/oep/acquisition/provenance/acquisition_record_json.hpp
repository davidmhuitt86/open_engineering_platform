#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/provenance/acquisition_record.hpp"

namespace oep::acquisition::provenance {

/// Full JSON representation used for `GET /acquisition-records`,
/// `GET /acquisition-records/{id}`, and internal bookkeeping responses.
[[nodiscard]] nlohmann::json to_json(const AcquisitionRecord& record);

}  // namespace oep::acquisition::provenance
