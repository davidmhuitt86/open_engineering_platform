from pathlib import Path

import pytest

from oep_reference_core.findings import Severity
from oep_reference_core.package_source import ObjectSource, PackageSource
from oep_reference_core.repo_paths import SCHEMAS_DIR
from oep_reference_core.schema_registry import SchemaRegistry

from validator.checks import (
    check_asset_references,
    check_behavior_references,
    check_broken_references,
    check_duplicate_ids,
    check_pending_unit_exceptions,
    check_relationship_integrity,
    check_required_semantic_fields,
    check_schema_validity,
    run_all_checks,
)


def _provenance(**overrides) -> dict:
    base = {
        "author": "tester",
        "organization": "Test Org",
        "created_date": "2026-01-01",
        "confidence": "low",
        "content_license": "CC-BY-4.0",
    }
    base.update(overrides)
    return base


def _object_yaml(object_id: str, *, lifecycle_state: str = "Draft", reviewer: str | None = None) -> dict:
    return {
        "identity": {
            "object_id": object_id,
            "object_type": "Component",
            "display_name": object_id,
            "short_name": object_id.split(".")[-1],
            "version": "1.0.0",
            "lifecycle_state": lifecycle_state,
            "package_id": "test_package",
            "uuid": "00000000-0000-0000-0000-000000000001",
        },
        "classification": {"domain": "Electrical", "category": "Test"},
        "authority": {
            "authority_type": "Internal Engineering Authority",
            "authority_reference": "Synthesized for testing.",
        },
        "evidence": [],
        "provenance": _provenance(reviewer=reviewer) if reviewer else _provenance(),
        "history": {"lifecycle_events": [{"state": lifecycle_state, "date": "2026-01-01"}]},
        "simulation": {},
        "visualization": {},
        "assets": [],
    }


def _object_source(
    object_id: str,
    *,
    dir_name: str | None = None,
    lifecycle_state: str = "Draft",
    reviewer: str | None = None,
    relationships: list | None = None,
    behaviors: list | None = None,
    validation: list | None = None,
    properties: list | None = None,
    tmp_path: Path | None = None,
) -> ObjectSource:
    object_dir = (tmp_path or Path("/tmp")) / (dir_name or object_id)
    return ObjectSource(
        object_dir=object_dir,
        object=_object_yaml(object_id, lifecycle_state=lifecycle_state, reviewer=reviewer),
        properties=properties,
        relationships=relationships,
        behaviors=behaviors,
        validation=validation,
        education=None,
    )


def _package(objects: list[ObjectSource], *, package_id: str = "test_package", tmp_path: Path | None = None):
    return PackageSource(
        package_dir=(tmp_path or Path("/tmp")) / package_id,
        manifest={"package_id": package_id, "display_name": "Test", "publisher": "t"},
        objects=objects,
    )


@pytest.fixture(scope="module")
def registry() -> SchemaRegistry:
    return SchemaRegistry(SCHEMAS_DIR)


def test_check_required_semantic_fields_flags_published_object_without_reviewer(tmp_path):
    obj = _object_source("component.passive.a", lifecycle_state="Published", tmp_path=tmp_path)
    findings = check_required_semantic_fields([_package([obj], tmp_path=tmp_path)])
    assert len(findings) == 1
    assert findings[0].severity is Severity.ERROR
    assert findings[0].code == "missing_required_field"


def test_check_required_semantic_fields_passes_published_object_with_reviewer(tmp_path):
    obj = _object_source(
        "component.passive.a", lifecycle_state="Published", reviewer="someone", tmp_path=tmp_path
    )
    findings = check_required_semantic_fields([_package([obj], tmp_path=tmp_path)])
    assert findings == []


def test_check_required_semantic_fields_does_not_flag_draft_objects(tmp_path):
    obj = _object_source("component.passive.a", lifecycle_state="Draft", tmp_path=tmp_path)
    findings = check_required_semantic_fields([_package([obj], tmp_path=tmp_path)])
    assert findings == []


def test_check_duplicate_ids_flags_repeated_object_id(tmp_path):
    obj_a = _object_source("component.passive.a", dir_name="dir_a", tmp_path=tmp_path)
    obj_b = _object_source("component.passive.a", dir_name="dir_b", tmp_path=tmp_path)
    findings = check_duplicate_ids([_package([obj_a, obj_b], tmp_path=tmp_path)])
    assert len(findings) == 1
    assert findings[0].code == "duplicate_object_id"


