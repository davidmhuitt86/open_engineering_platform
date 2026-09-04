# Schema Migration: WORK_PACKAGE_001 to Engineering Knowledge Object Schema Version 1.0

WORK_PACKAGE_002 froze Schema Version 1.0 by implementing SDD-R011's
Engineering Knowledge Facet model and SDD-R012's Authority/Evidence
model, then refactoring the five gold-standard objects to conform.
"Backward compatibility is not required at this stage" (WORK_PACKAGE_002)
-- every change below is a breaking rename or restructuring, applied
uniformly across schemas, validator, compiler, and the five gold
objects in the same commit. This document records every non-obvious
decision so a future reader never has to reverse-engineer *why* a field
moved, was renamed, or was dropped.

## Why a migration document, not just updated schemas

SDD-R008 (Engineering Knowledge Lifecycle) requires history to never
be destroyed and every change to remain traceable. A schema
normalization is itself an engineering decision with its own
provenance -- this document, plus the `history.migration_notes` entry
every gold object now carries, are that record.

## The Facet model (SDD-R011) supersedes WORK_PACKAGE_001's ad hoc sections

WORK_PACKAGE_001 organized an object around whatever sections
SDD-R001 §5 happened to list, with no single governing model for *how*
those sections related to each other. SDD-R011 formalizes this: every
EKO is "a structured collection of Engineering Knowledge Facets," not
a file (SDD-R011 §2/§21 rule 2/3). Fourteen facets are canonical:
Identity, Classification, Properties, Relationships, Behaviors,
Validation, Education, Simulation, Visualization, Assets, Authority,
Evidence, Provenance, History.

### Facets map to files, but not one-for-one

REFERENCE-TASK-000010 requires facets to "become the canonical
architectural unit" but SDD-R011 §21 rule 3 is explicit that "files are
implementation details." Two options existed: one physical YAML file
per facet (14 files per object), or keeping WORK_PACKAGE_001's existing
six-file physical layout and reorganizing what each file's *content*
represents. The second was chosen:

* `object.yaml` now carries the nine facets that aren't array-heavy
  enough to justify their own file: Identity, Classification,
  Authority, Evidence, Provenance, History, Simulation, Visualization,
  Assets.
* `properties.yaml`, `relationships.yaml`, `behaviors.yaml`,
  `validation.yaml`, `education.yaml` remain their own files, exactly
  as WORK_PACKAGE_001 already had them -- each already corresponded
  1:1 to a facet (Properties, Relationships, Behaviors, Validation,
  Education respectively), so no change was needed there beyond the
  field-shape normalization described below.

This halves the churn (six files stay six files) while still making
every facet an independently-schema'd JSON Schema definition
(`schemas/*.schema.json`, one per facet, `$ref`'d together from
`object.schema.json`) -- the schema, not the file, is what SDD-R011
actually requires to be the architectural unit, and that requirement
is met in full.

## Field-by-field changes

### Identity (SDD-R011 §5)

| WORK_PACKAGE_001 | Schema Version 1.0 | Why |
|---|---|---|
| `identity.canonical_name` | `identity.short_name` | SDD-R011 §5 lists "Short Name," not "Canonical Name" -- a straight rename, same semantics. |
| `identity.status` | `identity.lifecycle_state` | SDD-R011 §5 calls this "Lifecycle State." Still the single authoritative lifecycle field -- SDD-R002 §10's "Lifecycle" classification dimension is represented here, never duplicated under `classification` (Constitution Article V). |
| *(none)* | `identity.package_id` | New in SDD-R011 §5 -- package membership becomes an explicit identity fact instead of only being implicit from directory location under `packages/<package_id>/`. |
| *(none)* | `identity.uuid` | New in SDD-R011 §5 -- a stable identifier independent of `object_id`, so a future rename/re-slug of the human-readable id can still be recognized as the same underlying object. Generated once via `uuid.uuid5` against a fixed namespace and object_id (deterministic, not `uuid4` -- regenerating it would be a spurious diff on every migration). |

