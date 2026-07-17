#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/downloads/download.hpp"

namespace oep::acquisition::downloads {

/// Full JSON representation used for `GET /downloads`, `GET /downloads/{id}`,
/// and `POST /downloads` responses.
[[nodiscard]] nlohmann::json to_json(const Download& download);

/// `GET /downloads/{id}/status` response body -- status/progress/timing
/// fields only, no source/connector/storage details.
[[nodiscard]] nlohmann::json status_to_json(const Download& download);

}  // namespace oep::acquisition::downloads