def test_check_duplicate_ids_flags_repeated_relationship_id(tmp_path):
    rel = {"relationship_id": "a.b.c", "relationship_type": "USES", "target": "x.y"}
    obj_a = _object_source("a.first", dir_name="first", relationships=[rel], tmp_path=tmp_path)
    obj_b = _object_source("a.second", dir_name="second", relationships=[rel], tmp_path=tmp_path)
    findings = check_duplicate_ids([_package([obj_a, obj_b], tmp_path=tmp_path)])
    assert any(f.code == "duplicate_relationship_id" for f in findings)


def test_check_duplicate_ids_flags_repeated_property_id_within_one_object(tmp_path):
    props = [
        {"property_id": "resistance", "value_type": "number", "required": True, "read_only": False},
        {"property_id": "resistance", "value_type": "number", "required": True, "read_only": False},
    ]
    obj = _object_source("a.first", properties=props, tmp_path=tmp_path)
    findings = check_duplicate_ids([_package([obj], tmp_path=tmp_path)])
    assert any(f.code == "duplicate_property_id" for f in findings)


def test_check_duplicate_ids_allows_same_property_id_across_different_objects(tmp_path):
    props = [{"property_id": "resistance", "value_type": "number", "required": True, "read_only": False}]
    obj_a = _object_source("a.first", dir_name="first", properties=props, tmp_path=tmp_path)
    obj_b = _object_source("a.second", dir_name="second", properties=props, tmp_path=tmp_path)
    findings = check_duplicate_ids([_package([obj_a, obj_b], tmp_path=tmp_path)])
    assert findings == []


def test_check_duplicate_ids_passes_when_everything_unique(tmp_path):
    obj_a = _object_source("a.first", dir_name="first", tmp_path=tmp_path)
    obj_b = _object_source("a.second", dir_name="second", tmp_path=tmp_path)
    findings = check_duplicate_ids([_package([obj_a, obj_b], tmp_path=tmp_path)])
    assert findings == []


def test_check_broken_references_flags_unresolved_relationship_target(tmp_path):
    rel = {"relationship_id": "a.first.uses.ghost", "relationship_type": "USES", "target": "does.not.exist"}
    obj = _object_source("a.first", relationships=[rel], tmp_path=tmp_path)
    findings = check_broken_references([_package([obj], tmp_path=tmp_path)])
    assert len(findings) == 1
    assert findings[0].code == "broken_reference"


def test_check_broken_references_passes_when_target_resolves(tmp_path):
    rel = {"relationship_id": "a.first.uses.second", "relationship_type": "USES", "target": "a.second"}
    obj_a = _object_source("a.first", dir_name="first", relationships=[rel], tmp_path=tmp_path)
    obj_b = _object_source("a.second", dir_name="second", tmp_path=tmp_path)
    findings = check_broken_references([_package([obj_a, obj_b], tmp_path=tmp_path)])
    assert findings == []


def test_check_broken_references_flags_unresolved_behavior_dependency(tmp_path):
    behavior = {
        "behavior_id": "a.first.calc",
        "name": "Calc",
        "behavior_type": "Calculator",
        "depends_on": ["ghost.id"],
    }
    obj = _object_source("a.first", behaviors=[behavior], tmp_path=tmp_path)
    findings = check_broken_references([_package([obj], tmp_path=tmp_path)])
    assert len(findings) == 1


def test_check_broken_references_errors_on_unresolved_unit_ref(tmp_path):
    prop = {"property_id": "voltage", "unit_ref": "unit.does_not_exist", "value_type": "number"}
    obj = _object_source("a.first", properties=[prop], tmp_path=tmp_path)
    findings = check_broken_references([_package([obj], tmp_path=tmp_path)])
    assert len(findings) == 1
    assert findings[0].severity is Severity.ERROR
    assert findings[0].code == "broken_reference"


def test_check_broken_references_does_not_flag_pending_unit_symbol(tmp_path):
    prop = {"property_id": "resistance", "unit_symbol_pending": "Ω", "value_type": "number"}
    obj = _object_source("a.first", properties=[prop], tmp_path=tmp_path)
    findings = check_broken_references([_package([obj], tmp_path=tmp_path)])
    assert findings == []


def test_check_pending_unit_exceptions_reports_info_for_documented_pending_units(tmp_path):
    prop = {"property_id": "resistance", "unit_symbol_pending": "Ω", "value_type": "number"}
    obj = _object_source("a.first", properties=[prop], tmp_path=tmp_path)
    findings = check_pending_unit_exceptions([_package([obj], tmp_path=tmp_path)])
    assert len(findings) == 1
    assert findings[0].severity is Severity.INFO
    assert findings[0].code == "pending_unit_reference"


def test_check_relationship_integrity_warns_on_unknown_type(tmp_path):
    rel = {"relationship_id": "a.first.rel", "relationship_type": "TOTALLY_MADE_UP_TYPE", "target": "a.first"}
    obj = _object_source("a.first", relationships=[rel], tmp_path=tmp_path)
    findings = check_relationship_integrity([_package([obj], tmp_path=tmp_path)])
    codes = {f.code for f in findings}
    assert "unknown_relationship_type" in codes


