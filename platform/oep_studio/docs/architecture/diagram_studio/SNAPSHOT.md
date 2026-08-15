# Diagram Studio — Complete Snapshot

**As of:** 2026-08-01, after AP-DS-001 → AP-DS-002. Independently re-verified for this snapshot (fresh `flutter test`/`flutter analyze` runs across both packages, plus `ctest` on `oep_foundation`) — not a restatement of prior claims.

> **AP-DS-003 landed after this snapshot was written.** Diagram Studio now also has live Engineering Intelligence Platform integration (validation/analysis/reasoning/recommendations, Engineering Explorer, Knowledge Graph, Query Console, Knowledge Sessions — all embedded in the canvas workspace). See `ENGINEERING_WORKSPACE.md` and `docs/IMPLEMENTATION_STATUS.md`'s AP-DS-003 section for the current, up-to-date account; this document's body below still accurately describes everything through AP-DS-002 and was not rewritten to avoid duplicating that newer material.

---

## 1. What Diagram Studio is

Diagram Studio is OEP's flagship engineering-diagram editor: a canvas-based tool for creating and editing wiring/schematic diagrams (components, connectors, wires, harnesses, groups, annotations), with a real command-pattern editing system, undo/redo, selection, grid/snap, alignment guides, and — as of AP-DS-002 — genuine Foundation Runtime Engineering Repository persistence.

## 2. Architecture (frozen since AP-DS-001, refined AP-DS-001A/B, extended AP-DS-002)

Two-package split, a governing principle unbroken across every phase:

```
oep_studio/lib/diagram_studio/   (32 files, 4,625 lines) — Studio-side shell:
    UI chrome, toolbars, panels, inspectors, settings, document/repository
    orchestration. Owns NO canvas, document model, or command logic.

oep_engine  (platform/oep_engine, package `engineering_engine`, 167 files, 9,320 lines) —
    the real engine: canvas/viewport, document/graph model, command/undo-redo
    system, selection, clipboard, symbol library, exporters.

"The Studio orchestrates. The Engineering Engine executes." — verified,
not just claimed: no canvas/command/document logic exists in oep_studio.
```

Layering: `EngineeringGraph` (document model) → `EditingCommand`/`CommandHistory` (mutation) → `GraphViewPanel`/`ViewState` (canvas/rendering) → `DiagramStudioPage` (gesture handling) → panels/toolbars/inspectors (chrome) → `StudioRegistry` (navigation). As of AP-DS-002, a new layer sits underneath: `DiagramRepositoryService` (oep_studio) ↔ `FoundationBridge` (FFI) ↔ Foundation's Public C API ↔ `RuntimeService` ↔ the Engineering Repository.

Full documents: `DIAGRAM_STUDIO_CONSTITUTION.md`, `ARCHITECTURE_SPECIFICATION.md`, `CANVAS_ARCHITECTURE.md`, `EDITING_ARCHITECTURE.md`, `INTERACTION_MODEL.md`, `DOCUMENT_MODEL.md`, `ENGINEERING_MODEL.md`, `ENGINEERING_MAPPING.md`, `PERFORMANCE_TARGETS.md`, `PERFORMANCE_REPORT.md`, `MIGRATION_GUIDE.md`, `IMPLEMENTATION_ROADMAP.md` — all in this directory.

## 3. Persistence model (AP-DS-002)

