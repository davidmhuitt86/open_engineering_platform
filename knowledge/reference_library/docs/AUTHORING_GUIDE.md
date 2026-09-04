# Authoring Guide

How to author a new Engineering Knowledge Object (EKO) under
`packages/`, and what the Reference Validator checks before the
Reference Compiler will build a package (SDD-R010, SDD-R011,
ENGINE-TASK-000003). Schema Version 1.0 (WORK_PACKAGE_002) -- see
`docs/SCHEMA_REFERENCE.md` for the full field-by-field reference and
`docs/SCHEMA_MIGRATION.md` if you're looking for a WORK_PACKAGE_001-era
field that moved or was renamed.

## One object, one directory, nine facets in `object.yaml`

Per SDD-R010 §6, every EKO lives in its own directory. SDD-R011's
Engineering Knowledge Facet model organizes what goes in each file --
see `docs/SCHEMA_REFERENCE.md` for why the facet-to-file mapping isn't
1:1:

```
packages/<package_id>/<object_id>/
  object.yaml          required -- Identity, Classification, Authority,
                        Evidence, Provenance, History, Simulation,
                        Visualization, Assets (nine facets, one file)
  properties.yaml       optional -- Properties (array)
  relationships.yaml     optional -- Relationships this object owns as
                        the source (array)
  behaviors.yaml         optional -- Behaviors (array, declarative
                        metadata only -- see SCHEMA_REFERENCE.md)
  validation.yaml         optional -- Validation Rules (array,
                        structured subject/operator/operand)
  education.yaml          optional -- Education (object -- consolidates
                        what used to be Description + AI Context +
                        Education)
  assets/                optional -- SVGs, images, etc. this object owns,
                        referenced from object.yaml's `assets` facet
```

`<object_id>` is a dotted, lowercase identifier (e.g.
`component.passive.resistor`) and is also the directory name. See
`packages/core_reference/` for five fully-authored examples --
`docs/GOLD_STANDARD_OBJECTS.md` walks through them.

## Property IDs are permanent; display names are not

REFERENCE-TASK-000012: every property has a `property_id` (permanent,
snake_case, never renamed once published) and a `display_name` (may
change freely). Never reuse a `property_id` for a different meaning,
and never treat `display_name` as an identifier anywhere.

## Units reference Unit Engineering Knowledge Objects, or document why not

Per REFERENCE-TASK-000011, a numeric property's unit should be
`unit_ref: unit.some_unit` -- an Object ID that must resolve to a
compiled Unit EKO. Only `unit.volt` exists among the five gold objects
today. For every other unit, use `unit_symbol_pending: "Ω"` (a plain
symbol string) instead -- this is the documented, correct choice when
no Unit EKO exists yet, not a shortcut to fix later. The validator
surfaces every `unit_symbol_pending` use as an **info** finding
(`check_pending_unit_exceptions`), never an error, so its use is always
visible in the validation report without blocking anything. Never set
both `unit_ref` and `unit_symbol_pending` on the same property.

## Cross-references are always by Object ID

Per SDD-R010 §10, never reference another object by filename or
relative path -- always by its `object_id` string (e.g.
`target: equation.ohms_law` in a `relationships.yaml` entry). The
compiler and validator resolve these strings against every object
across every package under `packages/`, not just the current one.

Asset *files* (SVGs, images) are the one exception -- referenced by a
path relative to the owning object's own `assets/` directory
(`object.yaml`'s `assets` facet, `{role, path, kind, description}`),
never by Object ID, since an asset is not itself an Engineering
Knowledge Object (SDD-R011 §14). `visualization.asset_roles` may
reference an entry from that same list *by role name*, not by path.

## Structured constraints, not free text

REFERENCE-TASK-000014: every constraint (on a property, a relationship,
a behavior, or a validation rule) is a structured
`{subject, operator, operand, description}` object
(`schemas/constraint.schema.json`), not a free-text sentence.
`operator` is one of `gt`/`gte`/`lt`/`lte`/`eq`/`neq` (compares
`subject` to `operand`) or `not_null`/`not_empty` (unary, ignores
`operand`). `description` may still explain the constraint in prose,
but it is never authoritative on its own (SDD-R011 §10). A `validation.yaml`
rule is this same shape plus `rule_id` and `severity`.

If a constraint genuinely can't be expressed this way (a cross-property
comparison, or a per-element predicate over a list input), don't force
it into the shape -- record it as a free-text `note` in the relevant
behavior's `execution_metadata` instead, exactly as
`component.passive.resistor.calculate_power` does for "the computed
result shall not exceed this object's own `power_rating` property."

## A package needs a manifest too

`packages/<package_id>/manifest.yaml` declares the package's own
identity (SDD-R004 §4) -- see `schemas/package_manifest.schema.json`
and `packages/core_reference/manifest.yaml` for a real example. Set
`release_date` to the date you are actually releasing this version;
never leave it to be filled in "at build time" -- see
`docs/REFERENCE_COMPILER.md`'s determinism section for why. Bump the
package's `version` major component when a schema migration like this
one changes what's authoritative for existing objects (`0.1.0` ->
`1.0.0` for this exact migration, producing `core_reference_v1.oerp`).

## Running the validator

```
pip install -e .[dev]
oep-validate
```

Prints a deterministic JSON report and exits non-zero if any check
reports an **error** (warnings and infos never block). The checks
(ENGINE-TASK-000003, extended for the facet model in WORK_PACKAGE_002):

| Check | What it catches |
|---|---|
| Schema validity | Every YAML file against its JSON Schema (`schemas/*.schema.json`) |
| Required fields | Cross-field requirements the schema alone can't express -- e.g. `lifecycle_state: Published` requires a `provenance.reviewer` (SDD-R008 §13) |
| Duplicate ids | Two objects/relationships/behaviors/validation rules sharing an id anywhere under `packages/`; a `property_id` repeated *within one object's own* `properties.yaml` |
| Broken references | A relationship `target`, a behavior `depends_on` entry, an `authority_source_object`/`evidence_source_object`, or a property's `unit_ref` that doesn't resolve to a known `object_id` |
| Pending unit exceptions | Every `unit_symbol_pending` use, reported as **info** (never blocks) |
| Relationship integrity | Self-referential relationships (warning); `relationship_type` outside the SDD-R003 initial list (warning -- extensible, never an error) |
| Behavior references | A behavior with neither inputs nor outputs (warning) |
| Asset references | Every path in the `assets` facet must exist on disk under that object's own `assets/` directory; every `visualization.asset_roles` entry must match a real `assets` entry's `role` |

## Extensible vocabularies are warnings, not errors

Object Types and Relationship Types are explicitly declared extensible
by their governing SDDs (SDD-R001 §24, SDD-R003 §21). Using a value
outside `tools/oep_reference_core/constants.py`'s initial lists
produces a **warning**, never an error. Behavior Types, by contrast,
are a *closed* SDD-R011 §9 enum enforced directly by the JSON Schema --
see `docs/SCHEMA_REFERENCE.md` for the full closed-vs-extensible list.

## Validation must succeed before compilation

`oep-compile <package_id>` runs every check above across *every*
package under `packages/` before writing anything to `dist/` (SDD-R010
§11). A validation error anywhere aborts the build with the same JSON
report `oep-validate` would have printed.
