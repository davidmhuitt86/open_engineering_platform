# Repository Integration

WORK_PACKAGE_024, ENGINE-TASK-000111 — Open/Save/Save As/Close/Dirty
State for a Diagram Studio document, and how it relates to the
Foundation repository.

**AP-DS-002 update: the gap this document originally described is now
closed.** Everything below "The gap" and "The resolution" sections
describes the PRE-AP-DS-002 state (local-JSON-only persistence, no
Foundation write path) and is kept as an accurate historical record —
do not delete it, it documents a real, deliberate interim decision.
Foundation Runtime Engineering Repository integration now exists: see
`docs/architecture/diagram_studio/ENGINEERING_MAPPING.md` for the
object/relationship mapping, `docs/architecture/diagram_studio/
DOCUMENT_MODEL.md`'s AP-DS-002 update for the document-model
consequences, and `lib/diagram_studio/repository/
diagram_repository_service.dart` for the implementation. Local JSON
(`DiagramDocument`) is NOT removed — it remains the format legacy
documents are migrated FROM (see `MIGRATION_GUIDE.md`), and the
Autosave/Recovery mechanism built in AP-DS-001A still uses it for its
own local recovery file, which is a separate, still-valid concern from
the document's primary save/open path.

## The gap

Studio's Foundation C API surface (`oep_api.h`, consumed through
`lib/core/foundation/foundation_bridge.dart` +
`FoundationRuntimeNotifier`) has no "Save"/"Save As", no dirty-state
concept, and no schema at all for Diagram Layout, ViewState,
Annotations, Layers, or wire overrides — it only knows
`EngineeringObject`/`Relationship` plus an append-only audit log. This
is a genuine, load-bearing gap, not an oversight to route around
quietly: building real Foundation-backed diagram persistence would
require a Foundation-side schema change, and `oep_foundation` is
explicitly off-limits to this work package (read-only, never modify).

## The resolution: follow Knowledge Studio's own precedent

Knowledge Studio already resolved the identical tension. It keeps its
own content (Knowledge Curation Sessions) in separate, Studio-owned
persistence (`KnowledgeSessionStorage`) and treats the Foundation
repository as an independent, ambient thing you can have open at the
same time, not something a Knowledge Session is saved *into*.

Diagram Studio follows the same shape:

* **Diagram content** (Engineering Graph + Diagram Layout) persists via
  `DiagramDocument` (`lib/diagram_studio/host/diagram_document.dart`),
  built directly on the Engine's own already-serializable
  `EngineeringGraph.toJson()`/`fromJson()` and
  `DiagramLayoutState.toJson()`/`fromJson()` — the same SDD-025-
  sanctioned path used throughout WORK_PACKAGE_019–023's own Engine-only
  verification ("Engineering Engine shall operate without an open
  Repository where practical").
* **The ambient Foundation repository**, opened separately via the
  existing `FoundationRuntimeNotifier`, is available for future
  evidence/provenance display but is never what a diagram file is saved
  into. `DiagramDocument` never writes to it.

## The document file

One JSON file per diagram, containing **both** the graph and its layout
together — not two separate files, and not calling
`JsonFileSerializationProvider.write`/`JsonFileLayoutSerializer.write`
directly (each of those is hardcoded to own an entire file by itself).
`DiagramDocument` composes the same two already-serializable pieces
into one envelope itself:

```json
{
  "schemaVersion": 1,
  "graph": { ... EngineeringGraph.toJson() ... },
  "layout": { ... DiagramLayoutState.toJson() ... }
}
```

This is a deliberate, narrow piece of Studio-side glue — "Studio
orchestrates, Engine executes" — not a reimplementation of graph or
layout serialization; every byte of the actual serialization logic is
still `EngineeringGraph`/`DiagramLayoutState`'s own `toJson()`/
`fromJson()`.

### Why Graph + Layout together, but ViewState separately

A saved diagram is only meaningful if positions/wire overrides/layers/
annotations come back with it — that's the document's actual content.
ViewState (zoom/pan/grid/guides/constraints/theme), by contrast, is the
*current viewport* — genuinely ambient session state, not part of the
diagram's content, consistent with WORK_PACKAGE_022's own ViewState
philosophy ("a fifth, permanently separate runtime concern"). ViewState
is therefore restored via Workspace Persistence
(`docs/WORKSPACE_INTEGRATION.md`), not embedded in the document file.

## `DiagramDocument` API

```dart
class DiagramDocument {
  String? path;
  bool isDirty;

  Future<({EngineeringGraph graph, DiagramLayoutState layout})> open(String filePath);
  Future<void> saveAs(String filePath, EngineeringGraph graph, DiagramLayoutState layout);
  Future<void> save(EngineeringGraph graph, DiagramLayoutState layout); // requires an existing path
  void markDirty();
  void close();
}
```

`DiagramStudioPage` marks the document dirty on every mutating Engine
Command (any call that goes through `engine.editing.execute(...)`), and
prompts to discard unsaved changes before New/Open/Close when dirty.
File pickers use `package:file_selector` (`openFile`/`getSaveLocation`),
the same package `DashboardPage`'s own "Open Repository" flow already
depends on.

## What this does *not* attempt

* No Foundation schema changes.
* No "Save Diagram to Repository" — there is no Public C API surface
  for it yet (mirrors Knowledge Studio's own still-placeholder
  "Repository Matches" panel, which has the identical gap, documented
  in `docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural Observations).
* No attempt to synchronize the diagram document's dirty state with any
  Foundation-side concept — they are unrelated by design.
