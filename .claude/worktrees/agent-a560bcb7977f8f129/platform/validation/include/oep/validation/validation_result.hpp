#pragma once

#include <string>
#include <vector>

namespace oep::validation {

// Severity levels, per OEP-SPEC-009-REPOSITORY_VALIDATION.
enum class Severity {
    Information,
    Warning,
    Error,
};

std::string to_string(Severity severity);

// A single integrity finding produced by RepositoryValidator.
struct ValidationFinding {
    Severity severity = Severity::Information;
    std::string category;
    std::string message;
    std::string object_id; // optional; empty when not applicable to a specific object
};

enum class RepositoryStatus {
    Healthy,
    Unhealthy,
};

std::string to_string(RepositoryStatus status);

// A deterministic summary of a repository's integrity, per
// OEP-SPEC-009-REPOSITORY_VALIDATION. A repository is Unhealthy if and
// only if at least one Error-severity finding was produced.
struct ValidationReport {
    RepositoryStatus status = RepositoryStatus::Healthy;
    int error_count = 0;
    int warning_count = 0;
    int information_count = 0;
    std::vector<ValidationFinding> findings;
};

// Aggregates `findings` into a report, computing status and counts.
// Findings are kept in the order given, which callers should make
// deterministic for a given repository state.
ValidationReport generate_validation_report(std::vector<ValidationFinding> findings);

} // namespace oep::validation
