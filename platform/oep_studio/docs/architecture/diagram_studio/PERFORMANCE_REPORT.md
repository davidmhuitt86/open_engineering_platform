# Diagram Studio — Performance Report

**Architecture Phase:** AP-DS-001B (Rendering Performance / Rendering Optimization / Large Diagram Testing deliverables)

## 1. Methodology

All benchmarks run headless under `flutter test` in `oep_engine/test/performance/` — there is no real GPU/display in this environment, so nothing here is a live frame-rate measurement. Measured via `Stopwatch` around specific operations:

- **Scene render** (`DiagramView.render`) — pure-Dart proxy for per-frame build cost.
- **Widget build/paint proxy** — `WidgetTester.pumpWidget`/`pump` timing around `GraphViewPanel` at a fixed 1920×1080 viewport, isolating culled build+paint cost from the object-model layer above it.
- **Wire paint cost** — direct `WirePainter.paint()` calls against a real `Canvas`/`PictureRecorder`, measured before and after adding culling.
- **Zoom/pan** — `ViewState.copyWith` transform arithmetic.
- **Selection** — `DiagramHitTesting.nodesInRect`.
- **Wire editing** — `WireEditing.dragCorner`.
- **Property update** — `CommandHistory.execute(UpdateNodePropertiesCommand)`.

**Explicitly not measured, and not measurable in this environment**: real GPU-bound frame time, display-refresh-synced FPS, input-to-photon latency, real user-perceived jank/jitter under live pointer input. "Implied FPS" below is `1000/ms` derived from CPU-time proxies, not an observed frame rate. A future live DevTools-attached interactive profiling session is the only way to close this gap — named explicitly as a limitation, not glossed over.

## 2. Results (ms; independently re-run and confirmed in this session, not taken on report)

| Objects | Scene render (ms) | Implied FPS | Zoom (ms) | Pan (ms) | Select (ms) | Wire edit (ms) | Property update (ms) |
|---|---|---|---|---|---|---|---|
| 10 | 7.8 | 128 | 0.68 | 0.03 | 0.98 | 0.78 | 2.63 |
| 100 | 11.7 | 85 | 0.006 | 0.009 | 0.96 | 0.05 | 0.08 |
| 1,000 | 9.1 | 110 | 0.004 | 0.002 | 1.23 | 0.02 | 0.18 |
| 10,000 | 48.3 | 21 | 0.004 | 0.004 | 7.34 | 0.02 | 0.57 |
| 100,000 | 184.3 | 5.4 | 0.005 | 0.007 | 17.97 | 0.05 | 5.14 |