def test_check_relationship_integrity_warns_on_self_reference(tmp_path):
    rel = {"relationship_id": "a.first.rel", "relationship_type": "USES", "target": "a.first"}
    obj = _object_source("a.first", relationships=[rel], tmp_path=tmp_path)
    findings = check_relationship_integrity([_package([obj], tmp_path=tmp_path)])
    codes = {f.code for f in findings}
    assert "self_referential_relationship" in codes


def test_check_relationship_integrity_accepts_known_type_without_warning(tmp_path):
    rel = {"relationship_id": "a.first.rel", "relationship_type": "USES_EQUATION", "target": "a.second"}
    obj = _object_source("a.first", relationships=[rel], tmp_path=tmp_path)
    findings = check_relationship_integrity([_package([obj], tmp_path=tmp_path)])
    assert findings == []


def test_check_behavior_references_warns_when_no_inputs_or_outputs(tmp_path):
    behavior = {"behavior_id": "a.first.calc", "name": "Calc", "behavior_type": "Calculator", "inputs": [], "outputs": []}
    obj = _object_source("a.first", behaviors=[behavior], tmp_path=tmp_path)
    findings = check_behavior_references([_package([obj], tmp_path=tmp_path)])
    assert any(f.code == "behavior_without_variables" for f in findings)


def test_check_behavior_references_accepts_a_well_formed_behavior_without_warning(tmp_path):
    behavior = {
        "behavior_id": "a.first.calc",
        "name": "Calc",
        "behavior_type": "Calculator",
        "inputs": [{"name": "x", "value_type": "number"}],
        "outputs": [],
    }
    obj = _object_source("a.first", behaviors=[behavior], tmp_path=tmp_path)
    findings = check_behavior_references([_package([obj], tmp_path=tmp_path)])
    assert findings == []


def test_check_asset_references_flags_missing_file(tmp_path):
    obj = _object_source("a.first", tmp_path=tmp_path)
    obj.object["assets"] = [{"role": "icon", "path": "missing_icon.svg", "kind": "svg"}]
    findings = check_asset_references([_package([obj], tmp_path=tmp_path)])
    assert len(findings) == 1
    assert findings[0].code == "missing_asset"


def test_check_asset_references_passes_when_asset_exists_on_disk(tmp_path):
    obj = _object_source("a.first", tmp_path=tmp_path)
    obj.object["assets"] = [{"role": "icon", "path": "present.svg", "kind": "svg"}]
    obj.assets_dir.mkdir(parents=True)
    (obj.assets_dir / "present.svg").write_text("<svg/>", encoding="utf-8")
    findings = check_asset_references([_package([obj], tmp_path=tmp_path)])
    assert findings == []


def test_check_asset_references_flags_broken_visualization_asset_role(tmp_path):
    obj = _object_source("a.first", tmp_path=tmp_path)
    obj.object["assets"] = []
    obj.object["visualization"] = {"asset_roles": ["icon"]}
    findings = check_asset_references([_package([obj], tmp_path=tmp_path)])
    assert any(f.code == "broken_reference" for f in findings)


def test_check_schema_validity_flags_invalid_manifest(registry, tmp_path):
    package = _package([], tmp_path=tmp_path)
    package.manifest = {"package_id": "x"}  # missing every other required field
    findings = check_schema_validity([package], registry)
    assert len(findings) > 0
    assert all(f.severity is Severity.ERROR for f in findings)


def test_check_schema_validity_passes_a_well_formed_object(registry, tmp_path):
    obj = _object_source("a.first", tmp_path=tmp_path)
    package = _package([obj], tmp_path=tmp_path)
    package.manifest = {
        "package_id": "test_package",
        "display_name": "Test",
        "publisher": "t",
        "version": "0.1.0",
        "release_date": "2026-01-01",
        "package_type": "Core Library",
        "license": "x",
    }
    findings = check_schema_validity([package], registry)
    assert findings == []


def test_run_all_checks_merges_every_check_into_one_report(registry, tmp_path):
    obj = _object_source("a.first", lifecycle_state="Published", tmp_path=tmp_path)  # missing reviewer -> 1 error
    package = _package([obj], tmp_path=tmp_path)
    package.manifest = {
        "package_id": "test_package",
        "display_name": "Test",
        "publisher": "t",
        "version": "0.1.0",
        "release_date": "2026-01-01",
        "package_type": "Core Library",
        "license": "x",
    }
    report = run_all_checks([package], registry)
    assert report.passed is False
    assert any(f.code == "missing_required_field" for f in report.findings)
