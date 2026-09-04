"""Builds the precompiled `runtime.json` (AP-EK-020 Part A).

A deterministic, engine-facing view of the same authored object
documents already loaded into `reference.db` -- exactly the same
relationship this module bears to `search.idx`/`graph.idx`
(`compiler/indexes.py`): one more precomputed index inside the
package, serving one more consumer (the OEP Engineering Knowledge
Runtime, `platform/oep_engine/lib/core/knowledge/`), never a second
competing schema. The runtime never reads authoring YAML directly
(AP-EK-001); this is the file it reads instead.

Shape follows AP-EK-013 §16-25's registry contract: units, dimensions,
componentModels, laws, equations, constraints, provenance -- the same
fields `platform/oep_engine/lib/core/knowledge/models/knowledge_package.dart`'s
`KnowledgePackage.fromJson` expects.

Derivation rules (all deterministic, all traced back to already-
authored SDD-R011 facets -- nothing here is guessed):

- **Unit** objects (`identity.object_type == "Unit"`) become both a
  `unit` entry and (deduplicated by id) a `dimension` entry. The
  dimension's SI base-quantity exponents are parsed from the unit's
  own `si_base_expression` property (e.g. ``"kg*m^2*s^-3*A^-1"``) --
  see `_parse_si_base_expression`. The dimension id/name are derived
  from `classification.subcategory` (falling back to `category`),
  e.g. unit.volt's subcategory "Voltage" -> `dimension.voltage`.
- **Equation** objects become an `equation` entry. `expression` is the
  object's own `classification.aliases[0]` (the first authored
  alias is the convention this module treats as the canonical,
  human-readable form -- see the AP-EK-020 final report). `variables`/
  `dimensions` are derived from the object's own properties, each
  resolved to a dimension via its `unit_ref`. If the equation's own
  `authority.authority_type` is `"Physical Law"`, a matching `law`
  entry is also derived (id: `law.<suffix>` from `equation.<suffix>`),
  referencing the equation.
- **Component** objects become a `componentModel` entry. `parameters`
  are the object's own required properties that have a `unit_ref`
  (properties without one -- e.g. `package_style`, a string -- are not
  engineering-dimensioned inputs and are excluded). `equationRefs` are
  the object's own `USES_EQUATION` relationship targets.
  `constraintRefs`/`constraints` are the object's own `validation.yaml`
  rules whose `subject` names one of those parameters, with the rule's
  own dotted `rule_id` re-prefixed as `constraint.<local-name>` (the
  same short-id convention the vertical slice's solver already expects
  -- see `platform/oep_engine/lib/core/analysis/analysis_engine.dart`'s
  `ElectricalCoreIds`).
- **Terminal count** is the one property this module cannot derive
  from any existing SDD-R011 facet (no terminal facet exists yet in
  this schema) -- it is fixed by explicit, disclosed convention:
  `component.reference_node` gets one terminal (`ground`); every other
  Component gets two (`t1`/`t2`), matching every component the first
  vertical slice actually models. This is documented here rather than
  silently assumed.
"""

from __future__ import annotations

import re
from typing import Any

from oep_reference_core.package_source import ObjectSource, PackageSource

from compiler.manifest import COMPILER_VERSION

_SI_TERM_PATTERN = re.compile(r"([a-zA-Z]+)(\^(-?\d+))?")
_SI_BASE_KEYS = {"kg": "kg", "m": "m", "s": "s", "A": "a"}

_SLUG_PATTERN = re.compile(r"[^a-z0-9]+")


def _slug(value: str) -> str:
    return _SLUG_PATTERN.sub("_", value.strip().lower()).strip("_")


def _parse_si_base_expression(expression: str) -> dict[str, int]:
    """Parses e.g. ``"kg*m^2*s^-3*A^-1"`` into ``{"kg": 1, "m": 2, "s": -3, "a": -1}``.

    Only the four SI base quantities the first vertical slice's DC
    electrical dimensions need (kg, m, s, A) are recognised (AP-EK-020
    §4 non-goals) -- an unrecognised base symbol is a compiler error,
    not a silently-ignored term.
    """
    exponents = {"kg": 0, "m": 0, "s": 0, "a": 0}
    for match in _SI_TERM_PATTERN.finditer(expression):
        base, _, power = match.groups()
        if base not in _SI_BASE_KEYS:
            raise ValueError(f"Unrecognised SI base symbol {base!r} in si_base_expression {expression!r}.")
        exponents[_SI_BASE_KEYS[base]] += int(power) if power else 1
    return exponents


