#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/metadata/artifact_metadata.hpp"

namespace oep::acquisition::metadata {

/// Full JSON representation used for `GET /metadata`, `GET /metadata/{id}`,
/// and `POST /metadata` responses.
[[nodiscard]] nlohmann::json to_json(const ArtifactMetadata& metadata);

/// `GET /metadata/{id}/status` response body -- status/timestamp/error
/// fields only, no descriptive artifact details.
[[nodiscard]] nlohmann::json status_to_json(const ArtifactMetadata& metadata);

}  // namespace oep::acquisition::metadata
