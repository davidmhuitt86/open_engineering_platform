"""Builds the compiled `manifest.json` (SDD-R004 §8).

Every field is derived from the package's own source-controlled
``manifest.yaml`` plus counts computed from the loaded objects --
never from the wall clock at build time. This is what makes
ENGINE-TASK-000007's "running the compiler twice shall produce
identical package hashes" achievable: there is no `datetime.now()`
anywhere in this module. "Build Date" is the package author's own
pinned ``release_date``, exactly as they set it when they decided to
release this version (SDD-R004 §4 "Release Date" is package identity
metadata, not a compiler timestamp).
"""

from __future__ import annotations

from oep_reference_core.package_source import PackageSource

COMPILER_VERSION = "0.1.0"


def build_manifest(package: PackageSource) -> dict:
    manifest = package.manifest
    object_count = len(package.objects)
    relationship_count = sum(len(obj.relationships or []) for obj in package.objects)
    asset_count = sum(
        len((obj.object.get("visualization") or {}).get("assets") or []) for obj in package.objects
    )

    return {
        "package_name": manifest["display_name"],
        "package_id": manifest["package_id"],
        "version": manifest["version"],
        "publisher": manifest["publisher"],
        "package_type": manifest["package_type"],
        "language": manifest.get("language", "en"),
        "license": manifest["license"],
        "dependencies": manifest.get("dependencies", []),
        "minimum_oep_version": manifest.get("minimum_oep_version"),
        "target_domains": manifest.get("target_domains", []),
        "object_count": object_count,
        "relationship_count": relationship_count,
        "asset_count": asset_count,
        "build_date": manifest["release_date"],
        "compiler_version": COMPILER_VERSION,
    }
