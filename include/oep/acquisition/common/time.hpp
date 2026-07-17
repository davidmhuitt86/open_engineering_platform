#pragma once

#include <string>

namespace oep::acquisition::common {

/// The current time as `"YYYY-MM-DDTHH:MM:SSZ"` (UTC) -- matches the
/// format the Repository layer's SQL `to_char(..., 'YYYY-MM-DD"T"HH24:MI:SS"Z"')`
/// produces, so a timestamp set in C++ looks identical to one read back
/// from PostgreSQL. Shared by `acquisition::AcquisitionExecutionService`
/// and `connectors::StubConnector`.
[[nodiscard]] std::string current_timestamp_utc();

}  // namespace oep::acquisition::common
