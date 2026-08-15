# Diagram Studio — Engineering Mapping

**Architecture Phase:** AP-DS-002. This is the required "Engineering Mapping" deliverable: how every diagram element maps to Engineering Objects and Relationships, per the spec's "The mapping shall be documented."

## The constraint this mapping resolves

Foundation's `EngineeringObject`/`Relationship` schema (`oep_foundation/platform/repository/include/oep/repository/{engineering_object,relationship}.hpp`) is intentionally minimal and fixed-field — it has no generic properties bag and never will. AP-DS-001's `ENGINEERING_MODEL.md` correctly identified this meant genuinely graphics-only data (positions, viewport, selection state) could never honestly become Engineering Objects — they have no independent engineering meaning, and forcing them into the object model would violate the frozen Constitution's "no graphics-only entities" principle from the other direction (pretending decoration is engineering data).

AP-DS-002 resolves this with one small, additive Foundation-side schema extension (not a redesign): `EngineeringObject` gained an opaque `content` string field that Foundation never parses (`OEP_API_VERSION` 19→20, `OEP_ABI_VERSION` unchanged at 1 — purely additive, verified). This single field is what makes the mapping below possible without duplicating data or inventing graphics-as-engineering-objects.

## The mapping

| Diagram element | Foundation representation |
|---|---|
| **Diagram** | One `EngineeringObject`, `ObjectType::Diagram`. `name` = diagram title. `content` = `jsonEncode({'graph': EngineeringGraph.toJson(), 'layout': DiagramLayoutState.toJson()})` — a complete, lossless snapshot. **This is the round-trip source of truth** for open/save. |
| **Node** (Wire/Connector/Module/Harness/Splice/Terminal/Component/every `NodeCategory`) | One `EngineeringObject` each, `ObjectType::Component`. Tags: `node-category:<category>` (preserves `oep_engine`'s finer `NodeCategory` taxonomy, since Foundation's `ObjectType` enum is coarser by design) and `diagram:<diagramObjectId>` (so a diagram's decomposed objects can be found/cleared without a separate index). |
| **Wire connection** (`EngineeringRelationship`, `RelationshipType.connectedTo`) | One Foundation `Relationship`, `RelationshipType::ConnectedTo`, between the two corresponding node objects. |
| **Annotation** | **Not a separate Engineering Object** — per AP-DS-001's own ratified Constitution (§3.2), annotations are the one deliberate "no independent engineering type" exception. Lives inside the Diagram's `content` blob only. This is a frozen decision, not re-litigated here. |
| **Layer** | **Not a separate Engineering Object** — a tag on member nodes (e.g. `layer:power`) plus layer definitions (name/visibility/lock) inside the `content` blob. Avoids proliferating low-value repository objects for what is fundamentally a rendering/organization grouping. |
| **Viewport, Selection Set, User Preferences** | **Never Engineering Objects** — presentation state with no independent engineering meaning, lives inside the `content` blob exclusively. Forcing these into the object model would violate "no graphics-only entities." |
| **Document Metadata** | Native to `EngineeringObject` already (name/description/author/version/tags/timestamps) — no new mechanism needed. |
| **Relationship Metadata** | Native to `Relationship` already (description/author/created timestamp) — no new mechanism needed. |
| **Project** | One `EngineeringObject`, `ObjectType::Project`. A diagram belongs to a project by convention (created together via `DiagramRepositoryService.createProject`); no `Contains` relationship is currently created between them — see Known Limitations below. |
| **Package** | Unchanged — Foundation's pre-existing package/installer/trust subsystem (WP-REP series), consumed as-is through already-bound FFI calls. AP-DS-002 added no new package-level mapping. |

## Why decomposition AND a content blob, not just one or the other

A content-blob-only design would satisfy "no data loss" but not "Engineering Objects become the canonical document model" — the repository would contain one opaque object per diagram, nothing genuinely queryable. A decomposition-only design (every node/wire as separate objects, nothing else) would satisfy the object-model requirement but couldn't honestly represent viewport/selection/layer-visibility/annotations without inventing graphics-as-engineering-objects, violating the frozen Constitution.

The chosen design does both: **real engineering entities become real, queryable Foundation objects** (nodes, wires), while **presentation-only state stays in one content blob attached to the object that legitimately owns it** (the Diagram). The content blob is the authoritative round-trip source — `loadDiagram` reads only from it, never reconstructs from the decomposed objects — so the decomposed objects can never become a second, divergent source of truth. This directly honors the platform's "never duplicate Engineering Object data" rule: the position/viewport/layer data isn't duplicated anywhere, it exists in exactly one place (the content blob), and the decomposed node/wire objects carry no data the blob doesn't already have.

## Known limitations (honest, not hidden)

1. **Decomposed objects are regenerated on every save, not diffed.** `DiagramRepositoryService.saveDiagram` deletes and recreates every Component object/`ConnectedTo` Relationship tagged to the diagram on each save, rather than computing a minimal diff. Correctness does not depend on this (the content blob is authoritative), but it means Foundation's audit log accumulates a create/delete pair for every unchanged node on every save — real object churn, and a real optimization opportunity for a future phase, not attempted here.
2. **No `Contains` relationship between Project and Diagram objects yet.** A diagram created via `createProject`+`saveDiagram` are two independent objects today, associated only by application convention (both created in the same `DiagramRepositoryService` call sequence), not a queryable Foundation relationship. Adding one is a small, additive follow-up.
3. **Single-repository-transaction-per-call, not one transaction spanning a whole multi-step workflow.** `saveDiagram` and `createProject` each wrap themselves in their own transaction; `migrate` (which calls both) does not additionally wrap the whole sequence in one outer transaction, so a failure partway through `migrate` leaves any already-committed earlier step (e.g. a created Project) in place even though the overall migration is reported as failed. This is disclosed explicitly in `DiagramRepositoryService.migrate`'s own code comment and in `MIGRATION_GUIDE.md` — not hidden behind a false "fully atomic" claim.
