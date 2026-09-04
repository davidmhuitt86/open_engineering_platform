"""The Reference Compiler pipeline (ENGINE-TASK-000004).

YAML authoring source -> validate -> resolve -> compiled `.oerp`.
Compiler only -- nothing here loads a compiled package back (that is
the Reference Runtime, out of scope for WORK_PACKAGE_001; see
``runtime/README.md``).
"""

from __future__ import annotations

import hashlib
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from oep_reference_core.findings import ValidationReport
from oep_reference_core.package_source import PackageSource, discover_packages
from oep_reference_core.repo_paths import DIST_DIR, PACKAGES_DIR, SCHEMAS_DIR
from oep_reference_core.schema_registry import SchemaRegistry

from compiler.archive import write_deterministic_zip
from compiler.database import build_database
from compiler.indexes import build_graph_index, build_search_index, write_json_index
from compiler.manifest import build_manifest
from compiler.runtime_export import build_runtime_export
from validator.checks import run_all_checks


class CompilationError(Exception):
    """Raised when validation fails and the compiler refuses to build a package."""

    def __init__(self, report: ValidationReport) -> None:
        self.report = report
        super().__init__(f"validation failed with {len(report.errors)} error(s); see report for detail")


@dataclass
class BuildResult:
    package_id: str
    output_path: Path
    sha256: str
    validation_report: ValidationReport


def _package_license_text(package: PackageSource) -> str:
    manifest = package.manifest
    return (
        f"{manifest['display_name']} ({manifest['package_id']})\n"
        f"Version {manifest['version']}\n"
        f"Published by {manifest['publisher']}.\n\n"
        f"License: {manifest['license']}\n"
    )


def _stage_package(package: PackageSource, staging_dir: Path) -> None:
    staging_dir.mkdir(parents=True, exist_ok=True)

    manifest = build_manifest(package)
    (staging_dir / "manifest.json").write_text(
        __import__("json").dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8"
    )

    build_database([package], staging_dir / "reference.db")
    write_json_index(build_search_index([package]), staging_dir / "search.idx")
    write_json_index(build_graph_index([package]), staging_dir / "graph.idx")
    write_json_index(build_runtime_export([package]), staging_dir / "runtime.json")

    assets_dir = staging_dir / "assets"
    for obj in package.objects:
        if obj.assets_dir.is_dir() and any(obj.assets_dir.iterdir()):
            destination = assets_dir / obj.object_dir.name
            shutil.copytree(obj.assets_dir, destination)

    localization_dir = staging_dir / "localization"
    localization_dir.mkdir(parents=True, exist_ok=True)
    (localization_dir / "README.txt").write_text(
        "No localized content is compiled into this package yet (SDD-R004 §13).\n",
        encoding="utf-8",
    )

    signature_dir = staging_dir / "signature"
    signature_dir.mkdir(parents=True, exist_ok=True)
    (signature_dir / "UNSIGNED").write_text(
        "This package is not digitally signed. Signing infrastructure (SDD-R004 §15) is "
        "out of scope for WORK_PACKAGE_001 and is deferred to a future work package.\n",
        encoding="utf-8",
    )

    license_dir = staging_dir / "license"
    license_dir.mkdir(parents=True, exist_ok=True)
    (license_dir / "LICENSE.txt").write_text(_package_license_text(package), encoding="utf-8")


def compile_package(
    package_id: str,
    *,
    packages_dir: Path = PACKAGES_DIR,
    schemas_dir: Path = SCHEMAS_DIR,
    output_dir: Path = DIST_DIR,
) -> BuildResult:
    """Validates and compiles one package into a deterministic `.oerp` file.

    Raises :class:`CompilationError` if validation reports any error
    (SDD-R010 §11: "Validation must succeed before compilation").
    Validation runs across *every* package under ``packages_dir``, not
    just the one being compiled, so a broken reference into a sibling
    package is still caught (SDD-R004 §14 dependency resolution).
    """
    registry = SchemaRegistry(schemas_dir)
    all_packages = discover_packages(packages_dir)
    report = run_all_checks(all_packages, registry)
    if not report.passed:
        raise CompilationError(report)

    target = next((p for p in all_packages if p.package_id == package_id), None)
    if target is None:
        raise ValueError(f"No package with package_id {package_id!r} found under {packages_dir}")

    output_dir.mkdir(parents=True, exist_ok=True)
    major_version = target.manifest["version"].split(".")[0]
    output_path = output_dir / f"{package_id}_v{major_version}.oerp"

    with tempfile.TemporaryDirectory(prefix="oerp-build-") as raw_staging_dir:
        staging_dir = Path(raw_staging_dir)
        _stage_package(target, staging_dir)
        write_deterministic_zip(staging_dir, output_path)

    sha256 = hashlib.sha256(output_path.read_bytes()).hexdigest()
    return BuildResult(
        package_id=package_id,
        output_path=output_path,
        sha256=sha256,
        validation_report=report,
    )
