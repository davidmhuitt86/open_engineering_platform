"""Locates repository-relative directories regardless of the caller's cwd."""

from __future__ import annotations

from pathlib import Path

# tools/oep_reference_core/repo_paths.py -> tools/oep_reference_core -> tools -> <repo root>
REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMAS_DIR = REPO_ROOT / "schemas"
PACKAGES_DIR = REPO_ROOT / "packages"
DIST_DIR = REPO_ROOT / "dist"
