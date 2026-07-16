"""The deterministic finding model shared by the validator and compiler.

The compiler runs the same validation the standalone validator does
before it will produce a package (SDD-R010 §11: "Validation must
succeed before compilation") -- both report findings using this one
model so their output is identical in shape.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class Severity(str, Enum):
    """Ordered from least to most severe for deterministic sorting."""

    INFO = "info"
    WARNING = "warning"
    ERROR = "error"

    @property
    def rank(self) -> int:
        return {Severity.INFO: 0, Severity.WARNING: 1, Severity.ERROR: 2}[self]


@dataclass(frozen=True, order=False)
class Finding:
    """One validation finding.

    ``location`` is a stable, human-readable path such as
    ``"core_reference/component.passive.resistor/relationships.yaml"``
    or ``"core_reference/component.passive.resistor#properties[2].name"``
    -- specific enough to fix the problem without re-running the
    validator in verbose mode.
    """

    severity: Severity
    code: str
    message: str
    location: str

    def sort_key(self) -> tuple:
        # Errors first is more useful for a human skimming the report,
        # but the *report itself* sorts errors last (see
        # ``ValidationReport.to_dict``) since "does it pass" reads
        # better with the summary above a scrollable finding list --
        # this key is for grouping/deduplication only, not the report's
        # printed order.
        return (self.location, self.code, self.severity.rank, self.message)

    def to_dict(self) -> dict:
        return {
            "severity": self.severity.value,
            "code": self.code,
            "message": self.message,
            "location": self.location,
        }


@dataclass
class ValidationReport:
    """A deterministic, serializable collection of findings.

    Deterministic means: given the same input source tree, two
    separate runs of the validator produce byte-identical JSON output
    from :meth:`to_json`. No wall-clock timestamp or non-deterministic
    ordering is included anywhere in the report.
    """

    findings: list[Finding]

    @property
    def errors(self) -> list[Finding]:
        return [f for f in self.findings if f.severity is Severity.ERROR]

    @property
    def warnings(self) -> list[Finding]:
        return [f for f in self.findings if f.severity is Severity.WARNING]

    @property
    def infos(self) -> list[Finding]:
        return [f for f in self.findings if f.severity is Severity.INFO]

    @property
    def passed(self) -> bool:
        """Validation succeeds if there are zero errors.

        Warnings and info findings do not block compilation -- they
        exist to surface extensibility-respecting soft checks (e.g. an
        unrecognized-but-permitted relationship type) without treating
        legitimate extension as failure.
        """
        return len(self.errors) == 0

    def sorted_findings(self) -> list[Finding]:
        return sorted(self.findings, key=Finding.sort_key)

    def to_dict(self) -> dict:
        findings = self.sorted_findings()
        return {
            "passed": self.passed,
            "summary": {
                "errors": len(self.errors),
                "warnings": len(self.warnings),
                "infos": len(self.infos),
                "total": len(findings),
            },
            "findings": [f.to_dict() for f in findings],
        }

    def to_json(self) -> str:
        import json

        return json.dumps(self.to_dict(), indent=2, sort_keys=True) + "\n"

    def merged(self, other: "ValidationReport") -> "ValidationReport":
        return ValidationReport(findings=[*self.findings, *other.findings])
