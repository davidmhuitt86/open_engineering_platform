"""Shared fixtures for building synthetic Engineering Knowledge Objects in tests."""

from __future__ import annotations

from pathlib import Path

import pytest

from oep_reference_core.package_source import ObjectSource, PackageSource


def _provenance(**overrides) -> dict:
    base = {
        "author": "tester",
        "created_date": "2026-01-01",
        "review_status": "Draft",
        "confidence": "low",
        "content_license": "CC-BY-4.0",
    }
    base.update(overrides)
    return base


def _object_yaml(object_id: str, *, status: str = "Published", reviewer: str | None = "someone") -> dict:
    return {
        "identity": {
            "object_id": object_id,
            "canonical_name": object_id.split(".")[-1],
            "display_name": object_id.split(".")[-1].title(),
            "object_type": "Component",
            "version": "1.0.0",
            "status": status,
        },
        "classification": {"domain": "Electrical", "category": "Test"},
        "description": {"short_definition": "x", "detailed_description": "y"},
        "provenance": _provenance(reviewer=reviewer),
        "version": {"major": 1, "minor": 0, "patch": 0},
        "visualization": {},
    }


def make_object_source(
    object_id: str,
    *,
    tmp_path: Path,
    dir_name: str | None = None,
    status: str = "Published",
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
        object=_object_yaml(object_id, status=status, reviewer=reviewer),
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
