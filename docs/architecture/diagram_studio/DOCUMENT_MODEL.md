# Diagram Studio — Document Model

**Architecture Phase:** AP-DS-001 (superseding updates from AP-DS-001A and AP-DS-002 below)

> **AP-DS-002 update (supersedes §2's core claim).** This document's original §2 stated Diagram Studio documents are local-only and never create a Foundation `EngineeringObject`. **This is no longer true.** `DiagramRepositoryService` (`lib/diagram_studio/repository/diagram_repository_service.dart`) now saves diagrams as repository-backed Engineering Objects — see `ENGINEERING_MAPPING.md` for the full mapping and `MIGRATION_GUIDE.md` for converting existing local documents. The local-JSON `DiagramDocument` model described below is NOT removed — it remains valid for two purposes: (1) AP-DS-001A's Autosave/Recovery mechanism, which is deliberately still local-only (recovery must survive a crash before any repository write happens), and (2) as the source format migration reads FROM. §7's "reserved but unused `repositoryObjectId`" note is also superseded: repository-backed nodes now populate a real Foundation object id, via the decomposition described in `ENGINEERING_MAPPING.md` — though note the mapping document's own honest caveat that these decomposed objects are regenerated (not diffed) on every save.

> **AP-DS-001A update.** Autosave, Recent Files, and document metadata (title/created/modified/author) — all named as gaps implicitly by this document's original §6 ("no autosave was found") — are now implemented, entirely within the local-JSON model described below (no Foundation involvement, `schemaVersion` unchanged at 1). Autosave writes to a separate recovery file, never the user's save path; a `findRecovery()`/`recoverFrom()` pair supports startup crash-recovery. See `oep_studio/docs/IMPLEMENTATION_STATUS.md`'s AP-DS-001A section for full detail. §5's "no migration logic" limitation remains open and unchanged for the LOCAL schema specifically — AP-DS-002 added migration to a different (repository-backed) format, not versioning within the local JSON schema itself. Sections below are left as originally written.

## 1. What a "document" is today

A Diagram Studio document (`DiagramDocument`, `oep_studio/lib/diagram_studio/host/diagram_document.dart`) is a single local JSON file combining two serialized structures:

```json
{
  "graph": { /* EngineeringGraph.toJson() — nodes, relationships, groups, ports */ },
  "layout": { /* DiagramLayoutState.toJson() — positions, layers, annotations, view state */ }
}
```

`schemaVersion = 1`. Read/written via plain `dart:io` `File`/`jsonDecode`/`jsonEncode` — no database, no Foundation Repository call anywhere in the path.

## 2. Why it is local-only (a deliberate, documented decision, not an oversight)

Foundation's actual repository schema has no concept of Diagram Layout, ViewState, Annotations, Layers, or wire overrides — it knows only `EngineeringObject`/`Relationship` plus an append-only audit log. Building genuine Foundation-backed diagram persistence requires a Foundation-side schema extension, which was explicitly out of scope for the work that built Diagram Studio's Phase 1 (`oep_foundation` may not be modified from within a Diagram Studio work package). This is stated verbatim in `diagram_document.dart`'s own doc comment and is ratified here as the accurate current state, not something this phase silently accepts without flagging: **it is a real, unresolved architectural gap that must be closed before Diagram Studio can be considered Foundation-integrated**, and it is the top-priority item in `IMPLEMENTATION_ROADMAP.md`.

## 3. Document hierarchy — flat, not multi-sheet

There is **no "Sheet," "Drawing Set," "Project," or "Package" concept** anywhere in the codebase (confirmed by grep across both packages — zero matches). One file = one flat `EngineeringGraph` + one `DiagramLayoutState`. There is a `DiagramLayer` concept, but it is an **intra-diagram** z-order/visibility/lock grouping mechanism, not a multi-sheet drawing-set concept — do not conflate the two when reading other Studio documentation that uses "layer" loosely.

**Cross-sheet references do not exist**, because sheets do not exist. Any future multi-sheet/drawing-set capability is new document-model work, not a refinement of existing structure.

## 4. Engineering Context

The "ambient" Foundation repository (open/closed state) is tracked for **display only** — a badge shown in the document UI — and has no bearing on document content, persistence, or the `EngineeringGraph` itself. There is currently no notion of a document being "scoped to" or "backed by" a specific Foundation repository or package.

## 5. Versioning

A single `schemaVersion = 1` integer constant. No migration logic, no revision history, no diff/merge capability. If the JSON schema changes in a future phase, there is currently no upgrade path defined — this should be treated as a known limitation to design for before the schema is extended, not discovered after the fact.

## 6. Persistence & autosave

- **Document persistence**: explicit, user-triggered Open/Save/Save As/Close/New only. Confirmed no autosave of document content.
- **Workspace-state persistence** (a different thing — panel visibility/widths, last-open path, view state): this IS autosaved, via `WorkspaceStateStorage.save()` on dispose/toggle. This is UI-chrome preference persistence, not document autosave, and should not be conflated with it in future documentation.

## 7. Node → Foundation Object linkage (reserved but unused)

`EngineeringNode` carries a nullable `repositoryObjectId` field, explicitly commented as "Foundation Object this node is mapped to, once a Repository is attached... `null` for a temporary/unsaved graph." **Nothing in the current implementation ever populates this field.** It is a designed-for hook, not a working feature — every node created today has `repositoryObjectId == null` permanently, because nothing calls into Foundation to create or resolve one. See `ENGINEERING_MODEL.md` for the full implication of this.

## 8. Summary assessment

The document model is internally coherent and functionally sufficient for a standalone local drawing tool — serialization is real, round-trips correctly, and workspace-state persistence works. It is **not yet an "engineering document" in the platform sense** — it does not participate in the Repository, has no multi-sheet structure, no versioning beyond a single schema constant, and no cross-document referencing. Treat this document model as Phase 1 of a longer arc, not a finished target state.