### Version Information: dropped as a separate facet

WORK_PACKAGE_001 had a structured `version: {major, minor, patch,
revision_notes, compatibility}` section, mirroring SDD-R001 §22.
SDD-R011 §5's Identity Facet lists only a single `version` string field
-- no separate Version Information facet exists in the 14-facet list.
Rather than inventing a fifteenth facet SDD-R011 does not define,
`identity.version` (a plain semver string, e.g. `"1.0.0"`) became the
sole authoritative version, and `revision_notes` moved to
`provenance.revision_notes` (still structured, still a list of
strings) since Provenance already tracks "who changed what, when."

### Classification (SDD-R011 §6)

| WORK_PACKAGE_001 | Schema Version 1.0 | Why |
|---|---|---|
| `classification.authority` | moved to the new `authority` facet | REFERENCE-TASK-000013 explicitly separates Authority from Classification; SDD-R011 §15 gives Authority its own facet. |
| `classification.visibility` | **dropped** | SDD-R011 §6's field list (Domain, Discipline, Family, Category, Subcategory, Roles, Capabilities, Technology, Industry, Tags) has no Visibility field, and no other facet claims it either. WORK_PACKAGE_001's `visibility` (Public/Licensed/Enterprise/...) was really a *package distribution* concern (SDD-R002 §12: "controls distribution"), not a per-object classification fact -- dropped rather than force-fit into a facet that doesn't want it. If package-level distribution control is needed later, it belongs on the package manifest, not the object. |
| `classification.ownership` | moved to `provenance.organization` | SDD-R011 §17 Provenance Facet lists "Organization." WORK_PACKAGE_001's `ownership` ("the maintaining organization") is exactly that fact, just recorded in the wrong facet -- Provenance ("who maintains/authors this record") is the right home, distinct from the new Authority facet ("where does the engineering truth originate"). |
| `search_metadata.*` (a separate `object.yaml` section) | folded into `classification` | SDD-R011 has no separate Search Metadata facet. Its fields (keywords, aliases, abbreviations, alternate_names, manufacturer_terms, standards_references) are all still genuinely classification-adjacent search terms, so they became additional `classification` fields rather than being dropped or given a facet SDD-R011 doesn't define. |

### The new Authority Facet (SDD-R011 §15, SDD-R012 §5/§12)

`authority.authority_type` is a closed, five-value enum (Physical Law,
International Standard, Government Standard, Manufacturer
Specification, Internal Engineering Authority -- SDD-R011 §15's own
list). `authority.authority_reference` is free text identifying the
specific law/standard (e.g. "Ohm's Law", "IEC 60617 rectangular
resistor symbol"). `authority.authority_source_object` is reserved for
an Object ID once a Source Object EKO exists to reference (SDD-R012 §7:
`authority.iec`, `standard.iec.60617`, etc.) -- **no Source Object EKOs
were created in this work package.** WORK_PACKAGE_002 explicitly
instructs "document the requirement but do not implement them unless
absolutely required for schema correctness," and free-text
`authority_reference` is schema-correct on its own; every gold
object's `authority.notes` field states this explicitly as a deferred
normalization.

### The new Evidence Facet (SDD-R011 §16, SDD-R012 §13)

An array of `{evidence_type, reference, evidence_source_object,
description}`. `evidence_type` is a closed enum (Standard, Datasheet,
Manual, Application Note, Test Result, Calculation, Simulation Result).
Same deferred-Source-Object-reference treatment as Authority above --
`evidence_source_object` stays null until a real Source Object EKO
exists.

### The new History Facet (SDD-R011 §18)

`history.lifecycle_events` (required, at least one entry) records each
lifecycle transition with `{state, date, notes}`. Every gold object's
first entry documents its original WORK_PACKAGE_001 publication; a
second entry documents this migration -- "History shall never be
destroyed" (SDD-R008 §2) applies from the very first commit that
introduces the facet, not retroactively reconstructed later.

### Provenance (SDD-R011 §17)

`review_status` was **removed**. WORK_PACKAGE_001's `provenance` had
its own `review_status` field carrying the same Draft/Under
Review/.../Published value set as `identity.status`. Once
`identity.lifecycle_state` was confirmed as the single authoritative
lifecycle field (see Identity above), a second, independently-settable
copy of the same fact on Provenance was a direct Article V violation
waiting to happen (the two could silently drift apart). `organization`,
`approval_date`, and `digital_signature` were added, matching SDD-R011
§17's field list exactly (`digital_signature` stays `null` -- same
deferred-signing-infrastructure reasoning as the package-level
signature in `docs/PACKAGE_FORMAT.md`).

