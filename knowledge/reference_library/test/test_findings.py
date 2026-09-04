from oep_reference_core.findings import Finding, Severity, ValidationReport


def test_severity_rank_orders_info_below_warning_below_error():
    assert Severity.INFO.rank < Severity.WARNING.rank < Severity.ERROR.rank


def test_validation_report_passed_is_true_with_zero_errors():
    report = ValidationReport(
        findings=[
            Finding(Severity.WARNING, "w1", "a warning", "loc"),
            Finding(Severity.INFO, "i1", "an info", "loc"),
        ]
    )
    assert report.passed is True
    assert len(report.errors) == 0
    assert len(report.warnings) == 1
    assert len(report.infos) == 1


def test_validation_report_passed_is_false_with_any_error():
    report = ValidationReport(findings=[Finding(Severity.ERROR, "e1", "an error", "loc")])
    assert report.passed is False


def test_to_dict_summary_counts_are_correct():
    report = ValidationReport(
        findings=[
            Finding(Severity.ERROR, "e1", "e", "a"),
            Finding(Severity.ERROR, "e2", "e", "b"),
            Finding(Severity.WARNING, "w1", "w", "c"),
        ]
    )
    data = report.to_dict()
    assert data["passed"] is False
    assert data["summary"] == {"errors": 2, "warnings": 1, "infos": 0, "total": 3}
    assert len(data["findings"]) == 3


def test_to_json_is_deterministic_across_calls():
    report = ValidationReport(
        findings=[
            Finding(Severity.ERROR, "z_code", "message", "z_location"),
            Finding(Severity.WARNING, "a_code", "message", "a_location"),
        ]
    )
    assert report.to_json() == report.to_json()


def test_to_json_sorts_findings_by_location_then_code_regardless_of_insertion_order():
    report_a = ValidationReport(
        findings=[
            Finding(Severity.ERROR, "z_code", "m", "b_location"),
            Finding(Severity.ERROR, "a_code", "m", "a_location"),
        ]
    )
    report_b = ValidationReport(
        findings=[
            Finding(Severity.ERROR, "a_code", "m", "a_location"),
            Finding(Severity.ERROR, "z_code", "m", "b_location"),
        ]
    )
    assert report_a.to_json() == report_b.to_json()


def test_merged_combines_findings_from_both_reports():
    report_a = ValidationReport(findings=[Finding(Severity.ERROR, "e1", "m", "a")])
    report_b = ValidationReport(findings=[Finding(Severity.WARNING, "w1", "m", "b")])
    merged = report_a.merged(report_b)
    assert len(merged.findings) == 2
    assert merged.passed is False


def test_finding_to_dict_shape():
    finding = Finding(Severity.ERROR, "some_code", "some message", "some/location")
    assert finding.to_dict() == {
        "severity": "error",
        "code": "some_code",
        "message": "some message",
        "location": "some/location",
    }