def _provenance_id(object_id: str) -> str:
    return f"prov.{object_id}"


def _build_provenance(package: PackageSource, obj: ObjectSource) -> dict[str, Any]:
    return {
        "id": _provenance_id(obj.object_id),
        "sourceObjectId": obj.object_id,
        "sourceReference": f"{obj.relative_location(package.package_id)}/object.yaml",
        "sourceKnowledgeVersion": f"{package.package_id}@{package.manifest['version']}",
        "compilerVersion": COMPILER_VERSION,
        "contentHash": None,
    }


def _build_units_and_dimensions(
    packages: list[PackageSource],
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    units: list[dict[str, Any]] = []
    dimensions: dict[str, dict[str, Any]] = {}

    for package in packages:
        for obj in sorted(package.objects, key=lambda o: o.object_id or ""):
            identity = obj.object["identity"]
            if identity["object_type"] != "Unit":
                continue
            classification = obj.object.get("classification") or {}
            properties = {p["property_id"]: p for p in (obj.properties or [])}

            symbol = properties["symbol"]["value"]
            si_base_expression = properties["si_base_expression"]["value"]
            scale = properties["conversion_factor_to_si"]["value"]
            exponents = _parse_si_base_expression(si_base_expression)

            dimension_name = classification.get("subcategory") or classification.get("category")
            dimension_id = f"dimension.{_slug(dimension_name)}"
            dimensions.setdefault(
                dimension_id,
                {"id": dimension_id, "name": dimension_name, "exponents": exponents},
            )

            aliases = sorted(
                set(classification.get("abbreviations") or []) | set(classification.get("aliases") or [])
            )
            units.append(
                {
                    "id": identity["object_id"],
                    "symbol": symbol,
                    "dimensionId": dimension_id,
                    "scaleToBase": scale,
                    "aliases": aliases,
                }
            )

    units.sort(key=lambda u: u["id"])
    return units, dimensions


_REFERENCE_NODE_TERMINALS = [{"id": "ground", "name": "Ground"}]
_TWO_TERMINAL = [{"id": "t1", "name": "Terminal 1"}, {"id": "t2", "name": "Terminal 2"}]


def _terminals_for(object_id: str) -> list[dict[str, str]]:
    # See the module docstring's "Terminal count" note -- not derivable
    # from any existing facet yet, so fixed by explicit convention.
    return _REFERENCE_NODE_TERMINALS if object_id == "component.reference_node" else _TWO_TERMINAL


def build_runtime_export(packages: list[PackageSource]) -> dict[str, Any]:
    """Deterministically derives the AP-EK-013 registry-shaped payload.

    Ordering: every returned list is sorted by its own `id` field, so
    equivalent authored content always produces byte-identical
    canonical JSON (AP-EK-013 §27), independent of filesystem
    traversal or dict-iteration order.
    """
    units, dimensions_by_id = _build_units_and_dimensions(packages)
    unit_by_id = {u["id"]: u for u in units}

    def dimension_id_for_property(prop: dict[str, Any]) -> str | None:
        unit_ref = prop.get("unit_ref")
        if unit_ref and unit_ref in unit_by_id:
            return unit_by_id[unit_ref]["dimensionId"]
        return None

    equations: list[dict[str, Any]] = []
    laws: list[dict[str, Any]] = []
    component_models: list[dict[str, Any]] = []
    constraints_by_id: dict[str, dict[str, Any]] = {}
    provenance: list[dict[str, Any]] = []

    for package in packages:
        for obj in sorted(package.objects, key=lambda o: o.object_id or ""):
            identity = obj.object["identity"]
            object_id = identity["object_id"]
            object_type = identity["object_type"]
            version = identity["version"]
            classification = obj.object.get("classification") or {}
            authority = obj.object.get("authority") or {}
            prov_id = _provenance_id(object_id)

            provenance.append(_build_provenance(package, obj))

            if object_type == "Equation":
                aliases = classification.get("aliases") or []
                expression = aliases[0] if aliases else identity["display_name"]
                props_sorted = sorted(obj.properties or [], key=lambda p: p["property_id"])
                variables = [p["property_id"] for p in props_sorted]
                dims = [d for d in (dimension_id_for_property(p) for p in props_sorted) if d]
                equations.append(
                    {
                        "id": object_id,
                        "version": version,
                        "expression": expression,
                        "variables": variables,
                        "dimensions": dims,
                        "applicability": "linear_dc",
                        "provenanceId": prov_id,
                    }
                )
                if authority.get("authority_type") == "Physical Law" and "." in object_id:
                    law_id = "law." + object_id.split(".", 1)[1]
                    laws.append(
                        {
                            "id": law_id,
                            "version": version,
                            "name": identity["display_name"],
                            "equationRefs": [object_id],
                            "applicability": "linear_dc",
                            "provenanceId": prov_id,
                        }
                    )

            elif object_type == "Component":
                parameters = []
                for prop in sorted(obj.properties or [], key=lambda p: p["property_id"]):
                    dim_id = dimension_id_for_property(prop)
                    if dim_id is None:
                        continue
                    parameters.append(
                        {
                            "name": prop["property_id"],
                            "dimensionId": dim_id,
                            "required": bool(prop.get("required", True)),
                        }
                    )
                param_names = {p["name"] for p in parameters}

                equation_refs = sorted(
                    {
                        rel["target"]
                        for rel in (obj.relationships or [])
                        if rel["relationship_type"] == "USES_EQUATION"
                    }
                )

                constraint_refs = []
                for rule in sorted(obj.validation or [], key=lambda r: r["rule_id"]):
                    if rule["subject"] not in param_names:
                        continue
                    local_name = rule["rule_id"]
                    prefix = f"{object_id}."
                    if local_name.startswith(prefix):
                        local_name = local_name[len(prefix) :]
                    constraint_id = f"constraint.{local_name}"
                    constraint_refs.append(constraint_id)
                    constraints_by_id[constraint_id] = {
                        "id": constraint_id,
                        "version": "1.0.0",
                        "type": "parameter_bound",
                        "subject": rule["subject"],
                        "operator": _OPERATOR_MAP[rule["operator"]],
                        "operand": rule["operand"],
                        "severity": rule["severity"],
                        "applicability": "linear_dc",
                        "provenanceId": prov_id,
                    }

                component_models.append(
                    {
                        "id": object_id,
                        "version": version,
                        "domain": classification.get("domain", "Electrical"),
                        "terminals": _terminals_for(object_id),
                        "parameters": parameters,
                        "equationRefs": equation_refs,
                        "constraintRefs": sorted(set(constraint_refs)),
                        "applicability": "linear_dc",
                        "provenanceId": prov_id,
                    }
                )

    equations.sort(key=lambda e: e["id"])
    laws.sort(key=lambda law: law["id"])
    component_models.sort(key=lambda m: m["id"])
    provenance.sort(key=lambda p: p["id"])
    dimensions = sorted(dimensions_by_id.values(), key=lambda d: d["id"])
    constraints = sorted(constraints_by_id.values(), key=lambda c: c["id"])

    return {
        # AP-EK-013 §5's Knowledge Package *schema* version -- the
        # contract this runtime.json payload conforms to, distinct from
        # SDD-R011's authoring-schema version (there is no single
        # SDD-R011 "schema_version" scalar to reuse here; see
        # compiler/manifest.py's build_manifest for the .oerp's own
        # separate, already-existing manifest.json identity fields).
        "schemaVersion": "1.0.0",
        "dimensions": dimensions,
        "units": units,
        "componentModels": component_models,
        "laws": laws,
        "equations": equations,
        "constraints": constraints,
        "provenance": provenance,
    }


_OPERATOR_MAP = {
    "gt": "greaterThan",
    "gte": "greaterThanOrEqual",
    "lt": "lessThan",
    "lte": "lessThanOrEqual",
    "eq": "equal",
    "neq": "notEqual",
}
