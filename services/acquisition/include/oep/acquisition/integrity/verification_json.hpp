#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/integrity/verification.hpp"

namespace oep::acquisition::integrity {

/// Full JSON representation used for `GET /verifications`,
/// `GET /verifications/{id}`, and `POST /verifications` responses.
[[nodiscard]] nlohmann::json to_json(const Verification& verification);

/// `GET /verifications/{id}/status` response body -- status/hash/timestamp
/// fields only, no download session details.
[[nodiscard]] nlohmann::json status_to_json(const Verification& verification);

}  // namespace oep::acquisition::integrity
