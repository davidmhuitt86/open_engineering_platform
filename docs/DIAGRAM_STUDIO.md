# Diagram View (formerly "Diagram Studio Shell")

**This document does not describe Diagram Studio.** Diagram Studio is a
real, shipping Studio-side workspace in `oep_studio`
(`lib/diagram_studio/`, built in WORK_PACKAGE_024) — this repository
never implements it and may not be modified to do so. What follows is
(1) the View layer inside the Engineering Engine, which Diagram Studio
consumes via this package's public API exactly like the Demonstration
Host does, and (2) the Demonstration Host itself, now formally scoped to
regression testing, architectural validation, and Engine development
support only (ADR-023). See `docs/ARCHITECTURE_DECISIONS.md` ADR-003,
ADR-006, and ADR-023.

---

## The View layer (`lib/core/views/`)

The Engineering Graph is the single canonical center of the architecture.
A View is a stateless, read-only visualization of it:

```dart
abstract class EngineeringView<TScene> {
  String get id;
  String get displayName;
  TScene render(EngineeringGraph graph);
}
```

`Diagram View` (`lib/core/views/diagram/diagram_view.dart`) is the first
implementation. Sibling Views planned for later phases — Harness,
Diagnostic, Physical Layout, Simulation, Print — implement the same
contract as sibling folders under `lib/core/views/`, without the Graph or
existing Views changing.

### `DiagramView.render`

1. `DiagramLayout.compute` places every node on a deterministic grid
   (auto-layout is a rendering concern, not engineering knowledge —
   SDD-024 — so it's recomputed on every call, never stored on the graph).
2. Produces a `DiagramScene`: `DiagramNodeVisual`s (id, symbol id,
   position, selected/highlighted flags) and `DiagramWireVisual`s
   (relationship id, polyline points, selected/highlighted flags).
3. Returns plain Dart data — no `dart:ui`, no Flutter. Nothing is painted
   here.

### Renderer registration

`DiagramRendererRegistry` (`lib/core/views/diagram/diagram_renderer.dart`)
is a discovery point: a host registers a `DiagramSceneRenderer` (a marker
type) under an id, and can offer renderer selection. The Engineering
Engine never implements one itself — that would require Flutter, which
SDD-025/026 forbid in engine code.

## The Demonstration Host (`example/`)

A standard Flutter-package `example/` app — **not** Diagram Studio.
Consumes only `package:engineering_engine/engineering_engine.dart` and
exists solely to verify the engine end-to-end:

- Paints `DiagramView`'s scene: wires via a `CustomPainter`
  (`wire_painter.dart`), symbols via `flutter_svg` rendering each node's
  `SymbolDefinition.geometry.assetPath`, laid out with `Positioned` widgets
  inside an `InteractiveViewer` (pan/zoom).
- **Graph Explorer** — a list of nodes; tapping one calls
  `SelectionService.selectNode` and marks it selected on the graph so the
  canvas reflects it.
- **Property Inspector** — switches on `SelectionService.current` (node,
  relationship; port/symbol/group/evidence selection states exist in the
  model but aren't separately surfaced in Phase 1's UI).
- **Evidence Panel** — lists `evidenceLinks` on the selected node.
- **Validation Panel** — renders `ValidationService`'s report with a
  manual re-validate action.
- **Status Bar** — `EngineeringEngine.diagnostics()` (state, version,
  symbol count, open graph count).
- A "Highlight Battery → Ground" action demonstrates
  `NavigationService.highlightPathBetween`, which computes a path via
  `GraphTraversal.findPath` and emits a `NavigationEvent` the host uses to
  set `runtime.highlighted` on the affected nodes/relationships.

Seed data: `example/lib/seed_graph.dart` builds a small ignition-circuit-
shaped graph (battery → ignition switch → module → coil → lamp → ground,
plus a battery → ground return path) via `GraphBuilder`, written from
scratch for this demo — not copied from the reference implementation.

Verified by `example/integration_test/app_test.dart` on a real Windows
device: engine initializes, 14 symbols load, the seed graph renders,
tapping a node updates the Property Inspector, and the Validation Panel
reports clean.
