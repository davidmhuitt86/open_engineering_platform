"""Deterministic YAML loading for Engineering Knowledge Object authoring files.

SDD-R010 §7: "Authoring files shall use YAML." Loading always uses
``yaml.safe_load`` -- authoring files are never trusted enough to
permit arbitrary Python object construction (a corrupted or malicious
contribution must never be able to execute code merely by being
loaded).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml


class YamlLoadError(Exception):
    """Raised when a YAML authoring file cannot be parsed."""

    def __init__(self, path: Path, reason: str) -> None:
        self.path = path
        self.reason = reason
        super().__init__(f"{path}: {reason}")


def load_yaml_file(path: Path) -> Any:
    """Loads and parses one YAML authoring file.

    Returns whatever structure the file contains (typically a ``dict``
    for a section file, or a ``list`` for ``relationships.yaml``).
    Raises :class:`YamlLoadError` on a missing file or malformed YAML
    -- never silently returns ``None`` or an empty structure for a
    parse failure, which would let a broken file masquerade as an
    empty one.
    """
    if not path.is_file():
        raise YamlLoadError(path, "file does not exist")
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise YamlLoadError(path, f"could not be read: {exc}") from exc
    try:
        return yaml.safe_load(text)
    except yaml.YAMLError as exc:
        raise YamlLoadError(path, f"invalid YAML: {exc}") from exc


def load_optional_yaml_file(path: Path) -> Any | None:
    """Like :func:`load_yaml_file`, but returns ``None`` for a missing file.

    Used for the optional per-object section files (``properties.yaml``,
    ``relationships.yaml``, ``behaviors.yaml``, ``validation.yaml``,
    ``education.yaml``) -- only ``object.yaml`` itself is mandatory.
    """
    if not path.is_file():
        return None
    return load_yaml_file(path)
