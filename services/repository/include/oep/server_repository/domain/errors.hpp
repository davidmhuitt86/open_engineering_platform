#pragma once

#include <stdexcept>
#include <string>

// ADR-0006 SS13's error contract, as exception types the persistence/API
// layers throw and catch -- deliberately none of these carry a
// filesystem path, credential, or raw driver exception text in their
// `what()` (WP-SRV-005's own already-fixed leak class, reaffirmed here
// from the start rather than discovered later).

namespace oep::server_repository::domain {

/// `NOT_FOUND` -- a referenced repository/object/relationship/revision/
/// commit does not exist (or, per ADR-0006 SS11's probing-resistance
/// rule, the caller is not authorized to see it -- this first slice has
/// no finer-grained authorization than "authenticated," so that
/// distinction never actually arises yet, but the error category is the
/// same one that rule would use).
class NotFoundError : public std::runtime_error {
 public:
  explicit NotFoundError(const std::string& what) : std::runtime_error(what) {}
};

/// `VALIDATION_FAILED` -- a mutation is structurally/semantically
/// invalid (unknown relationship endpoint, duplicate identity within a
/// create, malformed field). Never includes a filesystem path.
class ValidationError : public std::runtime_error {
 public:
  explicit ValidationError(const std::string& what) : std::runtime_error(what) {}
};

/// `CONCURRENCY_CONFLICT` -- a mutation's expected_revision does not
/// match the current revision (ADR-0004 SS10, ADR-0006 SS9).
class ConcurrencyConflictError : public std::runtime_error {
 public:
  explicit ConcurrencyConflictError(const std::string& what) : std::runtime_error(what) {}
};

/// `IDEMPOTENCY_CONFLICT` -- an operation identity (repository-creation
/// or commit) was already used with materially different content
/// (ADR-0006 SS9/SS21).
class IdempotencyConflictError : public std::runtime_error {
 public:
  explicit IdempotencyConflictError(const std::string& what) : std::runtime_error(what) {}
};

}  // namespace oep::server_repository::domain
