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

## Package format impact

- `runtime.json` `schemaVersion` stays `1.0.0`: the change is additive
  (two new top-level members, `objects` and `relationships`); no existing
  field changed meaning, and `manifest.json`, `search.idx`, `graph.idx`,
  `reference.db` and `assets/` are untouched.
**Missing required runtime member is not the same as an explicit empty runtime registry.**
`"objects": []` / `"relationships": []` means the package explicitly contains zero
entries and is valid. An absent member means the package does not satisfy the current
runtime package contract and is rejected with `packageInvalid` (message names the member
and says to recompile); it is never converted into an empty registry. This is an
intentional contract decision with no compatibility shim: there are no distributed legacy
`.oerp` packages, and a stale generated Studio asset is regenerated, not tolerated.

- `OerpReader` now **requires** both members. An `.oerp` compiled before
  WP-EKE-013 (no such members) is rejected with `packageInvalid` and must be
  recompiled; an empty list is valid and means the package authors none.
  (`KnowledgePackage.fromJson`, the in-memory/persisted form, still treats
  absent lists as empty; it is not a package format.)
- Studio bundles the compiled package as a generated, gitignored asset
  (`assets/knowledge/`); `tool/generate_knowledge_asset.dart` must be re-run
  so the bundled package carries the new members.
- `runtime.json` remains a typed projection of what deterministic lookup
  needs, not a dump of the Reference Library; full documents stay in
  `reference.db`.

## Compiler identity

`KnowledgePackageManifest.compilerVersion` (from `manifest.json`
`compiler_version`) is carried into `RuntimeIdentity.compilerVersion`
unchanged, alongside `packageId`/`packageVersion`/`schemaVersion`, and is
distinct from `runtimeVersion`/`runtimeBuild`.

## Symbol boundary (audited; documented, not resolved)

Audit result: `24d1cc2` does not violate the authoritative boundary; symbols
are a documented future integration point, not a defect of this work package.

- **Canonical source (Reference Library).** Symbols are Engineering Knowledge
  Objects of `object_type: Symbol` (currently one: `symbol.iec.resistor`, with
  identity, classification, properties such as `view_box`/`default_scale`, and
  an `assets/symbol.svg`).
- **Compiler.** The Reference Compiler already emits symbol knowledge: the
  object document in `reference.db`, its SVG under the `.oerp` `assets/`
  directory, its relationships in `graph.idx`, and (WP-EKE-013) its identity
  and relationships as a `KnowledgeObject`/`KnowledgeRelationship` in
  `runtime.json`. The runtime does **not** expose a symbol's properties or
  geometry: `runtime.json` projects typed properties only for Units, Equations
  and Components, and symbols were outside the AP-EK-013/AP-EK-020 first
  vertical slice. That is an intentional scope boundary, not a failure.
- **Engine `SymbolDefinition`** (`lib/core/symbols`, `SymbolLibrary`,
  `SymbolProvider`; 14 JSON definitions under `assets/symbols/`). It is a
  renderer/diagram concern *with some engine-owned semantics*: geometry (SVG
  asset), ports (id, connection type, direction, position), rendering
  metadata and validation rules (`requiredPortIds`,
  `allowedConnectionTypes`, used by `ValidationService`). Callers are the
  diagram view, exporters, validation and search. `EngineeringNode.symbolId`
  refers to `SymbolDefinition.identifier` (e.g. `resistor`).
- **Identity.** An engine symbol has no reference-library identity: its
  identifiers (`resistor`, `battery`, ...) do not correspond to EKO ids
  (`symbol.iec.resistor`), and no mapping exists in either direction. Today
  the two are independent authorities with no overlapping ids, so they do not
  conflict, but nothing prevents them diverging. This is the key integration
  question for later diagram interpretation.
- **No authority conflict exists today** (the identities are separate), and this is
  not a WP-EKE-013 violation. Any integration must explicitly define the mapping
  and decide where port/connection semantics belong.
- **Intended FUTURE direction (adapter and mapping do not exist):**

  ```
  Reference Library Symbol -> Compiler -> .oerp -> KnowledgeRuntime
        -> FUTURE Symbol Knowledge Adapter -> Engine SymbolDefinition / renderer
  ```

  The renderer's `SymbolLibrary` and the Reference Library must not both
  independently author canonical symbol knowledge.
- **Keep separate:** Symbol *knowledge* (what a symbol is, standards, semantics)
  is not symbol *rendering* (geometry/ports/style) and neither is visual symbol
  *recognition*. A future LLM/vision pipeline may use all three; they must not
  become one authority.
- **Deferred (required before symbol retrieval or diagram interpretation):**
  decide whether `SymbolProvider` resolves from compiled Symbol EKOs; define
  the `object_id` <-> `SymbolDefinition.identifier` mapping; decide which of
  ports/connection semantics belong in the Reference Library versus the
  renderer; expose symbol properties/geometry references through the runtime if
  needed. No second symbol store was created and the renderer was not touched.

Reference Discovery, symbol integration and diagram interpretation are later work
packages; none is implemented here.

## Authority separation

```
Reference Library -> Compiler -> .oerp -> OerpReader -> KnowledgeRuntime
   (authored)                                            = authoritative compiled
                                                           reference knowledge
Reference Discovery = future deterministic retrieval over the runtime/indexes
LLM / Vision        = future interpretation layer (produces observations only)
Engineering Repository = accepted project engineering truth
Engineering Graph      = project/workspace representation (not merged with the
                         reference knowledge graph)
```

The runtime does not depend on an open repository, Studio state, UIF, the
Reference Vault or acquisition state.

## Re-audit of AP-EKE-012 findings against current source

Confirmed still valid before this change and fixed: no object/relationship
registries; map-comprehension registries silently overwriting duplicates
(dimensions/units already checked); most cross-references unchecked;
`runtimeVersion` derived from `packageId@packageVersion`; no capability
surface. Not changed (out of scope, still open): signature verification,
`search.idx`/`graph.idx` readers, symbol mapping, terminal counts by convention.
