#pragma once

#include <nlohmann/json.hpp>

#include "oep/acquisition/registry/official_source.hpp"

namespace oep::acquisition::registry {

/// Full JSON representation used for REST API responses. `deleted_at` is
/// intentionally never serialized -- it is an internal soft-delete marker,
/// not part of the public Source Model (WORK-PACKAGE-002).
[[nodiscard]] nlohmann::json to_json(const OfficialSource& source);

}  // namespace oep::acquisition::registry
