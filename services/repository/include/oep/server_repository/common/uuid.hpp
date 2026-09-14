#pragma once

#include <string>

namespace oep::server_repository::common {

[[nodiscard]] bool is_uuid_like(const std::string& text);

/// Generates a random UUIDv4 (server-generated repository_id, commit_id,
/// audit event_id -- ADR-0006 SS20/SS21).
[[nodiscard]] std::string generate_uuid_v4();

}  // namespace oep::server_repository::common
