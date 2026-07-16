# Schema Reference

The nine JSON Schemas under `schemas/` (ENGINE-TASK-000002), what each
one validates, and the interpretive decisions made where SDD-R001/
R002/R003/R010 left the exact authoring-file split underspecified.

All schemas are Draft 2020-12, loaded and resolved entirely offline by
`oep_reference_core.schema_registry.SchemaRegistry` -- `$ref` between
schemas resolves only against files already loaded from `schemas/`,
never over the network (Constitution Article VIII).

## The eight schemas, and which file each validates

| Schema | Validates | Notes |
|---|---|---|
| `object.schema.json` | `object.yaml` | Identity, Classification (`$ref`), Description, Search Metadata, AI Context, Simulation, Visualization, Provenance (`$ref`), Version Information |
| `classification.schema.json` | `object.yaml`'s `classification` section | SDD-R002's full model, with Tags/Keywords/Aliases folded in from SDD-R001 §7 |
| `properties.schema.json` | `properties.yaml` | SDD-R001 §9 |
| `relationships.schema.json` | `relationships.yaml` | SDD-R003, `provenance` embedded via `$ref` |
| `behaviors.schema.json` | `behaviors.yaml` | SDD-R001 §11/§12, SDD-R005 -- declarative metadata only |
| `validation.schema.json` | `validation.yaml` | SDD-R001 §13 |
| `education.schema.json` | `education.yaml` | SDD-R001 §18 |
| `provenance.schema.json` | embedded in `object.yaml` and each `relationships.yaml` entry | SDD-R001 §21, SDD-R003 §13 |
| `package_manifest.schema.json` | `packages/<package>/manifest.yaml` | SDD-R004 §4. Not one of ENGINE-TASK-000002's seven named schemas -- see "Deviations" below |

## Deviations from a literal reading of the source documents

Several places where the specifications don't fully agree, or leave a
gap, required a judgment call. Each is recorded here rather than
resolved silently.

**`properties` is an eighth schema, not one of ENGINE-TASK-000002's
seven named ones.** The work package's schema list (object,
classification, relationships, behaviors, validation, education,
provenance) omits Engineering Properties. SDD-R010 §6's own example
object layout, however, explicitly lists `properties.yaml` as a sibling
file alongside `relationships.yaml`/`behaviors.yaml`/etc., and
SDD-R001 §9 requires every property to carry a specific typed shape
(Name, Value Type, Units, Default, Range, Required, Read Only) that
deserves real schema enforcement. Since ENGINE-TASK-000005 also
requires "every section defined by SDD-R001... No shortcuts," treating
the work package's list as non-exhaustive and adding `properties.schema.json`
follows the stricter of the two instructions rather than silently
dropping property validation.

**`classification` and `provenance` are sections inside `object.yaml`,
not separate physical files.** SDD-R010 §6's example object layout
does not list a `classification.yaml` or `provenance.yaml` file, and
SDD-R001 §5's own canonical structure treats Classification and
Provenance as sections of one Engineering Knowledge Object, not
independent artifacts. They get their own schema files (for reuse --
`provenance.schema.json` is `$ref`'d from both `object.schema.json` and
`relationships.schema.json`) without becoming separate authoring files.

**`identity.status` is the single authoritative lifecycle field;
`classification` has no separate `lifecycle` field.** SDD-R001 §6
requires Identity to carry a `Status` field; SDD-R002 §10 separately
lists "Lifecycle" as one of many classification dimensions, using the
same value set SDD-R008 §4 defines. Carrying the same fact in two
places would violate Constitution Article V ("Engineering Knowledge
Shall Never Be Duplicated"), so `identity.status` is authoritative and
`classification` does not repeat it.

**`visualization` holds direct asset files, not a second copy of
symbol linkage.** SDD-R001 §20 lists "IEC Symbol" as an example
visualization resource, but SDD-R001 §15 already models a Component's
relationship to its symbol as a `REPRESENTED_BY` relationship (e.g.
`component.passive.resistor` -> `symbol.iec.resistor`). Repeating that
same link as a second, redundant field on `object.yaml` would again
violate Article V. `visualization` therefore holds only assets this
object *directly owns* (`icon`, `preview_image`, `three_d_model`,
`footprint`, plus a generic `assets` list) -- linkage to a *separate*
Symbol EKO is always a relationship.

**A property's `units` field is either a plain unit symbol or an
Object ID, and the validator tells them apart heuristically.** SDD-R010
§10 requires cross-references to use Object IDs, but WORK_PACKAGE_001
compiles exactly five objects and only one of them (`unit.volt`) is a
Unit. Properties whose true unit isn't among the five gold objects
(e.g. a resistor's `resistance`, properly measured in ohms) use a
plain string symbol (`"Ω"`) instead of inventing a sixth object purely
to satisfy a cross-reference. `validator.checks.check_broken_references`
recognizes a `units` value that matches the Object ID pattern
(dotted, lowercase) and treats only *those* as references requiring
resolution -- a plain symbol like `"Ω"` or `"W"` never triggers a
reference check. See `docs/GOLD_STANDARD_OBJECTS.md` for the resulting
`unit.volt`-only cross-references in the gold objects themselves.

## Extensible vocabularies live in code, not in the schemas

Object Types, Relationship Types/Categories, and Behavior Types are
all constitutionally extensible (SDD-R001 §24, SDD-R003 §21, SDD-R005
§20). None of the corresponding schema fields uses a JSON Schema
`enum` to restrict them -- doing so would hard-reject a legitimate
future extension. Instead they're free-form strings at the schema
layer, checked against `tools/oep_reference_core/constants.py`'s
initial lists by the validator's semantic checks, which only ever
produce a **warning** for an unrecognized value (`docs/AUTHORING_GUIDE.md`).
Fields with a genuinely closed, stable set of values (`review_status`,
`severity`, `value_type`, `multiplicity`) do use JSON Schema `enum`,
since those lists are not declared extensible anywhere.