### Properties (SDD-R011 §7, REFERENCE-TASK-000011/000012)

| WORK_PACKAGE_001 | Schema Version 1.0 | Why |
|---|---|---|
| `name` | `property_id` | REFERENCE-TASK-000012: "Properties shall no longer rely on display names as identifiers." `property_id` is now documented as permanent; `display_name` may change freely without touching identity. (In practice the string values are unchanged -- this is a field-name/semantic promotion, not a re-slugging.) |
| `units` (a string, either a plain symbol or an object-id-shaped string the validator guessed at) | `unit_ref` **and** `unit_symbol_pending`, mutually exclusive | REFERENCE-TASK-000011: "Replace display-unit strings with references to Unit Engineering Knowledge Objects wherever practical." `unit_ref` must resolve to a real Unit EKO's `object_id` (a hard validator error if set and unresolved). `unit_symbol_pending` is the explicit, documented escape hatch for a unit with no compiled Unit EKO yet -- surfaced as an **info**-severity finding by `validator.checks.check_pending_unit_exceptions`, never an error or a silent gap. See "Deferred Unit EKOs" below for exactly which properties use it and why. |
| `default` | `value` **or** `default_value` (mutually exclusive by `read_only`) | SDD-R011 §7 lists both "Value" and "Default Value" as distinct property fields. The schema now requires `value` when `read_only` is `true` (a fixed physical constant, e.g. `unit.volt`'s `conversion_factor_to_si: 1.0`) and expects `default_value` otherwise (a suggested, user-overridable starting point, e.g. a resistor's `resistance: 1000`). |
| `range: {min, max}` only | `range` retained, plus a new `constraints` array | REFERENCE-TASK-000014 structured constraints (see below) sit alongside the simpler `range` shape rather than replacing it -- `range` remains the right tool for a plain numeric bound. |
| *(none)* | `visibility` (`public`/`internal`/`advanced`) | New in SDD-R011 §7 -- property-level visibility, unrelated to (and a replacement in spirit for) the object-level `classification.visibility` that was dropped. |

### Relationships (SDD-R011 §8, REFERENCE-TASK-000016)

WORK_PACKAGE_001's shape (`type`, `category`, `target`, `multiplicity`,
`metadata`, `behavior`, `constraints` as free text, nested `provenance`,
nested `version`) is replaced wholesale by SDD-R011 §8's own, leaner
field list: `relationship_id`, `relationship_type` (renamed from
`type`), `target`, `cardinality` (renamed from `multiplicity`),
`lifecycle`, `confidence`, `notes`, plus a structured `constraints`
array (REFERENCE-TASK-000014). **`category`, `metadata`, `behavior`,
the nested `provenance`, and the nested `version` are all dropped** --
none of them appear in SDD-R011 §8's field list, and a relationship's
own `lifecycle` (its maturity, independent of either endpoint's
`lifecycle_state`) plus `confidence` cover what `metadata` was
informally used for in WORK_PACKAGE_001. `notes` is explicitly
documentation-only, never authoritative for validation (SDD-R011 §10's
principle applied to relationships too) -- `constraints` is the
authoritative, structured mechanism for anything that used to be a
free-text relationship constraint.

