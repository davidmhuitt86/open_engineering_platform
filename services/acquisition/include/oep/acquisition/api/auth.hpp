#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace oep::acquisition::api {

/// WP-SRV-003: compares two strings without short-circuiting on the first
/// mismatching byte, so the time taken does not reveal how many leading
/// bytes of an attacker-supplied token happened to match the real one.
/// Still returns `false` immediately if the lengths differ (in a bearer
/// token comparison, a length mismatch does not measurably narrow down the
/// authentication challenge either -- the token can validly be any of a
/// huge number of lengths).
[[nodiscard]] bool constant_time_equals(std::string_view a, std::string_view b) noexcept;

/// Extracts the token from an `Authorization: Bearer <token>` header value.
/// Returns `std::nullopt` for anything that is not exactly that shape: a
/// missing header (an empty `header_value`), a different scheme, no token
/// at all, or extra internal whitespace -- WP-SRV-003 Phase 3 requires a
/// missing header and a malformed header to fail authentication the same
/// way, so callers should treat every `std::nullopt` identically rather
/// than trying to distinguish "missing" from "malformed".
[[nodiscard]] std::optional<std::string> parse_bearer_token(const std::string& header_value);

}  // namespace oep::acquisition::api
