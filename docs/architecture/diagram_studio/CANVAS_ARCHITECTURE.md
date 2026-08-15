# Diagram Studio — Canvas Architecture

**Architecture Phase:** AP-DS-001 (superseding update from AP-DS-001A below)

> **AP-DS-001A update.** The editor-completion phase closed the dual-source-of-truth risk named in §2 (`ViewState` is now authoritative, mirrored into `InteractiveViewer`'s transform controller), extended alignment guides to multi-node drags (§6), added viewport culling and `RepaintBoundary` adoption addressing §10's rendering-pipeline gaps, and added View reset + a coordinate-display overlay. The full-page `setState()`-per-drag-frame issue named in §10 was investigated but deliberately NOT fixed in AP-DS-001A — judged too risky without a drag-gesture test harness, which still does not exist. See `oep_studio/docs/IMPLEMENTATION_STATUS.md`'s AP-DS-001A section for verification detail. Sections below are left as originally written.

## 1. Viewport

Implemented via Flutter's `InteractiveViewer` with a `TransformationController` (`GraphViewPanel`, `oep_engine/lib/views/widgets/graph_view_panel.dart:134-141`): `minScale: 0.25`, `maxScale: 4`, `boundaryMargin: EdgeInsets.all(400)`, `constrained: false`, **`panEnabled: false`** (pan is handled manually — see §2).

## 2. Coordinate system

`Point2D`/`Rect2D` value types represent world/document (scene) coordinates. Screen↔scene mapping is delegated to `InteractiveViewer`'s transform matrix for zoom, but **pan is implemented manually**: `DiagramStudioPage._handleBackgroundPanUpdate` adjusts `ViewState.pan` directly, bypassing `InteractiveViewer`'s own pan gesture. Zoom/scale is read back out of the transform matrix post-hoc via `_syncViewStateFromTransform` (`matrix.getMaxScaleOnAxis()`/`getTranslation()`), called only on `onInteractionEnd`.

**This is a genuine, unresolved dual-source-of-truth**: Flutter's `Matrix4` (managed by `InteractiveViewer`) and the Engine's `ViewState.zoom`/`pan` are two independent values, reconciled only at gesture end, not continuously. Under a rapid, interrupted, or programmatic zoom/pan sequence, these two values can diverge before the next reconciliation point. No bug was confirmed live in this review, but the architectural risk is real and should be closed — either by driving `InteractiveViewer` entirely from `ViewState` (single source of truth) or by continuous (not just on-end) synchronization.

## 3. Infinite canvas

Effectively infinite in practice via `constrained: false` + a large `boundaryMargin`, not a literally unbounded coordinate space with special-cased rendering — there is no chunking/tiling system. This is adequate at current scale; see `PERFORMANCE_TARGETS.md` for what "current scale" means and what would need to change for it not to be.

## 4. Layers

`DiagramLayer` (visibility/lock/z-order grouping) is a real data model, with a dedicated panel (`diagram_layer_panel.dart`) and inspector (`diagram_layer_properties.dart`), and nodes can be assigned to a layer via `AssignLayerCommand`. **There is no dedicated z-order rendering pass** — nodes render in whatever order the underlying `scene.nodes` list iterates, not a layer-aware painter's-algorithm sort confirmed in the reviewed code. This should be verified/closed as a named item, not assumed correct.

## 5. Grid

Real, functional — not decorative. `GridPainter` draws grid lines; `GridComputer.computeLines(...)` generates them; `GridComputer.snap(...)` is actually used to snap drag results (both node moves and annotation drags), confirmed via direct call-site inspection.

## 6. Snap

Two independent snap systems, both real:
- **Grid snap** — `GridComputer.snap(...)`, applies whenever grid snapping is enabled, for both node and annotation drags.
- **Alignment guide snap** — `AlignmentGuideComputer.computeGuides(...)` (preview) + `.snapToGuides(...)` (commit), computed against sibling node bounding boxes. **Single-node-drag only** — multi-node drags receive grid snap but no alignment guide feedback. This asymmetry is a real, verified limitation, not a hypothetical.

## 7. Guides

Rendered via `CustomPaint(painter: GuidesPainter(...))`, driven by the same `AlignmentGuideComputer` output as §6. Functionally complete for the single-node case; absent for multi-node drags (see above).

## 8. Selection (canvas-facing)

Hit-testing: node hit-testing uses AABB math against a fixed `_nodeSize = 100` constant (not per-node actual bounds — worth flagging as a simplification that will need revisiting once variable-size nodes/resize exist); wire hit-testing uses `DiagramHitTesting.relationshipAt`; box-select uses `DiagramHitTesting.nodesInRect`. See `INTERACTION_MODEL.md` for the full selection semantics (multi-kind, additive/toggle modifiers).

## 9. Rendering pipeline

**Hybrid, not pure custom-paint.** `GraphViewPanel` is a `StatelessWidget` composing:
- `CustomPaint(painter: WirePainter(...))` — wires, full-list repaint every rebuild.
- `CustomPaint(painter: GridPainter(...))` — grid, conditional on visibility.
- `CustomPaint(painter: GuidesPainter(...))` — alignment guides.
- `CustomPaint(painter: ConnectionPreviewPainter(...))` — live connection-drag preview.
- Nodes — **not painted**; each is a `Positioned` + `SymbolNodeWidget` in a `Stack`, built via a `for` loop over `scene.nodes`, using Flutter's normal widget-tree diffing rather than canvas drawing.
- Annotations — same pattern, `Positioned`/widget-based, `for` loop over `annotations`.

This hybrid approach is a legitimate architectural choice (it lets nodes participate in normal Flutter widget behavior — hit-testing, semantics, hover — for free), but it has real performance consequences documented in §10 and `PERFORMANCE_TARGETS.md`.

## 10. Dirty-region rendering

**Does not exist.** No `RepaintBoundary` was found anywhere in `graph_view_panel.dart` (verified by reading the complete 269-line file). `WirePainter`/`GridPainter`/`GuidesPainter` each redraw their entire data set on every `CustomPaint` rebuild — there is no per-shape or per-region dirty tracking. The node/annotation `for` loops are unconditional full iterations with no viewport culling of off-screen items and no level-of-detail logic at any zoom level. Compounding this: essentially every pointer-move event during a drag calls `setState()` on the entire `_DiagramStudioPageState`, forcing a full rebuild of the node/annotation widget list and all four painters on every frame of every drag.

## 11. Performance targets

See `PERFORMANCE_TARGETS.md` — stated there as aspirational goals for a future phase, explicitly not a description of current measured behavior, since no benchmark of current canvas performance exists (no performance test suite was found anywhere in either package).

## 12. Summary

The canvas architecture is functionally complete for correctness (grid, snap, guides, selection, connection-drawing all genuinely work) and structurally sound for its hybrid rendering choice, but has **zero performance engineering** applied to date. This is the single most consequential finding for anything after Phase 1: any target object count materially larger than what's been manually tested during development risks visible frame-rate degradation, because every drag frame currently triggers a full-tree rebuild with no culling.
