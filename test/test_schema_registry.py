import pytest

from oep_reference_core.repo_paths import SCHEMAS_DIR
from oep_reference_core.schema_registry import SchemaRegistry


@pytest.fixture(scope="module")
def registry() -> SchemaRegistry:
    return SchemaRegistry(SCHEMAS_DIR)


@pytest.fixture(scope="module")
def valid_object() -> dict:
    return {
        "identity": {
            "object_id": "component.passive.resistor",
            "canonical_name": "resistor",
            "display_name": "Resistor",
            "object_type": "Component",
            "version": "1.0.0",
            "status": "Published",
        },
        "classification": {"domain": "Electrical", "category": "Resistors"},
        "description": {"short_definition": "x", "detailed_description": "y"},
        "provenance": {
            "author": "a",
            "created_date": "2026-01-01",
            "review_status": "Published",
            "confidence": "high",
            "content_license": "CC-BY-4.0",
        },
        "version": {"major": 1, "minor": 0, "patch": 0},
    }


def test_every_named_schema_loads(registry: SchemaRegistry):
    for name in (
        "object",
        "classification",
        "properties",
        "relationships",
        "behaviors",
        "validation",
        "education",
        "provenance",
        "package_manifest",
    ):
        assert registry.schema(name)["$id"] is not None


def test_unknown_schema_name_raises_key_error(registry: SchemaRegistry):
    with pytest.raises(KeyError):
        registry.schema("does_not_exist")


def test_valid_object_has_no_errors(registry: SchemaRegistry, valid_object: dict):
    assert registry.iter_errors(valid_object, "object") == []


def test_missing_required_identity_field_is_an_error(registry: SchemaRegistry, valid_object: dict):
    broken = {**valid_object, "identity": {k: v for k, v in valid_object["identity"].items() if k != "object_id"}}
    errors = registry.iter_errors(broken, "object")
    assert any("object_id" in e.message for e in errors)


def test_malformed_object_id_pattern_is_an_error(registry: SchemaRegistry, valid_object: dict):
    broken = {
        **valid_object,
        "identity": {**valid_object["identity"], "object_id": "Not A Valid Id!"},
    }
    errors = registry.iter_errors(broken, "object")
    assert len(errors) == 1
    assert "does not match" in errors[0].message


def test_unknown_status_enum_value_is_an_error(registry: SchemaRegistry, valid_object: dict):
    broken = {**valid_object, "identity": {**valid_object["identity"], "status": "NotARealStatus"}}
    errors = registry.iter_errors(broken, "object")
    assert len(errors) == 1


def test_classification_ref_resolves_and_requires_domain_and_category(
    registry: SchemaRegistry, valid_object: dict
):
    broken = {**valid_object, "classification": {"domain": "Electrical"}}
    errors = registry.iter_errors(broken, "object")
    assert any("category" in e.message for e in errors)


def test_provenance_ref_resolves_and_requires_content_license(registry: SchemaRegistry, valid_object: dict):
    broken_provenance = {k: v for k, v in valid_object["provenance"].items() if k != "content_license"}
    broken = {**valid_object, "provenance": broken_provenance}
    errors = registry.iter_errors(broken, "object")
    assert any("content_license" in e.message for e in errors)


def test_errors_are_sorted_by_path_deterministically(registry: SchemaRegistry, valid_object: dict):
    broken = {
        **valid_object,
        "identity": {k: v for k, v in valid_object["identity"].items() if k not in ("object_id", "version")},
    }
    errors_first = registry.iter_errors(broken, "object")
    errors_second = registry.iter_errors(broken, "object")
    assert [e.message for e in errors_first] == [e.message for e in errors_second]


def test_properties_schema_rejects_unknown_value_type(registry: SchemaRegistry):
    instance = [
        {
            "name": "resistance",
            "value_type": "not_a_real_type",
            "required": True,
            "read_only": False,
        }
    ]
    errors = registry.iter_errors(instance, "properties")
    assert len(errors) == 1


def test_relationships_schema_requires_provenance(registry: SchemaRegistry):
    instance = [{"relationship_id": "a.b.c", "type": "USES", "target": "x.y"}]
    errors = registry.iter_errors(instance, "relationships")
    assert any("provenance" in e.message for e in errors)
