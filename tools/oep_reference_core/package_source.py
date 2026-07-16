"""Discovers and loads authoring source: packages/<package>/<object>/*.yaml.

SDD-R010 §6: "Each Engineering Knowledge Object occupies its own
directory. One object. One directory." This module only loads raw
YAML structures (dicts/lists) -- schema validation and semantic
modeling happen in the layers above it (:mod:`validator.checks`,
:mod:`compiler.build`), keeping "read the source tree" a single,
shared, well-tested responsibility.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from .yaml_io import load_optional_yaml_file, load_yaml_file

SECTION_FILES = ("properties", "relationships", "behaviors", "validation", "education")


@dataclass
class ObjectSource:
    """One Engineering Knowledge Object's authoring files, freshly loaded."""

    object_dir: Path
    object: dict
    properties: list | None
    relationships: list | None
    behaviors: list | None
    validation: list | None
    education: dict | None

    @property
    def object_id(self) -> str | None:
        return (self.object.get("identity") or {}).get("object_id")

    @property
    def assets_dir(self) -> Path:
        return self.object_dir / "assets"

    def relative_location(self, package_id: str) -> str:
        return f"{package_id}/{self.object_dir.name}"


@dataclass
class PackageSource:
    """One authoring package: a manifest plus every object beneath it."""

    package_dir: Path
    manifest: dict
    objects: list[ObjectSource] = field(default_factory=list)

    @property
    def package_id(self) -> str | None:
        return self.manifest.get("package_id")


def load_object_source(object_dir: Path) -> ObjectSource:
    object_data = load_yaml_file(object_dir / "object.yaml")
    sections: dict[str, object] = {}
    for section in SECTION_FILES:
        sections[section] = load_optional_yaml_file(object_dir / f"{section}.yaml")
    return ObjectSource(
        object_dir=object_dir,
        object=object_data,
        properties=sections["properties"],
        relationships=sections["relationships"],
        behaviors=sections["behaviors"],
        validation=sections["validation"],
        education=sections["education"],
    )


def load_package_source(package_dir: Path) -> PackageSource:
    manifest = load_yaml_file(package_dir / "manifest.yaml")
    objects = []
    for child in sorted(package_dir.iterdir(), key=lambda p: p.name):
        if child.is_dir() and (child / "object.yaml").is_file():
            objects.append(load_object_source(child))
    return PackageSource(package_dir=package_dir, manifest=manifest, objects=objects)


def discover_packages(packages_root: Path) -> list[PackageSource]:
    """Loads every package directly under ``packages/`` that has a manifest.yaml."""
    packages = []
    for child in sorted(packages_root.iterdir(), key=lambda p: p.name):
        if child.is_dir() and (child / "manifest.yaml").is_file():
            packages.append(load_package_source(child))
    return packages