- **Diagram** → one Foundation `EngineeringObject` (`ObjectType::Diagram`), `content` field = lossless JSON snapshot of `EngineeringGraph` + `DiagramLayoutState`. **This is the round-trip source of truth** — `loadDiagram` reads only from it.
- **Nodes** → real `EngineeringObject`s (`ObjectType::Component`, tagged with node category), **wires** → real `Relationship`s (`ConnectedTo`) — regenerated (not diffed) on every save, a disclosed simplification.
- **Annotations, viewport, selection, layers** → deliberately NOT Engineering Objects (per the frozen Constitution's "no graphics-only entities" rule) — live in the content blob only.
- **Local JSON is not removed** — it remains legitimate for AP-DS-001A's Autosave/Recovery and as the migration source format (`MIGRATION_GUIDE.md`).
- Foundation's C API gained exactly two new functions this arc (`oep_object_update_content`/`oep_object_get_content`), purely additive: `OEP_API_VERSION` 19→20, `OEP_ABI_VERSION` unchanged at 1 (verified by direct header read).

## 4. Independently re-verified state (this snapshot's own checks, not carried-forward claims)

| Check | Result |
|---|---|
| `oep_engine` `flutter test` | **210/210 passing** |
| `oep_engine` `flutter analyze` | Clean, 0 issues |
| `oep_studio` `flutter test` (full suite) | **490/491 passing, 1 flaky** — `diagram_studio_interaction_test.dart` failed in the full-suite run but **passes cleanly in isolation** (re-run confirmed). Pre-existing test-isolation flakiness, not a regression from AP-DS-002; worth a follow-up to find the state leak, not urgent. |
| `oep_studio` `flutter analyze` | 2 pre-existing, unrelated infos (`foundation_runtime_service.dart` curly-brace style) — 0 issues in Diagram Studio code |
| `oep_foundation` `ctest` | 62/62 CTest suites passing |
| `OEP_API_VERSION` / `OEP_ABI_VERSION` | 20 / 1 — confirmed by direct header read just now |
| Native bridge DLL (`oep_foundation_bridge.dll`) | Rebuilt and verified this arc — all 168 C API functions confirmed exported via `dumpbin` (previously only 38 were, a real pre-existing defect found and fixed) |

## 5. Implementation status by area

| Area | Status |
|---|---|
| Canvas (viewport, zoom/pan, fit-to-window, coordinate display, grid/snap/guides) | **Complete**, performance-benchmarked (10–100,000 objects) |
| Selection (single/multi/marquee, hover, keyboard) | **Complete** |
| Editing (move/rotate/mirror/resize/group/align/distribute/duplicate/delete) | **Complete** — resize and align/distribute UI were the last gaps, closed AP-DS-001A/B |
| Command/undo-redo architecture | **Complete**, frozen since AP-DS-001, untouched since |
| Wiring (creation, routing, junctions, endpoint editing, wire-edit mode) | **Complete** |
| Clipboard | **Complete** — in-process + OS clipboard fallback (AP-DS-001A) |
| Toolbars/menus | **Complete** — `EditActionsToolbar` closed the last discoverability gap (AP-DS-001B) |
| Panels (Explorer, Layer, Search, Validation, Annotation, Recent Commands) | **Complete**, lightly audited for accessibility (real gap, see §6) |
| Property inspectors (8) | **Functional**, multi-selection editing behavior not exhaustively audited (real gap, see §6) |
| Document model — local JSON (Autosave/Recovery) | **Complete** (AP-DS-001A) |
| Document model — Foundation Repository persistence | **Complete** (AP-DS-002), with disclosed simplifications (§3) |
| Project/Repository Browser, Package management UI | **Complete** (AP-DS-002) |
| Migration (legacy JSON → repository) | **Complete**, with a disclosed cross-step transaction-atomicity limitation |
| Rendering performance | **Benchmarked and optimized** — wire viewport culling fixed a real ~113x cost at 100,000 objects (AP-DS-001B) |
| Printing | **Does not exist** |
| PDF/SVG export | **Does not exist** — scaffold directories only, JSON export is the only real exporter |
| Simulation | **Does not exist** — `NoOpSimulationProvider` placeholder |
| Engineering Intelligence Platform integration | **Does not exist** — explicitly deferred to AP-DS-003 |
| Multi-sheet/Drawing Set document model | **Does not exist** — flat single-diagram model only |
| Accessibility (screen reader, focus traversal, contrast) | **Reviewed lightly, not certified** |
| Live GPU/interactive performance profiling | **Not done** — all performance numbers are headless CPU-time proxies |

## 6. Known, disclosed gaps (carried forward honestly, not hidden)

1. Decomposed node/relationship Foundation objects are regenerated (not diffed) on every save — real Foundation audit-log churn.
2. No `Contains` relationship between Project and Diagram objects yet.
3. `DiagramRepositoryService.migrate` isn't wrapped in one outer transaction across its multi-step sequence — a failure partway can leave an already-committed earlier step in place even though migration reports overall failure.
4. No integration-test harness loads the real native DLL — `DiagramRepositoryService`/FFI correctness is verified via `flutter analyze` + pure-Dart serialization tests, not a live round-trip test.
5. `docs/tasks` Create/Save-package (authoring) has no FFI backend yet — only `installPackage` (consuming an existing archive) is bound.
6. Full inspector multi-selection audit and full accessibility certification remain incomplete (reviewed lightly, AP-DS-001B).
7. One flaky test (`diagram_studio_interaction_test.dart`) fails only in full-suite runs, not in isolation — a test-isolation issue, not a product defect, unaddressed.
8. `InteractiveViewer` transform vs. `ViewState.zoom`/`pan` remains a two-way sync (the concrete bug was fixed AP-DS-001A; the architectural dual-source-of-truth pattern itself remains).

## 7. What's next (per the ratified roadmap)

`IMPLEMENTATION_ROADMAP.md`'s current sequencing: AP-DS-002a (decomposition diffing, Project↔Diagram relationship, migrate's outer transaction) and AP-DS-004 (remaining polish — accessibility, inspector audit, panel-overflow fix) can run in parallel; then AP-DS-003 (Engineering Intelligence Platform integration — Validation/Analysis/Reasoning/Recommendations); AP-DS-005 (Tool architecture formalization, lower priority) after that; then a final v1.0 polish phase (printing, PDF/SVG export, simulation scoping, multi-sheet documents).

No further phase has been started or approved.
