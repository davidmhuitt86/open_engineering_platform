# Knowledge Runtime Boundary (WP-EKE-013)

Status: implemented by WP-EKE-013. Specifications: AP-EK-001, AP-EK-013,
AP-EK-020. Audit basis: AP-EKE-012
(`docs/project/audits/2026-09-19-AP-EKE-012-REFERENCE-RUNTIME-DIAGRAM-KNOWLEDGE-AUDIT.md`).

## Roles

```
Reference Library      = authoritative authored knowledge (YAML EKOs)
Reference Compiler     = deterministic compilation (Python, knowledge/reference_library/compiler)
.oerp                  = immutable distributable knowledge package
OerpReader             = package parser (platform/oep_engine/lib/core/knowledge/oerp)
KnowledgeRuntime       = immutable authoritative runtime registry
Reference Discovery    = FUTURE consumer of KnowledgeRuntime (not implemented)
```

The runtime consumes only compiled output (`manifest.json` + `runtime.json`
read by `OerpReader`). It never reads authoring YAML, and there is no second
package loader or package format. WP-EKE-013 ends at `KnowledgeRuntime`.

## Registries

`KnowledgeRuntime` keeps typed registries (not a generic untyped store):
dimensions, units, **objects**, **relationships**, component models, laws,
equations, constraints, provenance. All are unmodifiable after activation,
and the retained `runtime.package` holds unmodifiable collections.

### Object registry

`getObject(id)` returns a `KnowledgeObject`: the canonical reference-object
identity exactly as authored in the Identity/Classification facets
(`id`, `objectType`, `name`, `shortName`, `version`, `lifecycleState`,
`uuid`, `domain`, `tags`) plus `provenanceId`. It is the *reference-library*
object; it is not an Engineering Graph instance (`core/graph`) and not an
Engineering Repository object. The AP-EK-013 §18 fields `description`,
`createdUtc`, `lastModifiedUtc`, `author` are not authored in schema 1.0 and
are therefore not invented.

### Relationship registry

`getRelationship(id)` returns a `KnowledgeRelationship` (`id`,
`relationshipType`, `sourceObjectId`, `targetObjectId`, `cardinality`,
`lifecycle`, `confidence`, `notes`, `provenanceId`); the source is the
object that owns the authored relationship. `relationshipsForObject(id)`
returns every relationship where the object is source or target, sorted by
id (empty list when it has none; `referenceNotFound` for an unknown object).
The optional authored fields are `""` when absent.

### Where the data comes from (decision)

The Reference Compiler's `runtime_export.py` projects `objects` and
`relationships` into `runtime.json`, alongside the existing registries.
`graph.idx` was not used because it carries only outgoing edge
targets keyed by node (no object identity, no cardinality/confidence), and
consuming it would require a second reader path in the runtime. One compiled
member, one reader, deterministic ordering (every list sorted by id).
`graph.idx` remains the precompiled index intended for future Discovery.

## Activation rules

Duplicate authoritative ids are rejected in **every** registry with
`duplicateAuthority` (registries are built by an explicit helper, never by a
map literal that would keep the last definition).

Before a package activates, every reference the schema actually carries must
resolve, otherwise activation fails with `invalidReference` (the same code
already used for unit -> dimension):

| From | Field | Must exist in |
|---|---|---|
| Unit | `dimensionId` | dimensions |
| Equation | `provenanceId`, `dimensions[]` | provenance, dimensions |
| Law | `provenanceId`, `equationRefs[]` | provenance, equations |
| Constraint | `provenanceId` | provenance |
| ComponentModel | `provenanceId`, `equationRefs[]`, `constraintRefs[]`, `parameters[].dimensionId` | provenance, equations, constraints, dimensions |
| Object | `provenanceId` | provenance |
| Relationship | `sourceObjectId`, `targetObjectId`, `provenanceId` | objects, objects, provenance |

Not validated because the schema carries no such field: dimension and unit
provenance. `ProvenanceRecord.sourceObjectId` is also not checked against the
object registry (fixture packages declare no objects). Missing lookups at
runtime are `referenceNotFound`, distinct from invalid package content.

## Identity

Package and runtime identities are separate (AP-EK-013 §7):

```
package:  packageId, packageVersion, schemaVersion, compilerVersion, contentHash
runtime:  runtimeVersion, runtimeBuild   (KnowledgeRuntime.runtimeVersion / .runtimeBuild)
```

`runtimeVersion` is `0.1.0`, mirroring `platform/oep_engine/pubspec.yaml`
(a test enforces they agree); `runtimeBuild` is a manual counter bumped when
runtime semantics change without a version bump. It is never derived from
`packageId@packageVersion`. A `RuntimeIdentity` persisted before this change
loads with `runtimeBuild = "unrecorded"`; its old `runtimeVersion` string
(`<package>@<version>`) is preserved as recorded.

## Capabilities

`runtime.capabilities` is derived from the immutable package only: registry
counts (0 for an empty optional registry), `availableRegistries`, `has(name)`,
component-model `domains`, and sorted id lists for units, laws, equations,
component models and constraints. All collections are unmodifiable.

## Content hash

`objects` and `relationships` are part of the canonical serialisation and so
of `contentHash`. Hashes computed before this change (packages without those
members) differ, because the canonical form now has two extra (empty) lists.
No stored hash was pinned by any test or persisted artefact in this repository.

## Trust

Unchanged: hash verification is still enforced; a package declaring a
signature still cannot activate (no trust store exists); unsigned packages
activate only with the explicit development flag. Signature verification
remains a disclosed gap.

## Outside the runtime

Reference Discovery, semantic/fuzzy search, embeddings, LLM/vision
interpretation, inference and reference-usage records. The workspace/diagram
`SearchService` (`lib/core/search`) indexes Engineering Graph instances in the
open workspace; it is not Reference Discovery and does not read the
KnowledgeRuntime.
