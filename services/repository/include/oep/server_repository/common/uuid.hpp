#pragma once

#include <string>

namespace oep::server_repository::common {

/// Validates that `text` is a canonical UUIDv4 string: correct textual
/// structure (36 characters, hyphens at positions 8/13/18/23, hex digits
/// elsewhere), version nibble `4`, and the RFC 4122 / RFC 9562 standard
/// variant (the two high bits of the variant nibble are `10`, i.e. the
/// variant nibble is one of `8`/`9`/`a`/`b`, case-insensitive).
///
/// WP-SRV-011C: ADR-0004/ADR-0006 establish UUIDv4 as the identity format
/// for every Server Repository resource and operation identity (whether
/// server-generated or client-supplied). This function is the single
/// point of truth for that contract -- every API-level identity field
/// (repository-creation `operation_id`, commit `operation_id`,
/// client-supplied `object_id`/`relationship_id`/source/target ids) and
/// every URL-path resource id passed into `persistence::ServerRepositoryStore`
/// is checked through it, so strengthening it here closes the gap
/// uniformly rather than needing to be duplicated at each call site.
[[nodiscard]] bool is_uuid_like(const std::string& text);

/// Generates a random UUIDv4 (server-generated repository_id, commit_id,
/// audit event_id -- ADR-0006 SS20/SS21).
[[nodiscard]] std::string generate_uuid_v4();

}  // namespace oep::server_repository::common
