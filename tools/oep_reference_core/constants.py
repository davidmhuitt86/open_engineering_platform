"""Canonical, extensible vocabularies defined by the SDDs.

Every list here is explicitly documented by its governing SDD as
*extensible* -- future work packages and Marketplace packages add to
these lists without modifying this module's own contract (SDD-R001
§24, SDD-R002 §20/21.8, SDD-R003 §21). Where the Reference Validator
checks a value against one of these lists, an unrecognized value is
reported as a warning, never an error -- rejecting outright would
contradict the constitutional extensibility rules these lists exist
to serve.

Vocabularies with a genuinely closed, stable set of values (lifecycle
states, cardinality, confidence, severity, the new SDD-R011 §9 behavior
types, and the new SDD-R011 §15/§16 authority/evidence types) are
enforced directly as JSON Schema `enum`s instead -- see
`schemas/identity.schema.json`, `schemas/relationships.schema.json`,
`schemas/behaviors.schema.json`, `schemas/authority.schema.json`, and
`schemas/evidence.schema.json`. They are not duplicated in this module.
"""

from __future__ import annotations

# SDD-R001 §4 -- Object Types.
OBJECT_TYPES = frozenset(
    {
        "Component",
        "Theory",
        "Equation",
        "Symbol",
        "Unit",
        "Material",
        "Connector",
        "Measurement",
        "Tool",
        "Standard",
        "Process",
        "Failure Mode",
        "Simulation Model",
        "Package",
        "Manufacturer",
        "Property Definition",
        "Engineering Method",
    }
)

# SDD-R003 §8 -- Relationship Types (initial set; extensible).
RELATIONSHIP_TYPES = frozenset(
    {
        "USES",
        "HAS_PROPERTY",
        "HAS_UNIT",
        "HAS_SYMBOL",
        "HAS_MODEL",
        "DEFINED_BY",
        "MEASURED_BY",
        "REPRESENTED_BY",
        "CONNECTED_TO",
        "DERIVED_FROM",
        "PART_OF",
        "CONTAINS",
        "IMPLEMENTS",
        "DEPENDS_ON",
        "REQUIRES",
        "PRODUCES",
        "CONSUMES",
        "CONTROLS",
        "PROTECTS",
        "MONITORS",
        "FAILS_AS",
        "SIMULATED_BY",
        "VALIDATED_BY",
        "REFERENCES",
        "RELATED_TO",
        "USES_EQUATION",
        "USED_BY",
    }
)

# SDD-R001 §12 -- Capabilities.
CAPABILITIES = frozenset(
    {
        "Searchable",
        "Renderable",
        "Simulatable",
        "Validatable",
        "Teachable",
        "Explainable",
        "Manufacturable",
        "Purchasable",
        "Exportable",
        "Printable",
        "AI Explainable",
        "Versionable",
        "Reviewable",
        "Indexable",
        "Translatable",
    }
)

# An Object ID is a dotted, lowercase, snake_case path, e.g.
# "component.passive.resistor" or "equation.ohms_law" (SDD-R001 §6
# example; SDD-R010 §10 "Objects reference other objects only by
# Object ID").
OBJECT_ID_PATTERN = r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$"

# A Relationship ID follows the same family of identifiers (SDD-R003
# §4: "Relationship identifiers shall be globally unique").
RELATIONSHIP_ID_PATTERN = r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$"

# A Property ID is a short, snake_case, object-local identifier
# (REFERENCE-TASK-000012) -- permanent once published, but not
# globally dotted like an Object ID since properties are only ever
# addressed through their owning object.
PROPERTY_ID_PATTERN = r"^[a-z][a-z0-9_]*$"
