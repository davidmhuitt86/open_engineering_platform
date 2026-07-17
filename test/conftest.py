"""Shared fixtures for building synthetic Engineering Knowledge Objects in tests.

Builds the SDD-R011 facet-shaped ``object.yaml`` structure (WORK_PACKAGE_002)
-- see docs/SCHEMA_MIGRATION.md for the full field-by-field rationale.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from oep_reference_core.package_source import ObjectSource, PackageSource


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


def _object_yaml(
    object_id: str,
    *,
    lifecycle_state: str = "Published",
    reviewer: str | None = "someone",
) -> dict:
    short_name = object_id.split(".")[-1]
    return {
        "identity": {
            "object_id": object_id,
            "object_type": "Component",
            "display_name": short_name.title(),
            "short_name": short_name,
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
        "provenance": _provenance(reviewer=reviewer),
        "history": {"lifecycle_events": [{"state": lifecycle_state, "date": "2026-01-01"}]},
        "simulation": {},
        "visualization": {},
        "assets": [],
    }


def make_object_source(
    object_id: str,
    *,
    tmp_path: Path,
    dir_name: str | None = None,
    lifecycle_state: str = "Published",
    reviewer: str | None = "someone",
    relationships: list | None = None,
    behaviors: list | None = None,
    validation: list | None = None,
    properties: list | None = None,
    education: dict | None = None,
) -> ObjectSource:
    object_dir = tmp_path / (dir_name or object_id)
    return ObjectSource(
        object_dir=object_dir,
        object=_object_yaml(object_id, lifecycle_state=lifecycle_state, reviewer=reviewer),
        properties=properties,
        relationships=relationships,
        behaviors=behaviors,
        validation=validation,
        education=education,
    )


def make_package_source(
    objects: list[ObjectSource],
    *,
    tmp_path: Path,
    package_id: str = "test_package",
) -> PackageSource:
    return PackageSource(
        package_dir=tmp_path / package_id,
        manifest={
            "package_id": package_id,
            "display_name": "Test Package",
            "publisher": "Tester",
            "version": "0.1.0",
            "release_date": "2026-01-01",
            "package_type": "Core Library",
            "license": "Test License",
        },
        objects=objects,
    )


@pytest.fixture
def object_factory(tmp_path):
    def factory(object_id: str, **kwargs):
        return make_object_source(object_id, tmp_path=tmp_path, **kwargs)

    return factory


@pytest.fixture
def package_factory(tmp_path):
    def factory(objects, **kwargs):
        return make_package_source(objects, tmp_path=tmp_path, **kwargs)

    return factory
