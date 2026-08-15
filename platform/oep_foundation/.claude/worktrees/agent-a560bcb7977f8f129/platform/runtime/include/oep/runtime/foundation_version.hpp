#pragma once

namespace oep::runtime {

// The single canonical Foundation version string for this build.
// Referenced by the CLI (version command, generator, and anything
// constructing a FoundationRuntime) and by the Public C API's version
// reporting (OEP-SPEC-021 section 8), so both layers always agree on
// which Foundation version is running.
inline constexpr const char* kFoundationVersion = "0.1.0";

} // namespace oep::runtime
