"""Loads `schemas/*.schema.json` and validates instances fully offline.

Constitution Article VIII: "The Engineering Reference Library shall
remain fully functional without Internet access." Every `$ref` between
schemas resolves to a file already loaded into the local
:class:`referencing.Registry` -- there is no network retrieval
callback configured, so an unresolvable `$ref` fails loudly instead of
silently reaching out to the network.
"""

from __future__ import annotations

import json
from pathlib import Path

import jsonschema
from referencing import Registry, Resource


class SchemaRegistry:
    """A registry of every JSON Schema under one ``schemas/`` directory."""

    def __init__(self, schemas_dir: Path) -> None:
        self.schemas_dir = schemas_dir
        self._schemas: dict[str, dict] = {}
        resources: list[tuple[str, Resource]] = []
        for schema_path in sorted(schemas_dir.glob("*.schema.json")):
            with schema_path.open("r", encoding="utf-8") as handle:
                schema = json.load(handle)
            schema_id = schema.get("$id", schema_path.name)
            self._schemas[schema_path.stem.removesuffix(".schema")] = schema
            self._schemas[schema_path.name] = schema
            resources.append((schema_id, Resource.from_contents(schema)))
        self._registry: Registry = Registry().with_resources(resources)

    def schema(self, name: str) -> dict:
        """Returns the raw schema dict for a short name (e.g. ``"object"``) or filename."""
        try:
            return self._schemas[name]
        except KeyError as exc:
            raise KeyError(f"No schema named {name!r} in {self.schemas_dir}") from exc

    def validator_for(self, name: str) -> jsonschema.protocols.Validator:
        schema = self.schema(name)
        validator_cls = jsonschema.Draft202012Validator
        validator_cls.check_schema(schema)
        return validator_cls(schema, registry=self._registry)

    def iter_errors(self, instance: object, name: str) -> list[jsonschema.exceptions.ValidationError]:
        """Returns every schema-validation error for ``instance`` against schema ``name``.

        Sorted by JSON path so output is deterministic regardless of
        the underlying validator's internal traversal order.
        """
        validator = self.validator_for(name)
        errors = list(validator.iter_errors(instance))
        errors.sort(key=lambda e: [str(p) for p in e.absolute_path])
        return errors
