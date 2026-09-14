#pragma once

#include <optional>
#include <string>
#include <string_view>

// ADR-0002 SS3 / ADR-0006 SS12: the Server Repository reuses the exact
// same Reference Server bearer-token authentication contract EAM already
// implements -- ADR-0002 explicitly anticipated this ("designed so
// future Knowledge and Exchange APIs can use the same server boundary").
// This is a deliberate, independent duplication of
// `services/acquisition/include/oep/acquisition/api/auth.hpp`'s ~30
// lines (same contract, same algorithm), not a cross-service dependency
// -- ADR-0002 SS3 itself already establishes that a future service
// replicates the *contract*, not a shared binary, across independent
// services (EAM is C++, this is also C++, but they remain two separate,
// independently deployable processes with no link-time coupling).

namespace oep::server_repository::api {

[[nodiscard]] bool constant_time_equals(std::string_view a, std::string_view b) noexcept;

[[nodiscard]] std::optional<std::string> parse_bearer_token(const std::string& header_value);

}  // namespace oep::server_repository::api