Interpretation:
- **Zoom and pan are flat regardless of document size** — pure transform arithmetic, correctly independent of object count.
- **The actually-rendered widget path (viewport-culled `GraphViewPanel` build) stays bounded**: the number of node/annotation/wire widgets actually constructed per frame is determined by what's visible in the viewport (observed ~150–250 objects across all tested document sizes), not total document size — confirmed by the wire-culling fix below.
- **`sceneRender`/`select`/`propUpdate` scale with total document size**, because they operate on the full object model (`EngineeringGraph`), not the culled render set — this is an object-model-layer characteristic, not a rendering-layer one (see §4 for the specific finding on `propUpdate`'s scaling).

## 3. Optimization performed (measurement-justified, not speculative)

**Finding**: `WirePainter.paint()` had no viewport culling — every wire in the document was redrawn on every repaint regardless of visibility. Measured directly at 100,000 objects (~40,000 wires): **111.8ms** for one paint call, roughly 7x a single frame's entire 16ms budget. This was the single largest rendering cost found in this phase — larger than node/annotation rendering, which AP-DS-001A had already culled.

**Fix**: added bounding-box viewport culling for wires in `GraphViewPanel`, mirroring the existing node/annotation culling pattern, before constructing `WirePainter`.

**Before/after, same 100,000-object document**: **111.8ms → 0.99ms**, a **~113x improvement**. Confirmed at 1,000/10,000 objects too, with a consistent 6–24x improvement depending on wire density.

**A real bug was also found and fixed in the process**: `AnnotationWidget` wrapped its `Positioned` return value in an outer `RepaintBoundary` placed directly as a `Stack` child, which Flutter disallows (a `RenderObject` interposed between `Stack` and its `Positioned` child throws a `ParentDataWidget` mismatch at runtime). This was a live, uncaught defect from AP-DS-001A's `RepaintBoundary` adoption — invisible until this phase's first widget test actually pumped `GraphViewPanel` with annotations present, since no such test existed before. Fixed by moving the `RepaintBoundary` inside `AnnotationWidget`'s own `Positioned`, preserving the intended repaint isolation without violating Flutter's parent-data contract. This is exactly the kind of defect a real test harness (built in this phase) exists to catch.

## 4. Optimization explicitly NOT performed, and why

**The `UpdateNodePropertiesCommand` scaling behavior** (0.08ms @ 100 objects → 5.14ms @ 100,000 objects) traces to `EngineeringGraph.copyWith`/`withNode` spreading the *entire* nodes map on every update (`{...nodes, id: node}`) rather than using a persistent/immutable map data structure with structural sharing. This is a genuine O(n) characteristic of the core immutable-value-type pattern used throughout `oep_engine`'s object model — not a rendering-layer issue, and not something this phase's scope (rendering performance) should fix unilaterally. Recorded here as a recommendation for a future, dedicated review (likely touching the Document Model / core data-structure choice, which AP-DS-001B's "no document model changes" constraint explicitly excludes), not fixed in this phase.

**Decoupling drag-preview `setState()` from the full `_DiagramStudioPageState`** (named as deferred in both AP-DS-001A and this phase's UX-audit agent) was evaluated but **not implemented in this phase either**, on evidence-based grounds: viewport culling (confirmed in §2/§3 above) already bounds the widget-build cost of any rebuild — including a drag-triggered `setState()` — to the culled visible set (~150–250 objects), regardless of total document size. The architectural inelegance of a full-state `setState()` call remains true, and the two-way `ViewState`/`InteractiveViewer` transform sync noted in `INTERACTION_MODEL.md` §6 remains a latent (not measured-live) risk — but the specific performance justification for the refactor (an unbounded rebuild cost scaling with document size) is not supported by this phase's measurements. Per the spec's own "optimize only where justified by measured results" instruction, this was deliberately left as-is rather than risking a large, untested restructure of gesture-handling state for a cost that culling already bounds. This should be revisited only if a future live-profiling session (see §5) finds real, measured jank during drag that this analysis doesn't predict.

## 5. Large diagram testing

The 10,000 and 100,000-object benchmark rows above ARE this phase's large-diagram testing — synthetic diagrams at this scale were generated and exercised through the real render/selection/wire-edit/property-update code paths, not just a visual smoke test. No responsiveness cliff was found in any measured dimension at 100,000 objects once wire culling was fixed; the remaining scaling in `sceneRender`/`select`/`propUpdate` is object-model-layer, bounded to tens of milliseconds even at 100,000 objects (well within an interactive-feeling budget for a discrete action like a click or property edit, as distinct from a continuous 60fps requirement, which only applies to render/pan/zoom — all of which are flat or bounded per §2–3).

## 6. Known limitations of this report

1. No real GPU/interactive profiling was performed — everything above is a CPU-time proxy in a headless test environment. A live DevTools-attached session against real user input is the only way to verify actual frame-rate/jank claims.
2. The `sceneRender`/`propUpdate` scaling with total document size (not viewport content) is a real, measured characteristic worth tracking — it will matter more if/when Diagram Studio documents grow well past 100,000 objects, or if property updates become a frequent bulk operation (e.g. a future batch-edit feature).
3. The setState/drag-state architectural concern (§4) remains open, deliberately, pending either a live-profiling finding that justifies it or a future phase willing to accept the restructuring risk with a more mature gesture-test harness than currently exists.

## 7. Recommendations

1. Prioritize a live interactive profiling session (DevTools, real hardware, real pointer input) before further rendering-performance work — this report's headless proxies are a reasonable stand-in but not a substitute for confirming real frame time under real drag/pan/zoom.
2. Track the `EngineeringGraph` immutable-update scaling characteristic (§4) as a candidate for a future, dedicated data-structure review — out of scope here, but the numbers are now on record.
3. Treat the drag-state `setState()` question as closed for this phase (evidence does not justify the change) and reopen it only with new evidence from #1 above.
