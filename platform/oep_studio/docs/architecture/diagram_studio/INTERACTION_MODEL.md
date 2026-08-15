# Diagram Studio — Interaction Model

**Architecture Phase:** AP-DS-001. Documents actual, verified current behavior (`diagram_studio_page.dart`, `graph_view_panel.dart`), not aspirational design.

## 1. Interaction modes (as implemented, not as a formal Tool abstraction)

There is **no `Tool` interface** in the codebase. Every mode below is implemented as ad hoc state (nullable IDs, booleans, rects) directly on `_DiagramStudioPageState`. This is documented here as the frozen Phase 1 reality; `EDITING_ARCHITECTURE.md` names formalizing this as a named future-phase item.

| Mode | Trigger | Status |
|---|---|---|
| Select (single) | Click on node/wire | Implemented — real hit-testing (AABB for nodes, `DiagramHitTesting.relationshipAt` for wires) |
| Select (additive/toggle) | Shift/Ctrl + click | Implemented |
| Box-select | Drag on empty background | Implemented — `DiagramHitTesting.nodesInRect` |
| Move | Drag selected node(s) | Implemented — live preview + committed `MoveNodesCommand`, grid snap + single-node alignment guides |
| Connect | Drag from a port | Implemented — live validity feedback via `ConnectionValidator.canConnect` |
| Reconnect | Drag an existing wire endpoint | Implemented |
| Wire edit ("Edit Route") | Explicit mode toggle | Implemented — insert/remove/drag vertex or segment, minimum-length constraint enforced |
| Annotate | Add/drag/edit/delete annotation | Implemented |
| Pan | Manual pan handler (`InteractiveViewer.panEnabled = false`) | Implemented |
| Zoom | `InteractiveViewer` pinch/scroll, mirrored into `ViewState` on interaction end | Implemented |
| Rotate / Mirror | Command trigger (toolbar/context menu) on selection | Implemented — 90°/180°/arbitrary angle dialog |
| Array place | Dialog-driven | Implemented |
| Replace symbol | Command trigger | Implemented |
| Resize | Corner-handle drag → `ResizeNodeCommand` | Implemented (AP-DS-001A) — verified with a real drag gesture in `test/workflow/diagram_studio_interaction_test.dart` (AP-DS-001B) |

## 2. Selection semantics

Multi-kind selection (`GraphSelection`): separate id sets for nodes, relationships, groups, annotations, managed uniformly through `SelectionService`. Modifiers: Shift/Ctrl = additive, Ctrl on an already-selected item = toggle-off. Box-select computes rectangle intersection against node bounds. This is a real, complete, correctly-generalized selection model — not a per-entity-type special case.

## 3. Keyboard shortcuts (verified, `CallbackShortcuts` in `diagram_studio_page.dart`, AP-DS-001B audit)

Full inventory of the `CallbackShortcuts.bindings` map in `DiagramStudioPage.build()`:

| Shortcut | Action | Also reachable from a toolbar? |
|---|---|---|
| Ctrl+Z | Undo | Yes — Edit Actions group (added AP-DS-001B) |
| Ctrl+Y / Ctrl+Shift+Z | Redo | Yes — Edit Actions group (added AP-DS-001B) |
| Ctrl+C | Copy | Yes — Edit Actions group (added AP-DS-001B) |
| Ctrl+X | Cut | Yes — Edit Actions group (added AP-DS-001B) |
| Ctrl+V | Paste | Yes — Edit Actions group (added AP-DS-001B) |
| Ctrl+D | Duplicate selection | Yes — Edit Actions group (added AP-DS-001B) |
| Ctrl+S | Save | Yes — Document Bar |
| Ctrl+A | Select all | Yes — Selection group |
| Delete / Backspace | Delete selection | Yes — Edit Actions group (added AP-DS-001B) |
| Escape | Deselect all | Yes — Selection group |
| Ctrl+0 | Reset view | Yes — Navigation group |

