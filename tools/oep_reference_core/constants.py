"""Canonical, extensible vocabularies defined by the SDDs.

Every list here is explicitly documented by its governing SDD as
*extensible* -- future work packages and Marketplace packages add to
these lists without modifying this module's own contract (SDD-R001
§24, SDD-R002 §20/21.8, SDD-R003 §21). Where the Reference Validator
checks a value against one of these lists, an unrecognized value is
reported as a warning, never an error -- rejecting outright would
contradict the constitutional extensibility rules these lists exist
to serve.
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

# SDD-R008 §4 -- Lifecycle States.
LIFECYCLE_STATES = frozenset(
    {
        "Draft",
        "Under Review",
        "Technically Verified",
        "Approved",
        "Published",
        "Deprecated",
        "Superseded",
        "Archived",
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

# SDD-R003 §9 -- Relationship Categories.
RELATIONSHIP_CATEGORIES = frozenset(
    {
        "Engineering",
        "Classification",
        "Simulation",
        "Validation",
        "Visualization",
        "Documentation",
        "AI",
        "Education",
        "Manufacturing",
        "Marketplace",
        "Repository",
        "Provenance",
    }
)

# SDD-R003 §14 -- Multiplicity.
MULTIPLICITIES = frozenset({"one_to_one", "one_to_many", "many_to_one", "many_to_many"})

# SDD-R005 §5 -- Behavior Types.
BEHAVIOR_TYPES = frozenset(
    {
        "Calculation",
        "Simulation",
        "Validation",
        "Transformation",
        "Measurement",
        "Recommendation",
        "Analysis",
        "Conversion",
        "Prediction",
        "Optimization",
        "Diagnostics",
        "Education",
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

# SDD-R002 §11 -- Authority.
AUTHORITY_LEVELS = frozenset(
    {
        "Core OEP",
        "Manufacturer",
        "Industry Standard",
        "Government",
        "Marketplace Package",
        "Community",
        "Private Repository",
    }
)

# SDD-R002 §12 -- Visibility.
VISIBILITY_LEVELS = frozenset({"Public", "Licensed", "Enterprise", "Marketplace", "Private", "Internal"})

# An Object ID is a dotted, lowercase, snake_case path, e.g.
# "component.passive.resistor" or "equation.ohms_law" (SDD-R001 §6
# example; SDD-R010 §10 "Objects reference other objects only by
# Object ID").
OBJECT_ID_PATTERN = r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$"

# A Relationship ID follows the same family of identifiers (SDD-R003
# §4: "Relationship identifiers shall be globally unique").
RELATIONSHIP_ID_PATTERN = r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$"
