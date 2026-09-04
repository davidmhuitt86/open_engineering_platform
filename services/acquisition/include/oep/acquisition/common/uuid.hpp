#pragma once

#include <string>

namespace oep::acquisition::common {

/// True if `text` has the shape of a UUID (`8-4-4-4-12` hex digits).
/// Checked locally (rather than relying on PostgreSQL's `uuid` cast to
/// reject bad input) so a malformed `{id}` REST path segment resolves
/// deterministically to "not found" instead of surfacing a SQL error from
/// deep inside a Repository layer. Shared by
/// `registry::PostgresOfficialSourceRepository` and
/// `acquisition::PostgresAcquisitionJobRepository`.
[[nodiscard]] bool is_uuid_like(const std::string& text);

}  // namespace oep::acquisition::common
