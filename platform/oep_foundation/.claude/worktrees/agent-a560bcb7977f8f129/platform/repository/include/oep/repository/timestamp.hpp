#pragma once

#include <string>

namespace oep::repository {

// Returns the current UTC time as an ISO-8601 string, e.g. "2026-01-01T00:00:00Z".
std::string current_timestamp_utc();

} // namespace oep::repository
