#include "oep/validation/validation_result.hpp"

namespace oep::validation {

std::string to_string(Severity severity) {
    switch (severity) {
        case Severity::Information: return "Information";
        case Severity::Warning: return "Warning";
        case Severity::Error: return "Error";
    }
    return "Information";
}

std::string to_string(RepositoryStatus status) {
    switch (status) {
        case RepositoryStatus::Healthy: return "Healthy";
        case RepositoryStatus::Unhealthy: return "Unhealthy";
    }
    return "Healthy";
}

ValidationReport generate_validation_report(std::vector<ValidationFinding> findings) {
    ValidationReport report;
    report.findings = std::move(findings);

    for (const ValidationFinding& finding : report.findings) {
        switch (finding.severity) {
            case Severity::Error: ++report.error_count; break;
            case Severity::Warning: ++report.warning_count; break;
            case Severity::Information: ++report.information_count; break;
        }
    }

    report.status = report.error_count == 0 ? RepositoryStatus::Healthy : RepositoryStatus::Unhealthy;
    return report;
}

} // namespace oep::validation
