# Diagram Studio — Performance Targets

**Architecture Phase:** AP-DS-001 (superseding update from AP-DS-001B below)

> **AP-DS-001B update.** This document's original framing note ("no performance benchmark suite exists... every figure below is a target, not a measurement") is now partially superseded: a real benchmark suite exists (`oep_engine/test/performance/`), covering 10/100/1,000/10,000/100,000 objects, and one measured, justified optimization was performed (wire viewport culling, ~113x improvement at 100,000 objects — see `PERFORMANCE_REPORT.md` for full results and methodology). The targets below remain the aspirational acceptance criteria; `PERFORMANCE_REPORT.md` is now the authoritative source for what has actually been measured against them. Headline result: viewport-culled rendering stays bounded regardless of document size (confirmed, not assumed); a few object-model-layer operations (`sceneRender`, `select`, `propUpdate` proxies) still scale with total document size rather than viewport content — tracked as a known limitation, not fixed in this phase (see `PERFORMANCE_REPORT.md` §4/§6).

**Important framing note**: no performance benchmark suite exists anywhere in `oep_studio` or `oep_engine` for Diagram Studio (confirmed — no `benchmark`/perf-test files found in either package's `test/` tree during this review). Every figure below is therefore a **target for future work to hit and measure against**, not a report of current measured performance. Stating a target is not the same as claiming it is met — the current rendering path (see `CANVAS_ARCHITECTURE.md` §9–10) has no dirty-region redraw, no viewport culling, and rebuilds the entire node/annotation widget tree plus all four canvas painters on every pointer-move frame during a drag. These targets should be treated as the acceptance criteria for the performance-engineering work named in `IMPLEMENTATION_ROADMAP.md`, not as an existing SLA.

## Targets

| Target | Value | Rationale |
|---|---|---|
| Object count | 100,000 objects (nodes + relationships + annotations combined) on a single diagram without unusable degradation | Matches the scale named in the governing work package spec; large industrial wiring diagrams can reach this order of magnitude |
| Frame rate | 60 FPS sustained during pan/zoom and during single-object drag, at up to 10,000 visible objects in viewport | Matches the spec's named target; visible-in-viewport, not total document count, is the correct denominator once culling exists |
| Selection latency | Sub-100ms from click to visible selection-state update, regardless of total document size | Matches the spec's named target; today's fixed-`_nodeSize` AABB hit-test is O(1) per node and already cheap — the risk is elsewhere (full-tree rebuild on selection change), not hit-testing itself |
| Zoom responsiveness | Perceived-instant (no visible lag) at any zoom level between 0.25x–4x (the current `InteractiveViewer` range) | Matches current `minScale`/`maxScale` configuration — no change to the range is implied, only to how cheaply it renders |
| Loading | Lazy — a document should become interactive before its full object set is parsed/laid out, for large documents | Not currently implemented — today's `DiagramDocument.open()` reads and deserializes the entire JSON file synchronously before the page becomes usable |
| Redraw | Incremental — only changed/affected screen regions repaint on a single-object edit, not the full canvas | The single largest gap versus current behavior; requires `RepaintBoundary` adoption and/or per-shape dirty tracking in `WirePainter`/node widget tree |

## What would need to change to hit these targets (reported as roadmap input, not implemented in this phase)

1. **Viewport culling** — the unconditional `for` loops over `scene.nodes`/`annotations` in `GraphViewPanel` need to skip items outside the current visible rect before target object counts are safe.
2. **`RepaintBoundary` adoption** — currently absent everywhere in `graph_view_panel.dart`; needed to stop unrelated state changes from forcing full-painter repaints.
3. **Decouple drag-preview state from full-page `setState()`** — today, every pointer-move during a drag calls `setState()` on the entire `_DiagramStudioPageState`, rebuilding everything. A narrower state-notification scope (e.g. a dedicated `ValueNotifier`/`ChangeNotifier` for the drag-preview layer only) would let only the dragged node(s) and affected wires rebuild.
4. **Lazy document loading** — `DiagramDocument.open()` should support incremental/async parsing for large files rather than a single synchronous full-document decode.
5. **A real benchmark suite** — before any of the above can be verified as sufficient, a dedicated performance test (synthetic N-object diagrams, measured frame time under scripted pan/zoom/drag) needs to exist. None exists today.

## Explicit non-goal for this phase

This document sets targets and names the work required to reach them; it does not implement any of it, per the work package's "do not implement major new features" and "do not introduce architectural changes unless required to eliminate inconsistency" constraints. Viewport culling and `RepaintBoundary` adoption are *additive* performance work, not architectural redesign — they can be layered onto the existing hybrid rendering approach in `CANVAS_ARCHITECTURE.md` without changing it structurally, and are named here specifically so a future phase can scope them without re-deriving this analysis.