No conflicts found (every binding is a unique `SingleActivator`). Gap closed by AP-DS-001B: prior to this phase, Undo/Redo/Cut/Copy/Paste/Duplicate/Delete — the most frequently used editing actions in the workspace — had keyboard shortcuts but **no toolbar affordance at all**, making them undiscoverable to a mouse-first or first-time user. `EditActionsToolbar` (`lib/diagram_studio/toolbars/diagram_toolbars.dart`) now surfaces all seven, each tooltip naming its shortcut, each button's enabled state mirroring the same guard the shortcut handler already used (`canUndo`/`canRedo`/`hasClipboardContent`/selection non-empty).

Remaining gap (not addressed — Studio-side only, not a `diagram_studio_page.dart` gesture-handler change, but also not "clearly simple" enough to add speculatively): Group/Ungroup, Rotate 90°/180°, Mirror, and Align/Distribute have no keyboard shortcuts, only toolbar buttons. Left for a future phase to avoid inventing shortcut conventions without design input.

## 4. Context menus, dock panels, navigation

Panels present and wired: Annotation, Explorer, Layer, Recent Commands, Search, Validation. Property inspectors: 8 entity-type-specific forms (annotation, layer, evidence-link, group, node, port, relationship, wire-override). Diagram Studio is registered through the same `StudioDestination`/`StudioRegistry` mechanism as every other Studio, confirmed reachable via normal navigation (not orphaned).

## 5. Multi-monitor behavior, accessibility

**Not independently verified in this review.** No multi-monitor-specific code path or accessibility semantics (screen-reader labels, focus traversal order, high-contrast handling) were found or excluded during this pass — this is a genuine documentation gap, not a claim that they don't exist. AP-DS-002 should include a dedicated accessibility audit; this document does not assert either "implemented" or "absent" for this item and should not be read as claiming full coverage above.

## 6. Known interaction gaps (from direct inspection)

- ~~Search results of kind `symbol`/`layer` are found but selecting them is a no-op~~ — **resolved** (AP-DS-001A): `_goToSearchResult` in `diagram_studio_page.dart` now handles both cases (selects every node using the symbol / every entity on the layer, and frames them).
- ~~Alignment guides only activate for single-node drags~~ — **resolved** (AP-DS-001A item 1): `_draggedGroupBounds` treats the whole selection as one rigid rectangle, so multi-node drags now get guide feedback identical to single-node drags. Verified with a real multi-select drag gesture in `test/workflow/diagram_studio_interaction_test.dart` (AP-DS-001B).
- ~~No resize interaction exists for any node type~~ — **resolved** (AP-DS-001A item 4), see the table above.
- Viewport transform (`InteractiveViewer`'s `Matrix4`) and `ViewState.zoom`/`pan` are two separate values reconciled only at gesture end (`onInteractionEnd`) — still open; a latent divergence risk under rapid or interrupted gestures, not confirmed as a live bug but architecturally worth closing.
- (AP-DS-001B) Undoing a node's creation does not clear a selection that referenced it — `GraphSelection.current.nodeIds` can end up pointing at an id no longer in the graph. Not user-visible today (`_syncPropertyInspectorSelection`'s node lookup miss degrades safely to clearing the Property Inspector), but `SelectionService` lives in `oep_engine`, out of this phase's scope — flagged for the engine-side team.
- (AP-DS-001B) Docked side panels (Layers/Search/Validation/Annotations/Recent Commands, `diagram_studio_page.dart` build()) are five `Expanded` children in one fixed-width `Column` with no minimum-height guard or scroll fallback — on a short window (observed under `flutter test`'s default 800×600 surface) this hard-overflows (`RenderFlex overflowed`) rather than degrading gracefully. Not reproduced at normal desktop window heights (verified fine at 1600×1000); worth a follow-up (e.g. wrapping the panel column in a `SingleChildScrollView` or making panels collapsible) before very small/tiled window layouts are a supported use case.
