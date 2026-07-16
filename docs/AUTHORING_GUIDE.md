# Authoring Guide

How to author a new Engineering Knowledge Object (EKO) under
`packages/`, and what the Reference Validator checks before the
Reference Compiler will build a package (SDD-R010, ENGINE-TASK-000003).

## One object, one directory

Per SDD-R010 §6, every EKO lives in its own directory, containing:

```
packages/<package_id>/<object_id>/
  object.yaml          required -- Identity, Classification, Description,
                        Search Metadata, AI Context, Simulation,
                        Visualization, Provenance, Version Information
  properties.yaml       optional -- Engineering Properties (array)
  relationships.yaml     optional -- Relationships this object owns as
                        the source (array)
  behaviors.yaml         optional -- Engineering Behaviors (array,
                        declarative metadata only -- see SCHEMA_REFERENCE.md)
  validation.yaml         optional -- Validation Rules (array)
  education.yaml          optional -- Educational Context (object)
  assets/                optional -- SVGs, images, etc. this object owns
```

`<object_id>` is a dotted, lowercase identifier (e.g.
`component.passive.resistor`) and is also the directory name. See
`packages/core_reference/` for five fully-authored examples --
`docs/GOLD_STANDARD_OBJECTS.md` walks through them.

## Cross-references are always by Object ID

Per SDD-R010 §10, never reference another object by filename or
relative path -- always by its `object_id` string (e.g.
`target: equation.ohms_law` in a `relationships.yaml` entry, or
`units: unit.volt` in a `properties.yaml` entry when a compiled Unit
EKO exists for that unit). The compiler and validator resolve these
strings against every object across every package under `packages/`,
not just the current one.

Asset *files* (SVGs, images) are the one exception -- those are
referenced by a path relative to the owning object's own `assets/`
directory (`object.yaml`'s `visualization.assets` field), never by
Object ID, since an asset is not itself an Engineering Knowledge
Object.

## A package needs a manifest too

`packages/<package_id>/manifest.yaml` declares the package's own
identity (SDD-R004 §4) -- see `schemas/package_manifest.schema.json`
and `packages/core_reference/manifest.yaml` for a real example. Set
`release_date` to the date you are actually releasing this version;
never leave it to be filled in "at build time" -- see
`docs/REFERENCE_COMPILER.md`'s determinism section for why.

## Running the validator

```
pip install -e .[dev]
oep-validate
```

Prints a deterministic JSON report and exits non-zero if any check
reports an **error** (warnings and infos never block). The seven
checks (ENGINE-TASK-000003):

| Check | What it catches |
|---|---|
| Schema validity | Every YAML file against its JSON Schema (`schemas/*.schema.json`) |
| Required fields | Cross-field requirements the schema alone can't express -- e.g. a `Published` object must have a `provenance.reviewer` (SDD-R008 §13) |
| Duplicate ids | Two objects, relationships, behaviors, or validation rules sharing an id, anywhere under `packages/` |
| Broken references | A relationship `target`, a behavior `depends_on` entry, or an object-id-shaped `units` value that doesn't resolve to a known `object_id` |
| Relationship integrity | Self-referential relationships (warning); relationship `type`/`category` outside the SDD-R003 initial lists (warning -- these lists are explicitly extensible, so an unrecognized value is never an error) |
| Behavior references | Behavior `type` outside the SDD-R005 initial list (warning); a behavior with neither inputs nor outputs (warning) |
| Asset references | Every path in `visualization` (icon, preview_image, three_d_model, footprint, or an `assets` entry) must exist on disk under that object's own `assets/` directory |

## Extensible vocabularies are warnings, not errors

Object Types, Relationship Types, Relationship Categories, and
Behavior Types are all explicitly declared extensible by their
governing SDDs (SDD-R001 §24, SDD-R003 §21, SDD-R005 §20). Using a
value outside `tools/oep_reference_core/constants.py`'s initial lists
produces a **warning**, never an error -- rejecting a legitimate
extension outright would contradict the SDDs that define these lists
as a starting point, not a closed set.

## Validation must succeed before compilation

`oep-compile <package_id>` runs every check above across *every*
package under `packages/` before writing anything to `dist/` (SDD-R010
§11). A validation error anywhere aborts the build with the same JSON
report `oep-validate` would have printed.