### Behaviors (SDD-R011 §9, REFERENCE-TASK-000015)

`type` renamed to `behavior_type`, now drawn from SDD-R011 §9's
nine-value list (Solver, Calculator, Validator, Converter, Analyzer,
Optimizer, Recommender, Explainer, Simulator) -- **replacing**
SDD-R005 §5's twelve-value list (Calculation, Simulation, Validation,
Transformation, Measurement, Recommendation, Analysis, Conversion,
Prediction, Optimization, Diagnostics, Education) used in WORK_PACKAGE_001.
The mapping applied to every existing behavior:

| SDD-R005 (WORK_PACKAGE_001) | SDD-R011 (Schema Version 1.0) |
|---|---|
| Calculation | Calculator |
| Simulation | Simulator |
| Validation | Validator |
| Conversion | Converter |

`description` is now explicitly documentation-only (REFERENCE-TASK-000015:
"Separate executable behavior from descriptive documentation") --
the *executable* contract is entirely the structured `inputs`/
`outputs`/`constraints`/`dependencies` fields, which carried no
engineering meaning change, only the `unit_ref`/`unit_symbol_pending`
split described under Properties above. A new `execution_metadata`
object (SDD-R011 §9) records facts about execution (e.g.
`deterministic: true`, or a free-text `note` for a constraint the
structured shape can't express -- see "What structured constraints
cannot express" below) without performing any execution itself; no
Engineering Behavior Engine exists to execute anything regardless
(explicitly out of scope, both work packages).

Behavior identifiers were reviewed against REFERENCE-TASK-000015's
"Behavior identifiers shall describe engineering intent" -- every
existing `behavior_id` was already a verb-phrase-derived dotted path
(e.g. `component.passive.resistor.calculate_current`), so no renaming
was needed, only the `behavior_type` remapping above.

### Validation (SDD-R011 §10, REFERENCE-TASK-000014)

WORK_PACKAGE_001's `expression: "resistance > 0"` (a free-text string)
is replaced by structured `subject`/`operator`/`operand` fields
(`subject: resistance, operator: gt, operand: 0`) -- see "Structured
constraints" below. `applies_to` was renamed `subject` for consistency
with the same field name used by `constraint.schema.json` everywhere
else it appears (properties/relationships/behaviors).

### Structured constraints (REFERENCE-TASK-000014)

A single shared definition, `schemas/constraint.schema.json`, is
`$ref`'d from `properties.schema.json`, `relationships.schema.json`,
`behaviors.schema.json`, and `validation.schema.json`:

```json
{"subject": "resistance", "operator": "gt", "operand": 0, "description": "..."}
```

`operator` is one of `gt`/`gte`/`lt`/`lte`/`eq`/`neq` (binary,
compares `subject` to `operand`) or `not_null`/`not_empty` (unary).
`validation.yaml` rules are this same shape plus `rule_id` and
`severity` -- a validation rule *is* a constraint, with an id and a
severity attached.

#### What structured constraints cannot express

A single-subject, single-literal-operand predicate cannot express
cross-property comparisons (e.g. "the computed power shall not exceed
this resistor's own `power_rating` property" -- comparing a *computed
result* against *another property*, not a literal) or per-element
predicates over a list input (e.g. "no individual resistance in this
list shall equal zero"). Rather than stretching the structured shape
to cover these with ad hoc extensions, each such case is documented as
a free-text `note` inside the relevant behavior's `execution_metadata`
(e.g. `component.passive.resistor.calculate_power`,
`component.passive.resistor.voltage_divider`,
`component.passive.resistor.parallel_resistance`,
`equation.ohms_law.inverse_solver`) -- deferred to whatever eventually
implements the Engineering Behavior Engine (explicitly out of scope
for both work packages), not silently dropped.

### Visualization and Assets: split into two facets (SDD-R011 §13/§14)

WORK_PACKAGE_001 nested a generic `assets` list inside `visualization`.
SDD-R011 gives Visualization and Assets separate facets with distinct
purposes: "Assets are referenced. Assets are not Engineering Knowledge"
(§14) versus "Visualization never changes engineering meaning" (§13,
presentation *hints*, not file references). Schema Version 1.0 follows
this split exactly:

* `assets` (top-level, on `object.yaml`) is the array of
  `{role, path, kind, description}` entries an object physically owns
  -- `symbol.iec.resistor`'s real `assets/symbol.svg` lives here.
* `visualization` now holds only presentation *hints* SDD-R011 §13
  names (`color_hints`, `rendering_rules`, `default_labels`,
  `connection_styles`, `display_groups`) plus an `asset_roles` list
  that references assets *by role name* (a string, checked by the
  validator against the object's own `assets` entries) rather than
  repeating file paths.

`icon`/`preview_image`/`three_d_model`/`footprint` as direct fields on
`visualization` (WORK_PACKAGE_001's shape) were folded into the generic
`assets` array with the corresponding `role` value -- one mechanism for
every asset an object owns, rather than four special-cased fields plus
a generic list.

## Deferred Unit EKOs

REFERENCE-TASK-000011 requires documenting, not creating, Unit EKOs
this schema correctness needs but this work package does not populate.
Every property using `unit_symbol_pending` today:

| Object | Property | Pending symbol | Would resolve to |
|---|---|---|---|
| `component.passive.resistor` | `resistance` | `Ω` | `unit.ohm` |
| `component.passive.resistor` | `tolerance` | `%` | `unit.percent` |
| `component.passive.resistor` | `power_rating` | `W` | `unit.watt` |
| `component.passive.resistor` | `temperature_coefficient` | `ppm/°C` | *(composite -- no single existing unit family)* |
| `component.passive.resistor` | `noise` | `μV/V` | *(composite)* |
| `equation.ohms_law` | `current` | `A` | `unit.ampere` |
| `equation.ohms_law` | `resistance` | `Ω` | `unit.ohm` |
| `material.copper` | `resistivity_at_20c` | `Ω·m` | `unit.ohm_meter` |
| `material.copper` | `temperature_coefficient` | `1/°C` | *(composite)* |
| `material.copper` | `conductivity_iacs` | `%` | `unit.percent` |
| `material.copper` | `melting_point` | `°C` | `unit.celsius` |
| `material.copper` | `density` | `g/cm³` | *(composite)* |
| `material.copper` | `thermal_conductivity` | `W/(m·K)` | *(composite)* |

None of these were created. WORK_PACKAGE_002 explicitly says "do not
implement them unless absolutely required for schema correctness," and
`unit_symbol_pending` *is* schema-correct on its own -- these thirteen
info-severity findings (`validator.checks.check_pending_unit_exceptions`)
are the honest, deterministic record of exactly what a future Core
Units package (SDD-R009 §6) needs to supply, not a defect to silently
work around.

## What this migration deliberately did not touch

* **No new gold-standard objects.** All five from WORK_PACKAGE_001 are
  refactored in place; none were added, removed, or renamed.
* **No engineering facts changed.** Every numeric value, every
  relationship's source/target/type, every behavior's inputs/outputs
  -- unchanged. Only field *names* and *organization* moved.
* **No Source Object EKOs** (`authority.iec`, `standard.iec.60617`,
  etc.) were created, per the explicit instruction to defer them
  unless schema-correctness requires them; free-text
  `authority_reference`/`evidence[].reference` is schema-correct
  without them.
* **The compiler's `.oerp` output format is unchanged** (SDD-R004's own
  `manifest.json`/`reference.db`/`search.idx`/`graph.idx`/`assets/`/
  `localization/`/`signature/`/`license/` shape) -- only the *content*
  reference.db's columns hold, and the manifest's package version
  (`0.1.0` -> `1.0.0`, producing `core_reference_v1.oerp` instead of
  `core_reference_v0.oerp`, since a breaking schema migration is
  exactly what a major version bump is for).
