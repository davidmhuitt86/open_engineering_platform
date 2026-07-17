#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/vault/vault_entry.hpp"

namespace oep::acquisition::vault {

/// Full JSON representation used for `GET /vault`, `GET /vault/{id}`, and
/// `POST /vault` responses.
[[nodiscard]] nlohmann::json to_json(const VaultEntry& entry);

/// `GET /vault/{id}/status` response body -- status/hash/timing fields
/// only, no source/download/metadata linkage details.
[[nodiscard]] nlohmann::json status_to_json(const VaultEntry& entry);

}  // namespace oep::acquisition::vault
