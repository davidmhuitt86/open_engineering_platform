"""Coverage for `compiler/runtime_export.py` (AP-EK-020 Part A).

`compile_package` already runs full schema/reference validation
(`validator.checks.run_all_checks`) *before* staging ever calls
`build_runtime_export` -- see `test_build.py`'s
`test_compile_package_refuses_to_build_when_validation_fails` and
`test_validator_checks.py` for "missing required object"/"invalid
provenance"/"malformed package" coverage at that layer. These tests
cover what is specific to this module: deriving the AP-EK-013
registry-shaped `runtime.json` payload from already-valid authored
content.
"""

import pytest

from oep_reference_core.package_source import discover_packages
from oep_reference_core.repo_paths import PACKAGES_DIR

from compiler.runtime_export import _parse_si_base_expression, build_runtime_export


def _core_reference_package():
    packages = discover_packages(PACKAGES_DIR)
    return next(p for p in packages if p.package_id == "core_reference")


def test_parses_si_base_expression_for_all_four_electrical_dimensions():
    assert _parse_si_base_expression("A") == {"kg": 0, "m": 0, "s": 0, "a": 1}
    assert _parse_si_base_expression("kg*m^2*s^-3*A^-1") == {"kg": 1, "m": 2, "s": -3, "a": -1}
    assert _parse_si_base_expression("kg*m^2*s^-3*A^-2") == {"kg": 1, "m": 2, "s": -3, "a": -2}
    assert _parse_si_base_expression("kg*m^2*s^-3") == {"kg": 1, "m": 2, "s": -3, "a": 0}


def test_invalid_unit_expression_raises_rather_than_silently_ignoring_the_term():
    with pytest.raises(ValueError, match="Unrecognised SI base symbol"):
        _parse_si_base_expression("kg*mol^1")


def test_build_runtime_export_derives_all_four_units_and_dimensions():
    export = build_runtime_export([_core_reference_package()])
    assert {u["id"] for u in export["units"]} == {"unit.volt", "unit.ampere", "unit.ohm", "unit.watt"}
    assert {d["id"] for d in export["dimensions"]} == {
        "dimension.voltage",
        "dimension.current",
        "dimension.resistance",
        "dimension.power",
    }
    volt = next(u for u in export["units"] if u["id"] == "unit.volt")
    assert volt["symbol"] == "V"
    assert volt["dimensionId"] == "dimension.voltage"
    assert volt["scaleToBase"] == 1.0


def test_build_runtime_export_derives_the_three_required_component_models():
    export = build_runtime_export([_core_reference_package()])
    ids = {m["id"] for m in export["componentModels"]}
    assert ids == {"component.passive.resistor", "component.reference_node", "component.source.voltage_ideal"}

    resistor = next(m for m in export["componentModels"] if m["id"] == "component.passive.resistor")
    assert {p["name"] for p in resistor["parameters"] if p["required"]} == {"resistance"}
    assert "equation.ohms_law" in resistor["equationRefs"]
    assert "constraint.resistance_positive" in resistor["constraintRefs"]

    reference_node = next(m for m in export["componentModels"] if m["id"] == "component.reference_node")
    assert reference_node["terminals"] == [{"id": "ground", "name": "Ground"}]

    voltage_source = next(m for m in export["componentModels"] if m["id"] == "component.source.voltage_ideal")
    assert {p["name"] for p in voltage_source["parameters"]} == {"voltage"}


def test_build_runtime_export_derives_ohms_law_and_power_equations_with_a_matching_law():
    export = build_runtime_export([_core_reference_package()])
    equation_ids = {e["id"] for e in export["equations"]}
    assert equation_ids == {"equation.ohms_law", "equation.power"}

    ohms_law_equation = next(e for e in export["equations"] if e["id"] == "equation.ohms_law")
    assert ohms_law_equation["expression"] == "V = I × R"

    ohms_law = next(law for law in export["laws"] if law["id"] == "law.ohms_law")
    assert ohms_law["equationRefs"] == ["equation.ohms_law"]


def test_build_runtime_export_derives_the_resistance_positive_constraint():
    export = build_runtime_export([_core_reference_package()])
    constraint = next(c for c in export["constraints"] if c["id"] == "constraint.resistance_positive")
    assert constraint["subject"] == "resistance"
    assert constraint["operator"] == "greaterThan"
    assert constraint["operand"] == 0
    assert constraint["severity"] == "error"


def test_build_runtime_export_provenance_covers_every_object():
    package = _core_reference_package()
    export = build_runtime_export([package])
    provenance_ids = {p["id"] for p in export["provenance"]}
    assert provenance_ids == {f"prov.{obj.object_id}" for obj in package.objects}


def test_build_runtime_export_is_deterministic_across_two_independent_calls():
    package = _core_reference_package()
    first = build_runtime_export([package])
    second = build_runtime_export([_core_reference_package()])
    assert first == second


def test_build_runtime_export_output_ordering_does_not_depend_on_input_order():
    package = _core_reference_package()
    forward = build_runtime_export([package])
    reversed_objects_package = package
    reversed_objects_package.objects = list(reversed(package.objects))
    backward = build_runtime_export([reversed_objects_package])
    assert forward == backward
