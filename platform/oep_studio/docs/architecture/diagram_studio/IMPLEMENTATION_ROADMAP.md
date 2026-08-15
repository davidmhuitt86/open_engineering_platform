# Diagram Studio — Implementation Roadmap

**Architecture Phase:** AP-DS-001 (this document is its Deliverable #6, per the governing spec), updated after AP-DS-001A

## AP-DS-001A — Editor Completion & UX Refinement (complete)

Ran between this roadmap's original publication and the current update. Closed, verified via independent rebuild/test in this session: resize support (previously entirely absent), the `MoveNodeCommand`/`MoveNodesCommand` duplication (resolved by removing the unused command), `AlignNodesCommand`/`DistributeNodesCommand` UI wiring (previously unwired, now has real toolbar buttons), multi-node alignment guides (previously single-node-drag only), the `InteractiveViewer`/`ViewState` dual-source-of-truth bug named in `CANVAS_ARCHITECTURE.md` §2, View reset + coordinate display, an OS-clipboard fallback alongside the existing in-process clipboard, viewport culling + `RepaintBoundary` adoption, and — the largest completion item — Autosave/Recent Files/Recovery/document metadata for the document model, none of which existed before this phase. Full detail and verification evidence: `oep_studio/docs/IMPLEMENTATION_STATUS.md`, AP-DS-001A section.

**Deliberately deferred out of AP-DS-001A, carried forward below**: decoupling drag-preview state from full-page `setState()` (judged too risky without a drag-gesture test harness); a full icon-consistency/overflow/keyboard-accessibility audit of toolbars, menus, panels, and the 8 property inspectors (reviewed only lightly this phase); a dedicated performance benchmark suite; widget-level interaction tests for `diagram_studio_page.dart`'s gesture callbacks.

## AP-DS-001B — Professional UX & Performance (complete)

Closed 3 of the 4 items originally proposed for this slot, plus the full UX/accessibility/error-handling audit named in its own governing spec:
1. **Interaction test harness — built.** `oep_studio/test/workflow/diagram_studio_interaction_test.dart` drives real gestures (select, drag+undo, box-select, multi-select drag, port connect, resize, wire-edit mode, undo/redo depth) against observable state, not implementation details.
2. **Performance benchmark suite — built.** `oep_engine/test/performance/`, covering 10 to 100,000 objects across render/zoom/pan/select/wire-edit/property-update. Found and fixed a real ~113x rendering cost (unculled wire painting) and a real crash bug (`RepaintBoundary`/`Positioned` conflict) that the harness itself surfaced. Full results: `PERFORMANCE_REPORT.md`.
3. **Toolbar/UX audit — done.** Added `EditActionsToolbar` (Undo/Redo/Cut/Copy/Paste/Duplicate/Delete had shortcuts but zero toolbar affordance), documented the full keyboard-shortcut inventory, fixed a disabled-state icon inconsistency.
4. **`setState()` decoupling — evaluated, deliberately NOT done.** Per `PERFORMANCE_REPORT.md` §4: viewport culling already bounds any rebuild's widget-construction cost to the visible set regardless of document size, so the measured justification for this specific refactor doesn't hold. Left as an architectural inelegance, not a measured performance problem — reopen only with live-profiling evidence.

**Carried forward, not fully completed this phase** (see `IMPLEMENTATION_STATUS.md`'s AP-DS-001B section for full detail): a complete inspector multi-selection audit, a complete accessibility certification (screen-reader/contrast/focus-traversal — reviewed lightly, not exhaustively), and one newly-found layout bug (docked side panels hard-overflow at short window heights, not reproduced at normal desktop sizes).

This roadmap sequences the named gaps and debt items from the eight companion documents into proposed subsequent Architecture Phases and, within each, implementation work packages. It reflects the priority ordering implied by the Constitution's own principles (Foundation connection and Engineering Intelligence integration are the two biggest gaps between "what Diagram Studio is" and "what its governing spec says it should be") and by risk (performance debt compounds the longer it's deferred).

## AP-DS-002 — Engineering Repository Integration (complete)

Closed the highest-priority gap this roadmap had named since AP-DS-001: Diagram Studio is no longer a fully local, disconnected drawing tool. Delivered, in order:

1. **Foundation-side schema extension** (`oep_foundation`, additive only): `EngineeringObject` gained an opaque `content` field; `oep_object_update_content`/`oep_object_get_content` added to the Public C API (`OEP_API_VERSION` 19→20, `OEP_ABI_VERSION` unchanged at 1). Full C++ test coverage, 62/62 CTest suites verified passing.
2. **FFI bindings closed a real, separately-flagged gap**: `oep_object_update`/`oep_object_delete`/`oep_relationship_update`/`oep_relationship_delete` — present in the C API since Work Package 014 but never bound in Dart — plus the two new content functions, all now bound in `oep_api_bindings.dart`/`foundation_bridge.dart`.
3. **`DiagramRepositoryService`** (`lib/diagram_studio/repository/`) — the actual save/load/migrate implementation. Does NOT use `FoundationBridgePort` (that interface remains unimplemented, zero consumers, superseded as the intended mechanism — see `ENGINEERING_MODEL.md`'s AP-DS-002 update for why).
4. **Migration system** (`LegacyMigrator`/`DiagramRepositoryService.migrate`) with verification and a disclosed, real limitation around cross-step transaction atomicity — see `MIGRATION_GUIDE.md`.
5. **Repository/Project Browser, Package management UI** — built by a separate, parallel effort; 4 new UI files, 14 new tests, no regressions.
6. **A genuinely pre-existing, previously-undiscovered build defect fixed as groundwork**: the native `oep_foundation_bridge.dll` build (`native/foundation_bridge/CMakeLists.txt`/`.def`) had drifted badly — a stale module list (referencing a nonexistent `platform/exchange`) and a `.def` export table covering only 38 of the header's 168 functions. Both fixed and verified via a real MSVC rebuild (first successful rebuild of this DLL in the session's history) — all 168 functions now confirmed exported via `dumpbin`.

Full detail: `ENGINEERING_MAPPING.md`, `MIGRATION_GUIDE.md`, `IMPLEMENTATION_STATUS.md`'s AP-DS-002 section.

**Carried forward, disclosed, not blocking**: decomposed node/relationship objects are regenerated (not diffed) on every save; no `Contains` relationship between Project and Diagram objects yet; `migrate`'s multi-step sequence isn't wrapped in one outer transaction; end-to-end verification against a real repository requires a live `flutter run` (no integration-test harness loading the real DLL exists yet).

## AP-DS-003 — Engineering Intelligence Workspace (complete)

Connected Diagram Studio to `EngineeringIntelligencePlatform` for live Validation, Analysis, Reasoning, and Recommendations, per the governing spec. Full detail: `ENGINEERING_WORKSPACE.md`.

Delivered: `DiagramIntelligenceService` (the sole EIP entry point — zero engineering logic elsewhere in `oep_studio`), a debounced Foundation-sync path (`DiagramRepositoryService.syncForIntelligence`) that feeds EIP without depending on the still-open AP-DS-002 document-bar Save gap, a canvas validation/analysis overlay, and 5 embedded panels (Recommendation, Engineering Explorer, Knowledge Graph, Query Console, Knowledge Sessions) adapting the pre-existing read-only `lib/engineering_intelligence/` pages rather than reinventing their rendering. Selection stays synchronized bidirectionally between canvas and every panel via `objectIdFor`/`nodeIdFor`.

**Not resolved this phase, carried forward** (see `ENGINEERING_WORKSPACE.md`'s Known Limitations): the local structural `DiagramValidationPanel`/`oep_engine/core/validation` still coexists with EIP's `ValidationEngine` under a confusingly similar name — this phase did not merge or rename either, both remain real, separate systems; true cross-isolate async FFI dispatch was not attempted (responsiveness comes from debouncing, not parallelism); live EIP latency at interactive scale has not been profiled.

## AP-DS-004 — Engineering Publishing & Deliverables (complete)

**Naming note**: this slot was previously reserved in this roadmap for a "Remaining Polish" phase (accessibility/inspector/panel-overflow items carried from AP-DS-001B). The governing task spec `docs/tasks/AP-DS-004.md` assigned the AP-DS-004 id to "Engineering Publishing & Deliverables" instead — that phase is what actually ran and completed. The polish items originally slotted here are renamed and carried forward as **AP-DS-004a (proposed)** below, unchanged in content.

Delivered a complete publishing pipeline: professional PDF/SVG/PNG diagram export (true vector, not rasterized), print preview, six tabular engineering reports (BOM/Wire/Connector/Harness/Relationship/Engineering Object) with CSV/Markdown/PDF export, Validation and Reasoning reports sourced exclusively from the Engineering Intelligence Platform, title blocks and revision management, an Exchange readiness checklist (preparation only, verified no networking/upload code exists), and a minimal template-preset storage layer. Full detail: `PUBLISHING_AND_DELIVERABLES.md`.

**A real gap was found during independent verification and closed directly**: the diagram print-preview dialog existed and was unit-tested but had no reachable UI entry point — no "Print" tab existed in the Publishing Center dialog. Fixed by adding one, backed by the real `PdfExportProvider`, with a new test asserting the trigger is genuinely enabled, not just present.

**Not resolved this phase, carried forward** (see `PUBLISHING_AND_DELIVERABLES.md`'s Known Limitations): Drawing/Installation/Service "Package" deliverables remain bounded by the single-diagram document model (not true multi-sheet bundles); Page Setup and multi-sheet print modes; Connector Reports' node-level (not per-pin) connectivity; 100,000-object performance unbenchmarked; Symbol Library artwork not embedded in exported drawings (nodes render as a labeled box); Templates/Document Management beyond an unwired named-preset storage layer.

## AP-DS-004a (proposed) — Remaining Editor Polish

(Renamed from this slot's original "AP-DS-004" reservation — see the naming note above. Content unchanged.) Scope, all carried forward from AP-DS-001B (see `IMPLEMENTATION_STATUS.md`'s AP-DS-001B section for the full source list): complete the inspector multi-selection audit (only lightly reviewed); complete a real accessibility certification (screen-reader labels, contrast, focus traversal — reviewed lightly, not exhaustively, in AP-DS-001B); fix the docked-side-panel hard-overflow bug at short window heights (found but not fixed in AP-DS-001B, not reproduced at normal desktop sizes); lazy document loading for very large documents (named in `PERFORMANCE_TARGETS.md`, not yet attempted); a live GPU/DevTools-attached profiling pass to validate `PERFORMANCE_REPORT.md`'s headless CPU-time proxies against real frame time, and now also `PUBLISHING_AND_DELIVERABLES.md`'s own disclosed 100,000-object publishing performance gap.

Recommended to run alongside whatever phase addresses the AP-DS-002a items (decomposition diffing, Project↔Diagram relationship) — none of these are blocking, all are real, disclosed gaps worth closing before a v1.0 declaration.

## AP-DS-005 (proposed) — Tool Architecture Formalization

Scope: evaluate and, if justified, implement a formal `Tool` interface replacing the ad hoc mode-state fields on `_DiagramStudioPageState` (`EDITING_ARCHITECTURE.md` §8). Lower urgency than AP-DS-002–004 — every existing mode works correctly today; this is a maintainability investment, not a functional gap, and should only be prioritized ahead of the others if a near-term feature genuinely requires the extensibility a `Tool` interface would provide.

## Small, low-risk items

**Closed by AP-DS-001A/001B** (kept here, struck through, as a historical record rather than silently deleted): ~~Resolve `MoveNodesCommand`/`MoveNodeCommand` duplication~~ (resolved — dead command removed, AP-DS-001A); ~~Confirm `AlignNodesCommand`/`DistributeNodesCommand` UI triggers~~ (resolved — toolbar added, AP-DS-001A/B); ~~Fix no-op `SearchResultKind.symbol`/`.layer` handlers~~ (resolved, AP-DS-001A); ~~Extend multi-node drags to receive alignment guides~~ (resolved, AP-DS-001A); ~~Resolve `InteractiveViewer`/`ViewState` dual-source-of-truth~~ (resolved — `ViewState` made authoritative, AP-DS-001A; residual architectural two-way-sync risk still noted in `INTERACTION_MODEL.md` §6 but the concrete bug is fixed); ~~Add resize~~ (resolved, AP-DS-001A); ~~Add an OS-level clipboard path~~ (resolved, AP-DS-001A).

**Still open, not their own phase, fold into whichever future phase touches the relevant file first**:
- Document or consolidate the duplicate top-level/`core/`-nested directory structure in `oep_engine` (`ARCHITECTURE_SPECIFICATION.md` §4.1).
- Implement PDF/SVG export (currently `.gitkeep`-only scaffolding, `ARCHITECTURE_SPECIFICATION.md` §3) — bundle with printing if/when printing is prioritized, since both likely share a rendering-to-fixed-page-size code path.
- Fix the docked-side-panel hard-overflow at short window heights, found in AP-DS-001B (`IMPLEMENTATION_STATUS.md`'s AP-DS-001B section).
- Add keyboard shortcuts for Group/Ungroup/Rotate/Mirror/Align/Distribute (currently toolbar-only, gap named in `INTERACTION_MODEL.md` §3 by AP-DS-001B — deliberately not added speculatively without design input on shortcut conventions).
- Track the `EngineeringGraph` immutable-update O(n) scaling characteristic found in `PERFORMANCE_REPORT.md` §4 as a candidate for a future core-data-structure review.

## Explicitly deferred, no phase assigned yet

- **Printing** — does not exist at all; no phase above claims it. Should get its own scoping pass once PDF export exists, since printing likely reuses PDF page-layout logic.
- **Simulation** (electrical/hydraulic/mechanical/pneumatic) — `NoOpSimulationProvider` is the only implementation; real simulation integration is a large, separate body of work not sequenced here because this review did not have visibility into product priority for it.
- **Multi-sheet/Drawing Set/Project document hierarchy** — genuinely new document-model work (not a refinement of the current flat model), likely depends on AP-DS-002's Foundation schema work being done first so multi-sheet structure can be designed against real repository semantics rather than invented twice.
- **Accessibility and multi-monitor behavior** — not audited in this phase (`INTERACTION_MODEL.md` §5); needs its own dedicated audit before a phase can be scoped.

## Sequencing summary

```
AP-DS-001  — Architecture freeze                          [complete]
        ↓
AP-DS-001A — Editor Completion & UX Refinement             [complete]
        ↓
AP-DS-001B — Professional UX & Performance                 [complete]
        ↓
Diagram Studio declared ready for Foundation Runtime integration
        ↓
AP-DS-002  — Engineering Repository Integration            [complete]
        ↓
AP-DS-003 — Engineering Intelligence Workspace              [complete]
        ↓
AP-DS-004 — Engineering Publishing & Deliverables            [complete]
        ↓
AP-DS-002a (proposed) — decomposition diffing, Project↔Diagram
             `Contains` relationship, migrate's outer transaction  ─┐
AP-DS-004a (proposed) — remaining editor polish (accessibility,     │
             inspector audit, panel-overflow fix, publishing        ├─ can run in parallel
             100k-scale benchmarking — carried from AP-DS-001B/004) │
AP-DS-003a (proposed) — reconcile the two "validation" systems      │
             (local structural vs. EIP), live-EIP-latency            │
             profiling, cross-isolate async FFI evaluation          ─┘
        ↓
AP-DS-005 — Tool Architecture (lower priority — every mode already works; this is a maintainability investment, revisit if a near-term feature needs it)
        ↓
Diagram Studio v1.0 polish phase (printing, export completion, simulation scoping, multi-sheet documents — each to be individually scoped once reached)
```

This sequencing is a recommendation for approval, not a ratified schedule — it is submitted as the roadmap deliverable for review alongside the rest of this architecture-freeze package.
