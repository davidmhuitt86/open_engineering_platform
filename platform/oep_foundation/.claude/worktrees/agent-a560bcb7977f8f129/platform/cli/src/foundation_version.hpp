#pragma once

#include "oep/runtime/foundation_version.hpp"

namespace oep::cli {

// Delegates to the single canonical definition in
// oep/runtime/foundation_version.hpp, shared with the Public C API
// (OEP-SPEC-021), so both layers always agree on which Foundation
// version is running.
inline constexpr const char* kFoundationVersion = oep::runtime::kFoundationVersion;

} // namespace oep::cli
