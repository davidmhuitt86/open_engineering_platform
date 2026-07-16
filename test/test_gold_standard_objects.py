"""Regression coverage for the five gold-standard EKOs (ENGINE-TASK-000005/000006).

These tests guard the actual authored content under
``packages/core_reference/`` -- if a future edit breaks a relationship,
drops a required section, or reintroduces a duplicate id, one of these
fails before the compiler would even be asked to build a package.
"""

from oep_reference_core.package_source import discover_packages
from oep_reference_core.repo_paths import PACKAGES_DIR, SCHEMAS_DIR
from oep_reference_core.schema_registry import SchemaRegistry

from validator.checks import run_all_checks

EXPECTED_OBJECT_IDS = {
    "component.passive.resistor",
    "equation.ohms_law",
    "unit.volt",
    "symbol.iec.resistor",
    "material.copper",
}


def _core_reference_package():
    packages = discover_packages(PACKAGES_DIR)
    return next(p for p in packages if p.package_id == "core_reference")


def test_exactly_five_gold_standard_objects_exist():
    package = _core_reference_package()
    assert {obj.object_id for obj in package.objects} == EXPECTED_OBJECT_IDS


def test_every_gold_standard_object_has_every_sdd_r001_section_file():
    package = _core_reference_package()
    for obj in package.objects:
        assert obj.object is not None, obj.object_dir
        assert obj.properties is not None, f"{obj.object_id} missing properties.yaml"
        assert obj.relationships is not None, f"{obj.object_id} missing relationships.yaml"
        assert obj.behaviors is not None, f"{obj.object_id} missing behaviors.yaml"
        assert obj.validation is not None, f"{obj.object_id} missing validation.yaml"
        assert obj.education is not None, f"{obj.object_id} missing education.yaml"


def test_every_gold_standard_object_is_published_with_a_reviewer():
    package = _core_reference_package()
    for obj in package.objects:
        assert obj.object["identity"]["status"] == "Published"
        assert obj.object["provenance"]["reviewer"]


def test_the_full_package_validates_with_zero_errors_and_zero_warnings():
    registry = SchemaRegistry(SCHEMAS_DIR)
    packages = discover_packages(PACKAGES_DIR)
    report = run_all_checks(packages, registry)
    assert report.passed is True
    assert report.warnings == []


def test_required_relationships_from_engine_task_000006_are_present():
    package = _core_reference_package()
    by_id = {obj.object_id: obj for obj in package.objects}

    resistor_targets = {(r["type"], r["target"]) for r in by_id["component.passive.resistor"].relationships}
    assert ("USES_EQUATION", "equation.ohms_law") in resistor_targets
    assert ("HAS_UNIT", "unit.volt") in resistor_targets
    assert ("REPRESENTED_BY", "symbol.iec.resistor") in resistor_targets

    copper_targets = {(r["type"], r["target"]) for r in by_id["material.copper"].relationships}
    assert ("USED_BY", "component.passive.resistor") in copper_targets


def test_symbol_svg_asset_referenced_by_the_symbol_object_exists_on_disk():
    package = _core_reference_package()
    symbol = next(obj for obj in package.objects if obj.object_id == "symbol.iec.resistor")
    assets = symbol.object["visualization"]["assets"]
    assert assets, "expected at least one visualization asset"
    for asset in assets:
        assert (symbol.assets_dir / asset["path"]).is_file()
