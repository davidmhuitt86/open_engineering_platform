# Schema Reference

The seventeen JSON Schemas under `schemas/` implementing SDD-R011's
Engineering Knowledge Facet model (Schema Version 1.0, WORK_PACKAGE_002,
REFERENCE-TASK-000010/000017), what each one validates, and every
interpretive decision made where SDD-R011/R012 left the exact
authoring-file split underspecified. For what changed from
WORK_PACKAGE_001's schema and *why*, see `docs/SCHEMA_MIGRATION.md` --
this document describes the current, frozen shape only.

All schemas are Draft 2020-12, loaded and resolved entirely offline by
`oep_reference_core.schema_registry.SchemaRegistry` -- `$ref` between
schemas resolves only against files already loaded from `schemas/`,
never over the network (Constitution Article VIII).

## Facets are the architectural unit; files are not

SDD-R011 §2/§21: "An Engineering Knowledge Object is a structured
collection of ... Engineering Knowledge Facets. The file layout is an
implementation detail." Fourteen facets are canonical (SDD-R011 §4):
Identity, Classification, Properties, Relationships, Behaviors,
Validation, Education, Simulation, Visualization, Assets, Authority,
Evidence, Provenance, History. Every one of them has its own JSON
Schema file, `$ref`'d together -- but only five of the fourteen live in
their own physical YAML file (the array-heavy ones, unchanged from
WORK_PACKAGE_001's layout). The other nine live as top-level keys
inside one shared `object.yaml`. See `docs/SCHEMA_MIGRATION.md` §"Facets
map to files, but not one-for-one" for why.

## The seventeen schemas

| Schema | Validates | Facet(s) |
|---|---|---|
| `object.schema.json` | `object.yaml` | Composes Identity, Classification, Authority, Evidence, Provenance, History, Simulation, Visualization, Assets |
| `identity.schema.json` | `object.yaml`'s `identity` | Identity (SDD-R011 §5) |
| `classification.schema.json` | `object.yaml`'s `classification` | Classification (SDD-R011 §6), plus SDD-R001 §7/§19 search terms folded in |
| `authority.schema.json` | `object.yaml`'s `authority` | Authority (SDD-R011 §15, SDD-R012 §5/§12) |
| `evidence.schema.json` | `object.yaml`'s `evidence` | Evidence (SDD-R011 §16, SDD-R012 §13) |
| `provenance.schema.json` | `object.yaml`'s `provenance` | Provenance (SDD-R011 §17) |
| `history.schema.json` | `object.yaml`'s `history` | History (SDD-R011 §18) |
| `simulation.schema.json` | `object.yaml`'s `simulation` | Simulation (SDD-R011 §12) |
| `visualization.schema.json` | `object.yaml`'s `visualization` | Visualization (SDD-R011 §13) |
| `assets.schema.json` | `object.yaml`'s `assets` | Assets (SDD-R011 §14) |
| `properties.schema.json` | `properties.yaml` | Properties (SDD-R011 §7) |
| `relationships.schema.json` | `relationships.yaml` | Relationships (SDD-R011 §8) |
| `behaviors.schema.json` | `behaviors.yaml` | Behaviors (SDD-R011 §9) |
| `validation.schema.json` | `validation.yaml` | Validation (SDD-R011 §10) |
| `education.schema.json` | `education.yaml` | Education (SDD-R011 §11) -- consolidates WORK_PACKAGE_001's Description + AI Context + Education sections |
| `constraint.schema.json` | embedded via `$ref` in properties/relationships/behaviors/validation | Not a facet itself -- the shared structured-constraint shape (REFERENCE-TASK-000014) |
| `package_manifest.schema.json` | `packages/<package>/manifest.yaml` | Package identity (SDD-R004 §4) -- not an EKO facet at all; a package's own metadata |

## `object.yaml`'s shape

```yaml
identity: {...}          # required
classification: {...}    # required
authority: {...}         # required
evidence: [...]          # optional, default []
provenance: {...}        # required
history: {...}           # required
simulation: {...}        # optional, default {}
visualization: {...}     # optional, default {}
assets: [...]            # optional, default []
```

`identity`, `classification`, `authority`, `provenance`, and `history`
are required on every object -- an Engineering Knowledge Object without
an identified authority or a recorded history entry is incomplete
under SDD-R011/R012, even for a `Draft` object. `evidence`,
`simulation`, `visualization`, and `assets` may legitimately be empty
(not every object owns assets or exposes simulation metadata).

## Required fields per facet (the ones the JSON Schema itself enforces)

| Facet | Required |
|---|---|
| Identity | `object_id`, `object_type`, `display_name`, `short_name`, `version`, `lifecycle_state`, `package_id`, `uuid` |
| Classification | `domain`, `category` |
| Authority | `authority_type`, `authority_reference` |
| Provenance | `author`, `organization`, `created_date`, `confidence`, `content_license` |
| History | `lifecycle_events` (at least one entry, each with `state` + `date`) |
| Properties (each entry) | `property_id`, `display_name`, `value_type`, `required`, `read_only`, plus `value` when `read_only` is `true` |
| Relationships (each entry) | `relationship_id`, `relationship_type`, `target` |
| Behaviors (each entry) | `behavior_id`, `name`, `behavior_type`, `description`, `inputs`, `outputs` |
| Validation (each entry) | `rule_id`, `subject`, `operator`, `severity` |
| Education | none (every field optional) |

`provenance.reviewer` is *not* schema-required (a `Draft` object
legitimately has none yet) -- but `identity.lifecycle_state ==
"Published"` without one is a semantic error the validator catches
separately (SDD-R008 §13; see `docs/AUTHORING_GUIDE.md`).

## Closed enums vs. extensible vocabularies

Fields with a genuinely closed, stable value set use a JSON Schema
`enum` and are rejected outright if violated:

* `identity.lifecycle_state`, `history.lifecycle_events[].state`,
  `relationships[].lifecycle` -- SDD-R008 §4's eight lifecycle states.
* `authority.authority_type` -- SDD-R011 §15's five-value list.
* `evidence[].evidence_type` -- SDD-R011 §16's seven-value list.
* `behaviors[].behavior_type` -- SDD-R011 §9's nine-value list.
* `relationships[].cardinality` -- SDD-R003 §14's four multiplicities.
* `provenance.confidence`, `relationships[].confidence` -- four-value
  qualitative scale.
* `constraint.schema.json`'s `operator` -- eight comparison operators.
* `properties[].value_type`, `behaviors[].inputs/outputs[].value_type`
  -- primitive data types.

Fields explicitly declared extensible by their governing SDD are
**never** a JSON Schema `enum` -- hard-rejecting a legitimate future
extension would contradict the SDD that defines the list as a starting
point:

* `identity.object_type` (SDD-R001 §24).
* `relationships[].relationship_type` (SDD-R003 §21).

These are free-form strings at the schema layer, checked against
`tools/oep_reference_core/constants.py`'s initial lists by the
validator's semantic checks, which only ever produce a **warning** for
an unrecognized value (`docs/AUTHORING_GUIDE.md`).

## Interpretive decisions

**`identity.lifecycle_state` is the single authoritative lifecycle
field.** SDD-R002 §10 separately lists "Lifecycle" as a classification
dimension using the same SDD-R008 §4 value set. Carrying the same fact
in two independently-settable places would violate Constitution
Article V ("Engineering Knowledge Shall Never Be Duplicated") --
`classification` has no `lifecycle` field.

**`provenance.organization` replaced `classification.ownership`.**
SDD-R011 §17 lists "Organization" as a Provenance field; WORK_PACKAGE_001's
`classification.ownership` was the same fact, recorded in the facet
that was about to gain a dedicated Authority sibling and no longer
needed to carry it. See `docs/SCHEMA_MIGRATION.md` for the full
reasoning.

**`unit_ref` and `unit_symbol_pending` are mutually exclusive, and only
one produces a validator error if unresolved.** REFERENCE-TASK-000011
requires unit references to resolve to a compiled Unit EKO "wherever
practical." `unit_ref`, when set, is *always* required to resolve --
`check_broken_references` reports an **error** otherwise.
`unit_symbol_pending` is the documented, non-error escape hatch for a
property whose true unit has no compiled Unit EKO yet (only `unit.volt`
exists among the five gold objects) -- tracked instead as an **info**
finding by `check_pending_unit_exceptions`, and enumerated in full in
`docs/SCHEMA_MIGRATION.md`'s "Deferred Unit EKOs" table.

**Structured constraints cannot express cross-property or per-element
predicates**, only a single subject compared against a literal operand
(`constraint.schema.json`). Where WORK_PACKAGE_001's free text expressed
something richer (e.g. "no individual resistance in this list shall
equal zero"), that requirement is now recorded as a free-text `note`
inside the relevant behavior's `execution_metadata` rather than forced
into a shape that can't carry it -- see `docs/SCHEMA_MIGRATION.md`
§"What structured constraints cannot express" for the exact list.

**`assets` and `visualization` are separate facets with no overlap.**
SDD-R011 §14: "Assets are referenced. Assets are not Engineering
Knowledge." SDD-R011 §13: "Visualization never changes engineering
meaning." `assets` (top-level on `object.yaml`) holds every file an
object physically owns (`{role, path, kind, description}`);
`visualization` holds only presentation hints, referencing an asset by
its `role` string (validated against the object's own `assets` list by
`check_asset_references`) rather than repeating a file path.

**No Source Object EKOs exist for `authority_source_object` or
`evidence[].evidence_source_object` to reference.** SDD-R012 §7
describes authorities and standards eventually becoming their own EKOs
(`standard.iec.60617`, etc.); WORK_PACKAGE_002 explicitly defers
creating any (out of scope: "do not implement them unless absolutely
required for schema correctness," and free-text `authority_reference`/
`evidence[].reference` already satisfies the schema). Both fields stay
`null` on every gold object today, with a `notes` field stating this
explicitly.
