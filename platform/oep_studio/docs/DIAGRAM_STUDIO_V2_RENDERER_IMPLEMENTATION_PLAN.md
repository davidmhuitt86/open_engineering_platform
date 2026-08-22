# Diagram Studio V2 Renderer Implementation Plan (AP-DIAGRAM-V2-001)

**Status:** Architecture/planning (AP-DIAGRAM-V2-001) complete; scene
adapter + parallel-renderer switch + canvas host infrastructure
(AP-DIAGRAM-V2-002) complete; V2 module/card rendering (AP-DIAGRAM-V2-003)
complete; V2 base wire renderer (AP-DIAGRAM-V2-004) complete; wire
color/label data-source resolution and V2 wire-label rendering
(AP-DIAGRAM-V2-005) complete; the Studio Wire Metadata Editor
(AP-DIAGRAM-V2-006 — **not itself a V2 renderer task**, a Property
Inspector feature that makes AP-DIAGRAM-V2-005's data source actually
writable) complete; the V2 connection-preview renderer (AP-DIAGRAM-V2-007
— visual rendering only, the existing wire-creation interaction system
remains fully authoritative) complete; V2 selection visual integration
(AP-DIAGRAM-V2-008 — module selection glow corrected to the real V2
`.mod-selected` rule; wire selection already correct; module/wire
*hover* deferred, no authoritative hovered-object identity exists
anywhere in OEP today) complete; V2 module port rendering and port-state
visuals (AP-DIAGRAM-V2-009 — port hover and active-wire-creation-source
states, the two port states with both real OEP data and a real V2 rule)
complete; V2 interaction-state visual integration (AP-DIAGRAM-V2-010 —
a full source-verified inventory of every V2 interaction visual against
existing OEP state, per §27; only the module-dragging visual had both a
real V2 rule and real OEP state, so it is the only new visual this task
added — box selection, resize, reconnect, and alignment guides do not
exist in V2 at all, and route-edit-mode handles were deliberately not
attempted, see §27) complete; V2 wire-edit model resolution
(AP-DIAGRAM-V2-011 — formal CASE C determination: V2's differential
route model is architecturally incompatible with OEP's absolute-point
model, empirically verified via a new node-movement test, §28) complete;
V2 wire-edit VISUAL reconstruction over OEP's existing absolute-route
model (AP-DIAGRAM-V2-012 — V2's handle/segment styling applied to OEP's
own unmodified wire-edit geometry and commands; V2's differential route
*semantics* remain deliberately unimplemented, per CASE C, §29) complete;
**real V2 canvas interaction** (AP-DIAGRAM-V2-013 — node tap/drag, port
hover/tap/drag, background tap for wire-select/deselect, all forwarded
to the exact same `DiagramStudioPage` handlers `GraphViewPanel` already
uses; the V2 canvas was visual-only through V2-012, so *nothing* on it
could actually be selected, dragged, or connected — this closes that
gap for the base interactions; wire-edit-mode dragging, box-select-drag,
reconnect, and resize remain visual-only, §30) complete; **V2 wire-edit
handle interaction** (AP-DIAGRAM-V2-014 — `V2WireEditOverlay`'s
handles are now draggable, forwarded to the exact same
`DiagramStudioPage` methods `WireEditHandles` already calls; OEP's
absolute-point route model, commands, and undo/redo are entirely
unmodified — AP-DIAGRAM-V2-011's CASE C stands, §31) complete — see
"Implementation status" and §§23–31 below. Wire routing/animation,
reconnect interaction, box-select-drag, resize interaction, module/wire
hover, overlays, minimap, legend remain unimplemented; those begin only
after separate authorization
(AP-DIAGRAM-V2-015+).

## Implementation status

| Item | Status | Where |
|---|---|---|
| Studio Diagram Scene Adapter | **Done** | `lib/diagram_studio/renderer/scene/studio_diagram_scene.dart`, `diagram_scene_adapter.dart` — pure translation of the frozen Engine `DiagramScene` into Studio's own `StudioDiagramScene`/`StudioSceneNode`/`StudioSceneWire`/`StudioScenePort`; no Flutter imports, no fabricated fields |
| Canvas host | **Done** | `lib/diagram_studio/renderer/canvas/v2_canvas_host.dart` — `V2CanvasHost`, reuses the page's existing `TransformationController` (no second viewport model); as of V2-003 renders real `V2ModuleCard`s, plus a lightweight bounds/origin diagnostic layer underneath |
| Coordinate system | **Done** | `lib/diagram_studio/renderer/canvas/scene_coordinate_transform.dart` — pure `sceneToScreen`/`screenToScene` functions, unit-tested (round-trip, zoom, pan, zero-zoom guard); card placement itself uses plain scene-space `Positioned` inside `InteractiveViewer`, same approach the current renderer already uses, so the standalone transform functions remain available for future non-widget-tree consumers (hit-testing) without being a second transformation system |
| Renderer switch | **Done** | `_useV2CanvasDev` (`diagram_studio_page.dart`), a plain non-persisted `State` field; UI entry point is a `kDebugMode`-gated toggle button at the canvas's bottom-right; default `false` (current renderer) |
| Current renderer preserved | **Done** | `GraphViewPanel`/`SymbolNodeWidget`/`WirePainter`/every other Engine renderer widget: byte-for-byte unmodified (verified via `git status platform/oep_engine/` — clean) |
| **V2 module/card renderer** | **Done** (AP-DIAGRAM-V2-003; selection glow corrected AP-DIAGRAM-V2-008) | `lib/diagram_studio/renderer/canvas/v2_module_card.dart` — one `V2ModuleCard` widget per node (Flutter widgets, not `CustomPainter` — text/label/future-hit-testing needs favored widgets, matching the current renderer's own choice); card body, category stripe, module label, symbol icon, port dots, selection glow all implemented; live-verified against the running application |
| **V2 module selection glow, corrected** | **Done** (AP-DIAGRAM-V2-008) | `node.selected` now renders V2's real `.mod-card.mod-selected` cyan triple-layer glow (`#22d3ee` ring + translucent halo + soft blur) instead of the amber `.mod-card.wire-selected` glow V2-003 originally (incorrectly) applied there — those are two distinct V2 CSS rules for two distinct situations; see §25 |
| **V2 wire selection glow** | **Done, unchanged** (verified AP-DIAGRAM-V2-008, first implemented AP-DIAGRAM-V2-004) | Re-checked `V2WirePainter` against `drawWires()`'s `isSel` treatment — already an exact match (amber `#f59e0b`, 8px, 0.4 opacity glow, 2.6px stroke); no correction needed |
| **V2 module/wire hover** | **Deferred, not implemented** (AP-DIAGRAM-V2-008) | No authoritative hovered-*node*/hovered-*wire* identity exists anywhere in OEP today — only port-level hover (`ViewState.hoveredPort`, `SymbolNodeWidget`'s per-port `MouseRegion`); confirmed by exhaustive grep across both `oep_engine` and `oep_studio`. V2's own `css/main.css` also has no `.mod-card:hover`/wire-hover CSS rule to reproduce even if OEP had the identity. Per this task's own instruction, no new hover-object identification or hit-testing architecture was created to manufacture one — see §25 |
| Port position | **RESOLVED** (corrects V2-002's classification) | `StudioScenePort.x`/`.y`, resolved in the adapter via the *same* `SymbolProvider.resolve(...).ports` → `fallbackPorts(...)` lookup the current renderer and the page's own drag-anchor code already use — see §14 for the full correction |
| Card shape/type | **Partially resolved** | Only V2's *standard* card family is implemented (all nodes); V2's `bulb`/`connector` shape variants are deliberately not implemented this pass — see the updated §14 |
| **V2 base wire renderer** | **Done** (AP-DIAGRAM-V2-004) | `lib/diagram_studio/renderer/canvas/v2_wire_painter.dart` — a `CustomPaint`/`CustomPainter` (`V2WirePainter`), painted in `V2CanvasHost`'s `Stack` beneath the module-card layer (matches the current renderer's own `WirePainter`-before-`SymbolNodeWidget` layering, `graph_view_panel.dart`); draws `StudioSceneWire.points` as-is (existing OEP absolute point lists, no route-model reinterpretation); styling ported from V2's own `drawWires()`/`css/main.css`: 1.6px base stroke / 2.6px selected, round caps/joins, an 8px 0.4-opacity amber selection glow underneath |
| **Wire color/label data-source resolution** | **Done, RESOLVED** (AP-DIAGRAM-V2-005, corrects the V2-002 through V2-004 UNRESOLVED classification) | `EngineeringRelationship.metadata['wireColor']`/`['label']` are real, already-established Engine metadata keys — `oep_engine/lib/core/publishing/reports/wire_report.dart` (AP-DS-004, a shipped feature) already documents and reads them as "well-known keys" for the Wire List report. That report's own doc comment discloses nothing currently populates them through any Studio UI, so in practice both resolve to blank/`null` for every real document today — a real, honest gap, not a missing convention. See §14 for the full correction and the separate `DiagramAnnotation(type: wireLabel)` mechanism this is deliberately *not* conflated with |
| **V2 wire label rendering** | **Done** (AP-DIAGRAM-V2-005) | `V2WirePainter` now draws a label (matching V2's `drawWires()` box/text styling exactly) sourced from `label ?? colorCode`, only when the wire is `selected` (V2 never shows a wire label otherwise), anchored at the midpoint of the wire's longest horizontal segment — `wireLabelAnchor()`, reproducing V2's own `route()` `lp` computation verbatim — falling back to the endpoint midpoint when no horizontal segment exists. Renders nothing today for any real document (see above), by design, not a bug |
| **Wire stroke color** | **Partially resolved** (AP-DIAGRAM-V2-005) | `resolveWireStrokeColor()` parses only a literal `#RRGGBB`/`#AARRGGBB` hex string from `colorCode` — a standard, universal format, not invented. Any other value (including a color *name*, which is what V2's own reference data actually uses via its `HEX` lookup table) falls back to the neutral `#888` default, since no name-to-color vocabulary exists anywhere in OEP and inventing one would fabricate visual meaning the data doesn't carry |
| **Studio Wire Metadata Editor** | **Done** (AP-DIAGRAM-V2-006 — a Property Inspector feature, not a V2 renderer task) | `lib/diagram_studio/inspector/engineering_relationship_properties.dart` — Wire Label/Wire Color `TextField`s on the relationship Property Inspector, writing `metadata['label']`/`['wireColor']` via the existing, previously-unused `UpdateRelationshipPropertiesCommand` (`oep_engine`, ENGINE-TASK-000085) through a new thin `DiagramStudioController.updateRelationshipMetadata()` wrapper — same centralized command/undo/dirty/Intelligence-sync pathway every other Diagram Studio edit already uses. See §23 for the full account |
| **V2 connection preview** | **Done** (AP-DIAGRAM-V2-007 — visual rendering only) | `lib/diagram_studio/renderer/canvas/v2_connection_preview_painter.dart` — `V2ConnectionPreviewPainter`, driven purely by the *existing* `_connectFromPort`/`_connectionCurrentPoint`/`_connectionValid` fields already authoritative for the current renderer's own `ConnectionPreviewPainter`; styling ported from V2's own preview `<line>` (cyan `#0891b2`, 1.5px, `6 3` dash, round cap — hand-drawn since `Canvas` has no native dash support), painted in the same wire layer as static wires (beneath cards), matching the V2 reference's own DOM ordering. See §24 for the full account, including the documented valid/invalid color adaptation (V2's own preview has none) |
| **V2 port rendering — position/border correction** | **Done** (AP-DIAGRAM-V2-009) | Port border corrected from V2-003's white to V2's real `.t-dot` value (`1.5px solid #0d0d0d`); position/size (7x7, `StudioScenePort.x/y * node.width/height`) already correct, unchanged. Fill color remains the existing Studio direction-based palette (`v2PortColor`) — V2's own fill (`background:h(t.c)`, a per-terminal wire-color code) has no OEP data source, see §26 |
| **V2 port state visuals** | **Done** (AP-DIAGRAM-V2-009) | `_V2PortDot` (`v2_module_card.dart`) — active wire-creation-source port (V2's `.wf`: cyan glow, scale 1.6) and hovered-port-during-a-pending-connection (V2's `.wh`: green glow, scale 1.5), sourced from the existing `_connectFromPort`/`ViewState.hoveredPort`; plain hover with no pending connection gets V2's unconditional `.t-dot:hover` scale-only treatment. See §26 for the full source/precedence account and why module/wire hover and a "selected port" state were *not* added |
| **V2 module dragging visual** | **Done** (AP-DIAGRAM-V2-010) | `V2ModuleCard.dragging` — V2's `.mod-card.dragging` (elevated shadow, 0.92 opacity), sourced from the existing `_dragNodeIds` (`node.id` membership). The only new Category-B interaction visual this task found — see §27 for the full inventory of every other interaction visual investigated and why each was deferred/not-present/out-of-scope |
| **Wire-edit model resolution** | **Done — CASE C** (AP-DIAGRAM-V2-011) | Formal determination that V2's differential per-segment-offset route model is architecturally incompatible with OEP's absolute-point model. Empirically verified (not just source-read) via `diagram_studio_wire_route_model_test.dart`: moving a connected node leaves a manually-routed wire's stored override points byte-for-byte unchanged. No Studio shadow route model was introduced. See §28 |
| **V2 wire-edit visual overlay** | **Done** (AP-DIAGRAM-V2-012 — V2 visual language over OEP's own unmodified route semantics) | `lib/diagram_studio/renderer/canvas/v2_wire_edit_overlay.dart` — `V2WireEditOverlay`, a `CustomPainter` reading only the existing `_wireEditWorkingPoints`/`_wireEditSelectedVertex`/`_wireDragCornerIndex`/`_wireDragSegmentIndex`; renders V2's segment highlight/handle styling (`#22d3ee` active, `rgba(34,211,238,.35/.7)` inactive) over OEP's real absolute-point geometry, plus a documented, deliberate extension of that same palette onto OEP's own vertex-handle concept (which V2 has no equivalent for). No new state, no hit-testing, no route-model change. See §29 |
| **V2 canvas interaction** | **Done** (AP-DIAGRAM-V2-013) | `V2ModuleCard`/`_V2PortDot`/`V2CanvasHost` gained real `GestureDetector`/`MouseRegion` wiring, all forwarded to the *exact same* `DiagramStudioPage` handlers `GraphViewPanel` already calls (`_handleNodeTap`, `_handleNodeDragStart/Update/End`, `_handlePortHoverEnter/Exit`, `_handlePortTap`, `_handlePortDragStart/Update/End`, `_handleBackgroundTap`) — no new selection/drag/wire-creation logic. Fixed a real bug caught by this task's own tests: the diagnostic and static-wire `CustomPaint` layers had no `IgnorePointer`, silently absorbing every tap before it could reach anything beneath them. See §30 |
| **V2 wire-edit handle interaction** | **Done** (AP-DIAGRAM-V2-014) | `V2WireEditHandles` (`v2_wire_edit_overlay.dart`) — real `GestureDetector`s (10x10 corner, 8x8 midpoint, sizes/split copied verbatim from `WireEditHandles`), forwarded to the *exact same* `_handleWireVertexTap`/`_handleWireCornerDragStart/Update/End`/`_handleWireSegmentDragStart/Update/End`. OEP's absolute-point route model, `SetWireRouteCommand`, undo/redo entirely unmodified — AP-DIAGRAM-V2-011's CASE C stands. See §31 |
| Wire routing/animation, reconnect/box-select/resize interaction | **NOT started** | Reconnect, box-select-drag, resize, dynamic routing algorithms, flow animation, and module/wire hover remain visual-only or unimplemented — next task's scope (AP-DIAGRAM-V2-015+) |
| V2 other systems | **NOT started** | minimap, legend, annotations, intelligence overlays, meter, route editor, module editor, V2 toolbar/sidebar/inspector — all untouched |

**AP-DIAGRAM-V2-003 correction to the port-position data gap (§14
below, superseding the V2-002 entry):** the V2-002 classification was
wrong. It looked only at `Port` (the graph model, genuinely
position-less) and concluded port position was UNRESOLVED. In fact the
*current, frozen* renderer already resolves real port geometry from a
different, already-public source — `SymbolPort.x`/`.y`
(`oep_engine/lib/core/symbols/models/symbol_port.dart`, normalized
`0..1` within the node's bounds), obtained via
`engine.registry.symbols.resolve(node.symbolId).ports`, falling back to
the public `fallbackPorts(node.ports, exit:)` helper
(`oep_engine/lib/core/views/diagram/fallback_port_layout.dart`) when a
symbol has no authored geometry. This is the *exact* lookup
`GraphViewPanel._portsFor` (Engine) and `DiagramStudioPage`'s own
drag-anchor/wire-endpoint code (`diagram_studio_page.dart:1671-1672`,
Studio) already both perform — the scene adapter now reuses it
verbatim (an optional `symbols:` parameter on `adaptDiagramScene`), so
V2 port positions can never silently drift from what the current
renderer and the page's own interaction code already agree on. **Port
position is RESOLVED, not a blocking gap.**

**Authority:** `docs/DIAGRAM_STUDIO_RECONSTRUCTION_AUDIT.md` (AP-DIAGRAM-001),
`docs/DIAGRAM_STUDIO_V2_RECONSTRUCTION_SPEC.md` (AP-DIAGRAM-000), and
`docs/DIAGRAM_STUDIO_COMPOSITION_BOUNDARY.md` (AP-DIAGRAM-W2). Terminology
below follows the Reconstruction Spec's own vocabulary; where this
document and those disagree, those win (per the Composition Boundary
document's own precedent).

**Baseline:** Wave 2 Stages A–D1 complete, Stage E inventory complete,
Stage E1 (bounded canvas rebuild-scope optimization) complete. This is
the frozen starting point for everything below.

---

## 1. Purpose

Diagram Studio's current UI is the pre-Wave-2 chrome (composition
boundary §11.5's monolith, partially decomposed by Waves 1–2). The
Reconstruction Spec's mandate is to rebuild the *presentation* layer —
canvas host, chrome, panels, interaction routing — to match the Wiring
Simulator V2 reference implementation
(`reference/legacy_wiring_sim_v2/eke-wiring-sim/`) visually and
behaviorally, while the *engineering* layer (commands, document,
session, selection, routing, simulation, instruments, persistence)
stays exactly as Waves 1–2 left it. This document is the bridge between
"Wave 2 is done" and "V2 renderer implementation can safely begin": it
establishes exactly what renders today, exactly what V2 requires, and
exactly how the two will connect, without writing any of that renderer
code yet.

## 2. Current renderer architecture

The current diagram canvas is **not Studio-owned**. Every pixel of the
diagram itself (nodes, wires, selection glow, hover, connection/reconnect
previews, resize handles, grid, guides) is painted by Flutter widgets
that live inside the **frozen Engine package**, `platform/oep_engine/`,
under `lib/views/widgets/`:

| Widget | File | Lines | Renders |
|---|---|---|---|
| `GraphViewPanel` | `graph_view_panel.dart` | 469 | The canvas host itself — lays out node/wire widgets, owns all gesture routing (drag/resize/connect/reconnect/route-edit/box-select/hover callbacks), composes every painter below into one `Stack`. |
| `SymbolNodeWidget` | `symbol_node_widget.dart` | 378 | One node's visual card — symbol art, category color, ports, selection/highlight ring. |
| `WirePainter` | `wire_painter.dart` | 33 | `CustomPainter` drawing one wire's polyline. |
| `AnnotationWidget` | `annotation_widget.dart` | — | Text/shape annotation rendering. |
| `ConnectionPreviewPainter` | `connection_preview_painter.dart` | — | The in-progress "drag from port A toward pointer" preview line. |
| `WireEditHandles` | `wire_edit_handles.dart` | — | Vertex/segment handles in wire-edit mode. |
| `ResizeHandles` | `resize_handles.dart` | — | Node resize-handle glyphs. |
| `ReconnectHandle` | `reconnect_handle.dart` | — | The draggable endpoint glyph during a reconnect gesture. |
| `GridPainter` | `grid_painter.dart` | — | Canvas background grid. |
| `GuidesPainter` | `guides_painter.dart` | — | Alignment-guide lines during node drag. |
| `OriginIndicator` | `origin_indicator.dart` | — | Scene-origin marker. |

`Diagram Studio` (`platform/oep_studio/lib/diagram_studio/workspaces/diagram_studio_page.dart`)
does **not** paint the diagram itself. It:
1. Calls `engine.diagramView.render(graph, layout, routing, symbols)` →
   a `DiagramScene` (pure data, §6 below).
2. Passes that `DiagramScene` into `GraphViewPanel` as a prop, along with
   ~30 gesture callbacks (`onNodeTap`, `onNodeDragUpdate`,
   `onWireCornerDragUpdate`, `onHover`, etc.) that `GraphViewPanel`
   invokes; the callbacks live in the page (Stage E inventory: Class C
   interaction state), and mutate page-local `State` fields that feed
   back into the *next* `DiagramScene` (selection, drag preview) or into
   Controller calls (committed mutations).
3. Renders its own chrome — toolbars, panels, sidebars, the coordinate
   readout, the minimap, the legend, the meter — entirely in Studio-owned
   widgets, separate from the canvas.

So today's rendering split is: **canvas interior = Engine-owned,
everything around the canvas = Studio-owned.**

## 3. Current renderer ownership

| Layer | Owner | Frozen? |
|---|---|---|
| Canvas host, node/wire/handle painters | `oep_engine/lib/views/widgets/` | **Yes** — do not modify, per this task and every prior Wave 2 stage |
| `DiagramScene` construction (`DiagramView.render`) | `oep_engine/lib/core/views/diagram/` | **Yes** |
| Gesture *routing* (which callback fires) | `GraphViewPanel` (Engine) | **Yes** |
| Gesture *handling* (what the callback does) | `DiagramStudioPage` (Studio) | No — Stage E territory |
| Chrome around the canvas (toolbars/panels/sidebars/minimap/legend/meter) | `DiagramStudioPage` and sibling Studio widgets | No |
| Document/tab/persistence/dirty-state | `DiagramStudioController` + providers (Stages A–D1) | No |

## 4. V2 renderer architecture (as it actually exists in the reference source, not as its own file layout implies)

The reference repository's own `docs/architecture.md` documents a
**four-phase plan**, and the actual source is mid-Phase-1: the
`diagram/` directory's *file names* (`module-renderer.js`,
`wire-renderer.js`, `viewport.js`, `label-renderer.js`) exist, but each
is a **16–24 line placeholder** whose entire body says "logic lives in
`renderer.js` (Phase 1); extraction is a Phase 2 goal" (verified by
reading each file directly, not assumed from the directory listing).
The actual, working V2 renderer is one file:

**`js/diagram/renderer.js`** (~360 lines) — everything: color-code
tables (`CAT_CLR`/`HEX`/`CNAMES`), module-card DOM construction
(`buildCard`/`buildStdCard`/`buildBulbCard`/`buildConnCard`), card
placement (`placeCards`), pan/zoom/pinch (`applyT`/`zBy`/`zReset`,
mouse+touch listeners), the minimap, wire routing (`route`, an
orthogonal-routing algorithm with per-segment manual override support),
wire drawing (`drawWires` — selection glow, bi-color stripe, route-edit
segment handles, wire-hit zones, labels, meter-lead dots), and the flow
(current-direction) animation (`requestAnimationFrame` dash-offset
loop).

Around that monolith, these files **are** real, separately-owned
implementations (verified by line count and content, not just header
comments):

| File | Lines | Real responsibility |
|---|---|---|
| `js/editor/module-editor.js` | 319 | Module drag, add/delete/edit, module property modal |
| `js/editor/wire-editor.js` | 152 | Wire-mode click-to-connect, wire deletion, wire property modal |
| `js/diagram/path-highlighter.js` | 82 | Power-path/ground-path trace highlighting |
| `js/editor/routing-editor.js` | 44 | Route-edit mode: segment select, arrow-key nudge, reset |
| `js/editor/selection-manager.js` | 30 | Single source of truth for wire/module selection, card highlight classes |
| `js/models/module.js`, `wire.js`, `terminal.js`, `connector.js`, `fault.js` | — | Pure data model, no DOM (per the repo's own layer-boundary table) |
| `js/utils/colors.js`, `geometry.js` | placeholder headers, but real constant tables/helpers duplicated at the top of `renderer.js` today | Color/geometry helpers, not yet extracted out of the monolith |

**Implication for the migration plan (§13):** OEP's V2 renderer must be
built from the *behavior* documented in `renderer.js` and the real
editor files above, not from a directory structure that mirrors V2's
*aspirational* file layout — V2 itself hasn't finished that extraction.

## 5. Engine renderer boundary (frozen, unconditional)

Confirmed unconditionally frozen for this entire reconstruction, per
every authoritative document and every prior Wave 2 stage:

```
DiagramDocument / DiagramScene
        ↓
Studio renderer adapter/model      ← NEW, Studio-owned, this plan's subject
        ↓
Studio-owned V2 renderer            ← NEW, Studio-owned, this plan's subject
        ↓
Flutter canvas/widgets
```

`platform/oep_engine/lib/views/widgets/*` and
`platform/oep_engine/lib/core/views/diagram/*` are **not modified,
refactored, or adapted** by this plan or by the V2 renderer
implementation that follows it. The new renderer is a **parallel,
Studio-owned replacement** that consumes the same `DiagramScene`/Engine
services the current renderer consumes — it does not extend, wrap, or
depend on `GraphViewPanel`/`SymbolNodeWidget`/`WirePainter` internals.

## 6. `DiagramScene` contract (exact, current)

`oep_engine/lib/core/views/diagram/diagram_scene.dart` (88 lines, read
in full):

```dart
class DiagramNodeVisual {
  String nodeId; String? symbolId; Point2D position;
  double width, height; bool selected, highlighted;
  String displayName; NodeCategory category;
  List<Port> ports; Map<String, Object?> metadata;
}

class DiagramWireVisual {
  String relationshipId; List<Point2D> points;
  bool selected, highlighted;
}

class DiagramScene {
  List<DiagramNodeVisual> nodes; List<DiagramWireVisual> wires;
  double contentWidth, contentHeight;
}
```

This is deliberately lean (SDD-025/026: "pure data — no drawing occurs
here"). It does **not** include: wire color, wire label text, annotation
geometry, layer visibility, selection-adjacent UI state (hover, drag
preview), or ViewState (zoom/pan/grid/guides) — those are supplied
separately by Studio at render time or read directly from
`EditingSession`/`ViewState` by the page. This is a real, pre-existing
architectural decision (not a gap): `DiagramScene` is a *render pass
snapshot*, and Studio is expected to enrich it with UI-only concerns
before painting, exactly as `DiagramStudioPage` already does for
selection (passed in from `GraphSelection`, not from `DiagramScene`
itself) and annotations (read from `session.layout.annotationOf`, not
from `DiagramScene`).

## 7. V2 reference renderer mapping

See §4 for which V2 files are real vs. placeholder. The behavior
actually implemented, extracted from source (not screenshots):

- **Card construction** (`buildCard`/`buildStdCard`/`buildBulbCard`/`buildConnCard`):
  three card *shapes* keyed off `module.bulb`/`module.connector` flags —
  standard terminal-strip card, bulb-symbol card (SVG glass bulb +
  filament + base), pass-through connector card (paired IN/OUT terminal
  columns). OEP's `EngineeringNode` has no equivalent shape-selection
  field today (§14).
- **Wire routing** (`route`): an orthogonal (Manhattan) auto-router keyed
  on each module's `exit` direction (`up`/`down`/`left`/`right`), with a
  **collision-avoidance allocator** (`allocX`/`allocY`, greedy nearest-
  free-lane search on a 6px grid) so parallel wires don't overlap, plus
  a **manual per-segment override** system (§13).
- **Wire drawing** (`drawWires`): base stroke, glow ring for
  selected/traced (amber for selection, green for trace), a
  **bi-color dashed stripe** for two-color wire codes (e.g. `"Bl/Y"`),
  a wide invisible hit-path for click targeting (separate from the
  visible stroke), and — only when a wire is selected or traced — a
  label badge and meter-lead marker dots.
- **Flow animation**: a `requestAnimationFrame` loop driving
  `stroke-dashoffset` on a dashed overlay path, direction-aware (reverses
  for wires terminating on a `ground`-category module), gated on the
  wire actually carrying non-zero, non-open current at the current key
  position.
- **Selection** (`selection-manager.js`): single-selection only (one wire
  *or* one module at a time — no multi-select in V2), driving CSS class
  toggles (`.wire-selected`, `.mod-selected`) rather than a rendered
  overlay layer.
- **Pan/zoom** (`applyT`/`zBy`/`zReset`, in `renderer.js`): a single CSS
  `transform: translate() scale()` on one `#scene` div; zoom clamped
  `[0.15, 3.0]`; `zReset` fits content to viewport with a 0.9 max-fit
  factor.

## 8. V2 visual system

Extracted from `css/main.css` (675 lines, the only CSS file with real
rules — `modules.css`/`wires.css`/`inspector.css`/`meter.css` are all
explicit placeholders: *"Phase 1 placeholder. Currently served by
main.css."*, verified by reading each):

| Element | Value |
|---|---|
| Canvas logical size | `1600×1000` px, fixed (not content-fit) |
| Canvas background | `--canvas-bg` (`#f5f2eb` dark theme / theme-dependent), 20px grid via double `linear-gradient` on `--canvas-grid` |
| Canvas border | 1.5px solid `--canvas-border`, 4px radius |
| Module card | `position:absolute`, white `--card-bg`, 1.5px solid `--card-border` (`#0d0d0d`), 3px radius, soft drop shadow |
| Card dragging state | heavier shadow, 92% opacity, `z-index:100` |
| Category stripe | 3px left-edge bar, color from `CAT_CLR[module.cat]` (11 category colors) |
| Terminal dot | 7×7px circle, 1.5px border, `hover: scale(1.5)` with a 0.1s transition |
| Terminal dot — lead/probe states | colored ring via `box-shadow` (red `#dc2626` for + lead, near-black for − lead, cyan for wire-from, green for wire-highlight), each with a scale bump |
| Wire selection | amber (`--amber`) box-shadow glow ring on the connected cards (`.wire-selected`), plus (in the SVG layer) an 8px-wide, 0.4-opacity amber glow stroke under the wire path |
| Wire trace | green (`#10b981`) equivalent of the above |
| Wire base stroke | 1.6px, 2.2px when traced, 2.6px when selected |
| Wire bi-color stripe | dashed (`5 4`), drawn as a second path on top |
| Route-edit segment handle | cyan (`#22d3ee`), 18px-wide invisible hit zone, visible 2–3px line + 3.5–5px midpoint dot, brighter/larger when the active segment |
| Wire label badge | white rounded rect, amber-brown border, only shown for the selected wire |
| Flow animation | dashed overlay, `12/8` dash/gap, ~1.2px/frame scroll speed |
| Viewport cursor | `grab` (pan-ready) / `grabbing` (panning) / `default` (edit mode) / `crosshair` (wire mode) |
| Color theme | CSS custom-property dark/light pair (`--surf-*`, `--text-*`, etc.) — a real dark/light theming system, analogous to `StudioTheme` |

## 9. Interaction/rendering separation (V2 → OEP mapping)

| V2 concern | Class | OEP target |
|---|---|---|
| `buildCard`/`drawWires`/flow animation | **Rendering** | Studio V2 Diagram Renderer (new) |
| `module-editor.js` drag, `wire-editor.js` click-to-connect, `routing-editor.js` nudge | **Interaction** | Studio interaction handlers — Stage E's existing Class C fields/handlers, *not* re-migrated by this plan |
| `MODULES`/`WIRES`/`positions`/`wireRoutes` globals | **State** | Already OEP: `EngineeringGraph`/`DiagramLayoutState` via the Engine (frozen) |
| `diagrams/trx300/*.json` (project/modules/wires/measurements/layout) | **Persistence** | Already OEP: `DiagramDocument` (graph+layout) + `DiagramWorkspaceState` (Stage D) — different files, same separation principle V2 already follows |
| `selection-manager.js` | **Derived visualization** (selection is Engine truth, V2's CSS-class toggling is presentation) | Already OEP: `GraphSelection` (Engine) → Studio passes `selected`/`highlighted` flags into `DiagramScene` visuals, same principle |
| `app.js`, `index.html`, `toolbar.js`, `sidebar.js` | **Application shell** | Already OEP: `DiagramStudioPage` composition root + `StudioShell` |

The mapping confirms OEP's existing Wave-1/2 architecture (Engine =
domain/runtime authority, Controller = orchestration, Studio = chrome)
already matches V2's own layer-boundary table (`docs/architecture.md`'s
"Layer Boundaries" section) in spirit — the renderer is the one layer
where the two diverge today (V2 renders directly against its own
in-memory model; OEP renders through the frozen Engine's own Flutter
widgets), which is exactly the gap this plan exists to close.

## 10. Renderer migration boundary (target architecture)

```
Diagram Studio
│
├── Studio shell                    (existing — StudioShell, unchanged)
│
├── Workspace state                 (existing — Stage D provider, unchanged)
│
├── Interaction state                (existing — Stage E Class C fields, unchanged)
│
├── Diagram scene adapter            (NEW — thin, see below)
│
└── V2 Diagram Renderer              (NEW — Studio-owned)
      ├── Module renderer            (card shapes: standard/bulb/connector)
      ├── Wire renderer              (routing + drawing + flow animation)
      ├── Label renderer             (wire labels, terminal labels — V2 keeps this
      │                                separate; OEP may fold into module/wire
      │                                renderers if the spec doesn't demonstrate
      │                                a real separate responsibility — see §16)
      ├── Selection renderer         (selection/hover glow — V2 uses CSS classes;
      │                                OEP's Flutter equivalent is a paint-time flag,
      │                                not a separate widget tree)
      └── Overlay renderer           (route-edit handles, connection/reconnect
                                       previews, alignment guides — already exist
                                       as separate Engine widgets today; V2-owned
                                       equivalents replace them one at a time)
```

**Diagram scene adapter** — the one genuinely new abstraction this plan
identifies as *necessary* (not merely organizational): a Studio-side
function/class that takes the existing `DiagramScene` (Engine-produced,
frozen contract) plus the UI-only enrichments Studio already computes
today (selection, hover, drag/resize/wire-edit preview geometry, wire
color derived from `EngineeringRelationship.metadata`) and produces a
V2-shaped render model the new renderer consumes. This is the
"`DiagramScene` in, Engine Commands out" boundary the spec already
establishes (§3.2–§3.7), applied one layer further down.

## 11. Current → V2 component mapping

| Current OEP | → V2 Reference | → Target OEP V2 Component | Migration Method | Status |
|---|---|---|---|---|
| `GraphViewPanel` (Engine, frozen) | `renderer.js` (canvas host + pan/zoom + card placement) | Studio V2 canvas host widget | replace (new Studio widget; Engine original untouched, coexists per §16) | planned |
| `SymbolNodeWidget` (Engine, frozen) | `buildCard`/`buildStdCard`/`buildBulbCard`/`buildConnCard` | Studio V2 module renderer | replace | planned |
| `WirePainter` (Engine, frozen) | `route` + the base/glow/stripe path drawing in `drawWires` | Studio V2 wire renderer | replace | planned |
| *(no current equivalent — labels are drawn inline by `WirePainter`/`SymbolNodeWidget`)* | label badge + terminal `t-lbl` text in `drawWires`/`buildCard` | Studio V2 label renderer, **if** kept separate (see §16 open decision) | new | planned |
| Selection handled via `DiagramNodeVisual.selected`/`DiagramWireVisual.selected` flags, painted inline | `.wire-selected`/`.mod-selected` CSS classes + amber/green SVG glow | Studio V2 selection renderer (paint-time flag → glow, not a CSS class system) | replace | planned |
| `ConnectionPreviewPainter`, `ReconnectHandle`, `WireEditHandles`, `ResizeHandles`, `GuidesPainter`, `GridPainter`, `OriginIndicator` (Engine, frozen) | connection preview line (`renderer.js` wire-in-progress block), route-edit segment handles (`drawWires`), no V2 equivalent for resize/guides/origin (V2 has no node-resize feature at all) | Studio V2 overlay renderer | replace where a V2 equivalent exists; **new OEP-only overlays** (resize handles, alignment guides) have no V2 reference and must be designed from OEP's own existing behavior, not invented from V2 | planned |
| No current equivalent | flow animation (`requestAnimationFrame` dash-offset loop) | Studio V2 animation renderer | new | planned |
| `AnnotationWidget` (Engine, frozen) | no V2 equivalent (V2 has no annotation feature) | Studio-owned, OEP-only — not a V2 port | keep as an OEP addition; re-implement Studio-side against the same visual language once the V2 renderer exists | planned, low priority |
| Coordinate readout (`diagram_studio_page.dart`, Stage E1) | no V2 equivalent | unchanged — already Studio-owned, already isolated (Stage E1) | none | done |
| Minimap (`diagram_studio_page.dart`'s `DiagramMiniMap` + `_showMiniMap`) | `initMinimap`/`updateMinimap`/`minimapClick` (`renderer.js`) | Studio V2 minimap (already Studio-owned; visual restyle only, not a rendering-ownership change) | adapt | planned, low priority |
| Legend (`DiagramLegendPanel`) | category-color legend (`toolbar.js`, not read in full — out of this pass's `renderer.js` focus) | Studio V2 legend (already Studio-owned) | adapt | planned, low priority |

## 12. Visual-system mapping

Covered in full in §8. Summary of the *contract*, not the values (values
must be read from `main.css` at implementation time, not transcribed a
second time and risk drift): the V2 visual system is a CSS
custom-property dark/light pair over a fixed-size absolutely-positioned
canvas, SVG wire paths with a separate always-there invisible hit-path,
and `box-shadow`-ring selection — every one of these has a direct
Flutter equivalent (`CustomPainter`/`Container` decoration, `Path`
hit-testing via a widened stroke, a painted ring) with no architectural
obstacle.

## 13. Wire-route model mismatch (explicitly classified, not resolved)

**Current OEP representation:** `DiagramLayoutState.wireOverrides: Map<String, List<Point2D>>`
(`oep_engine/lib/core/views/diagram/diagram_layout_state.dart`) — a
**full absolute point list** per wire, applied via
`SetWireRouteCommand`. When set, it *replaces* the auto-routed path
outright.

**V2 representation:** `wireRoutes[wireId]` is a **sparse map of
per-movable-segment offsets** (`route()`'s `overrides.forEach` loop in
`renderer.js`): each entry is a signed pixel offset applied to one
"movable" segment (an interior orthogonal segment, identified by index
via `getMovableSegs`) of the *freshly auto-routed* path, every time
`route()` re-runs. The auto-router's output is never replaced — it is
always recomputed, then nudged.

**Where the mismatch occurs:** OEP's model requires the auto-router to
run only once (at initial placement or on `resetLayout`), after which
`wireOverrides` is authoritative and terminal — an edited wire has no
further relationship to the auto-router or to endpoint movement (moving
a connected node does not itself re-flow an edited wire's shape, and
the current `route`/auto-layout system does not appear to auto-reroute
around moved nodes at all under either model). V2's model requires the
auto-router to run on *every* `drawWires()` call and treats overrides as
differential — so an edited wire's shape adapts if the module positions
that feed `route()`'s endpoint calculation change, while the *offsets
themselves* stay meaningful only as long as the segment topology
(`getMovableSegs`'s indexing) doesn't change shape.

**Renderer assumptions each model makes:**
- OEP: the wire renderer needs only `DiagramWireVisual.points` — a
  renderer-agnostic, already-resolved polyline. Simplest possible
  renderer contract.
- V2: the wire renderer (`route()`) must itself own the auto-routing
  algorithm, segment-movability classification, and offset application
  — routing is not separable from rendering in V2's model.

**Is a Studio-side adapter possible?** Partially, and asymmetrically:
- OEP → V2-shaped segment editing (i.e., building a V2-like route-edit
  *interaction* on top of OEP's absolute-point storage) is possible: a
  Studio-side adapter can compute "movable segments" from an existing
  `wireOverrides` point list the same way V2's `getMovableSegs` does,
  let the user nudge one via drag, and write the *result* back as a new
  absolute point list — OEP's storage model doesn't have to change for
  this direction.
- V2-shaped differential re-routing (a moved node causing an *edited*
  wire to re-flow while preserving the user's nudges) is **not**
  achievable as a pure Studio-side adapter over the current absolute-
  point storage, because the offsets' meaning is defined relative to a
  freshly-computed auto-route that OEP's model discards once an override
  exists.

**Does this require an Engine model decision?** Only if V2's
differential re-routing behavior is a hard requirement for parity. If
OEP's existing "edit replaces the route outright, moving a node does not
retroactively adjust an edited wire" behavior is acceptable (it is
today's actual behavior, unchanged through every prior Wave 2 stage),
no Engine change is needed — the renderer can visually match V2 while
the underlying edit semantics stay OEP's own. **This is the open
decision** (§18) — not resolved by this document, per the task's
explicit instruction.

## 14. V2 data gaps

Verified against the actual current OEP model (not assumed from the
spec's own concern list):

| Concern | Status | Detail |
|---|---|---|
| Wire color | **RESOLVED as of AP-DIAGRAM-V2-005** (corrects the V2-002/003/004 UNRESOLVED classification below) | Every prior task's grep searched `EngineeringRelationship` itself (still correctly no `color` field) but missed `oep_engine/lib/core/publishing/reports/wire_report.dart` — a real, shipped Engine feature (AP-DS-004, Wire List report) whose own doc comment explicitly documents `relationship.metadata['wireColor']` and `metadata['label']` as "well-known keys," and whose `generate()` already reads them (`rows.add({..., 'wireColor': relationship.metadata['wireColor'] ?? '', ..., 'label': relationship.metadata['label'] ?? '', ...})`). This is a real, Engine-established convention — not invented by the V2-005 adapter, just missed by earlier searches that only looked at the model class and not the reports that consume its `metadata` bag. **However**, that same report's doc comment discloses "nothing currently populates these through any Studio UI" — so `metadata['wireColor']`/`['label']` resolve to `null`/blank for every real document today. `adaptDiagramScene`'s new optional `graph:` parameter (AP-DIAGRAM-V2-005) reads both verbatim via `graph?.relationships[wire.relationshipId]?.metadata['wireColor'/'label']`. For the *visual stroke color* specifically, only a literal `#RRGGBB`/`#AARRGGBB` hex string is interpreted (`resolveWireStrokeColor()`, `v2_wire_painter.dart`) — free text (e.g. a color name, which is what V2's own `HEX` table actually maps) falls back to V2's documented neutral `#888` rather than being guessed, since no name-to-color vocabulary exists anywhere in OEP. Separately, `DiagramAnnotation(type: AnnotationType.wireLabel)` (`diagram_annotation.dart`) is a *different*, pre-existing mechanism — a free-floating drafting note a user manually places/drags, whose optional `anchorRelationshipId` soft-reference to a specific wire is never actually populated by any existing Studio command (confirmed via grep — only read by an inspector's "(unanchored)" fallback display, never written). Deliberately not used as the wire-label source: conflating a generic, unanchored drafting annotation with the wire's own first-class identity label (the `metadata` convention above) would misrepresent one kind of data as another. |
| **Port position** | **RESOLVED as of AP-DIAGRAM-V2-003** (was misclassified UNRESOLVED in V2-002) | `SymbolPort.x`/`.y` (`oep_engine/lib/core/symbols/models/symbol_port.dart`), obtained via `engine.registry.symbols.resolve(node.symbolId).ports`, falling back to the public `fallbackPorts(node.ports, exit:)` (`oep_engine/lib/core/views/diagram/fallback_port_layout.dart`) — the exact lookup `GraphViewPanel`/`diagram_studio_page.dart` already perform. The V2-002 entry looked only at `Port` (graph model, genuinely position-less) and missed this. Now reused verbatim by `adaptDiagramScene`'s optional `symbols:` parameter. |
| Card shape / type (V2's `module.bulb`/`module.connector` shape flags) | **Partially resolved** — standard-card family implemented; bulb/connector variants **UNRESOLVED**, deliberately deferred | `NodeCategory.connector` is a real, existing signal that *could* drive a connector-shaped card variant (a legitimate Studio adapter, not fabricated), but was not wired up in V2-003 to keep that task's scope to "one V2-styled card," matching the current renderer's own single-card-template convention (`SymbolNodeWidget` also renders every node with one shape). No signal exists at all for bulb-shaped cards — `EngineeringNode` has no boolean/enum shape hint and `NodeCategory` has no `lighting`/indicator equivalent. Every node in the V2 dev path today renders as the standard card; connector/bulb variants are open work for a later task, not fabricated. |
| Wire label text | **RESOLVED as of AP-DIAGRAM-V2-005** (superseded, see the Wire color row above for the full correction — `metadata['label']` is the same convention/discovery) | Rendered by `V2WirePainter` when the wire is selected; see the Implementation status table above. |
| Multimeter readings per wire per key-state | **RESOLVED** | Already OEP's own, larger, real subsystem — `DiagramSimulationService`/instruments (WP-DS-005A), unrelated to the renderer; V2's `wire.readings` is a much simpler, static, non-simulated version of what OEP already simulates live. No gap — OEP's version is a superset. |

## 15. Rendering replacement sequence

Derived from the dependency structure discovered above (not assumed):

1. **Diagram scene adapter** — must exist before anything else, since
   every renderer piece below consumes its output, not raw `DiagramScene`.
2. **Canvas host + coordinate system** — pan/zoom transform, fixed/
   fit-to-content sizing decision, hit-testing coordinate space. Nothing
   else can be visually verified without this.
3. **Module/node renderer** — the highest-value, most-visible piece;
   also the one with the clearest data-gap resolution needed first (§14
   card-shape decision) before it can be built correctly.
4. **Port rendering** — depends on node renderer existing (ports are
   drawn relative to a card).
5. **Wire renderer (base path only, no editing)** — depends on node/port
   renderer for endpoint resolution.
6. **Selection rendering** — depends on wire+node renderers existing to
   attach glow to.
7. **Labels** — depends on wire renderer (label position is wire-
   midpoint-derived) and the wire-color/label data-gap decision (§14).
8. **Hover/connection-preview/reconnect-preview overlays** — depends on
   base wire/node rendering being visually stable first (previews are
   drawn on top).
9. **Route-edit / wire-edit handles** — depends on the wire-route model
   decision (§13) being made, since the handle interaction is built
   directly on top of whichever route model is chosen.
10. **Flow animation** — purely additive on top of a working wire
    renderer; safe to defer without blocking anything else.
11. **Minimap / legend** — already Studio-owned, lowest-risk, can happen
    any time after step 3 (needs node positions/colors, nothing else).
12. **Interaction integration** — rewiring the ~30 existing gesture
    callbacks (Stage E inventory) from `GraphViewPanel`'s prop contract
    to the new Studio renderer's own contract. Deliberately last: every
    prior step can be visually verified read-only (rendering a static
    scene) before any interaction wiring risk is introduced.

This order is a **dependency-derived recommendation**, not a mandate —
the actual implementation task should re-verify it once the diagram
scene adapter's real shape is known.

## 16. Parallel-renderer decision

**Recommended: yes, behind a development-only switch**, for the
following concrete reason: `GraphViewPanel`/`SymbolNodeWidget`/
`WirePainter` are frozen (this document, §5) but not removed — Diagram
Studio must remain usable throughout the V2 renderer's construction
(every prior Wave 2 stage's own "no visual regression" rule applies
equally here). A parallel switch is the only way to build and visually
verify the V2 renderer incrementally (per §15's sequence) without ever
putting the production canvas in a broken intermediate state.

- **Switch location:** a single Studio-local flag (e.g. a
  `DiagramStudioSettings` field, or — lower-risk and easier to strip
  later — a compile-time/`kDebugMode`-gated constant in
  `diagram_studio_page.dart` itself), read once at the single point
  where `GraphViewPanel` is currently constructed, choosing between it
  and the new V2 canvas host.
- **Default:** **current renderer**, always, until the V2 renderer is
  judged feature-complete against §15's full sequence — this document
  does not authorize flipping the default.
- **Test strategy:** existing `test/workflow/` diagram tests continue to
  exercise the current (default) renderer unchanged; new, separate tests
  are added for the V2 renderer path as each §15 step lands, never
  replacing the existing coverage until the switch is removed.
- **Removal strategy:** once the V2 renderer reaches parity (all of §15
  plus the open decisions in §18 resolved) and is verified via the same
  live-hot-reload discipline as Stage E1, delete the current-renderer
  branch of the switch and, only then, revisit whether
  `GraphViewPanel`/`SymbolNodeWidget`/`WirePainter` in the Engine package
  become genuinely dead code worth a separate, explicitly-authorized
  removal task (not part of this plan or its first implementation
  follow-up).

## 17. Testing strategy

- No renderer behavior changes in this task — existing `test/workflow/`
  diagram tests, `diagram_document_test.dart`, `diagram_workspace_state_test.dart`,
  and the Stage A–D1 controller/provider/persistence/isolation tests all
  remain the regression baseline, unmodified, verified passing (§ Baseline
  test results in the completion report).
- The first real V2 renderer implementation task should add tests
  *alongside* the parallel-switch mechanism (§16): scene-adapter unit
  tests (pure data transform, no widget pump needed — cheapest,
  highest-value first), then widget-level rendering tests only for the
  V2 path, gated the same way the switch itself is gated.
- Live, manual, hot-reload-driven visual verification (this task's own
  §19 discipline) remains mandatory for every visual rendering change —
  automated widget tests can catch structural regressions but cannot
  substitute for a human visual comparison against the V2 reference
  screenshots/running reference app.

## 18. Live verification strategy

Unchanged from Stage E/E1's established, now-proven discipline:
`flutter run -d windows` kept running, developer-driven manual `r` hot
reload at each checkpoint, no automated VM-Service reload attempted (a
real, investigated, documented limitation — see the Stage E/E1
completion reports). For the V2 renderer implementation itself, the
*additional* verification step is a direct visual side-by-side against
`reference/legacy_wiring_sim_v2/eke-wiring-sim/index.html` (opened in a
browser) for each §15 step, not just internal OEP regression checks.

## 19. Explicit non-goals (of this document and its implementation)

- No Engine or Foundation modification, ever, for this reconstruction.
- No modification of `GraphViewPanel`/`SymbolNodeWidget`/`WirePainter`/
  any other current Engine renderer widget.
- No wire-route model change (§13 stays an open decision until
  separately authorized).
- No further interaction-state migration beyond what Stage E/E1 already
  did.
- No V2 renderer code in this task — planning only.
- No UI redesign of anything already Studio-owned (chrome, panels,
  toolbars) — only the canvas interior is in scope for the eventual V2
  renderer.

## 20. Open architecture decisions

Recorded, not resolved, per this task's own instruction:

1. **Wire-route model** (§13): accept OEP's existing "edit replaces the
   route, no differential re-routing" semantics as final, or pursue an
   Engine model decision to support V2-style differential nudging?
2. **Card-shape data source** (§14): which OEP field/convention decides
   "render as bulb" / "render as connector" — a new `metadata` key
   convention, or a `NodeCategory` extension? (`metadata` extension is
   this document's provisional recommendation, as the lower-risk,
   already-sanctioned escape hatch — but not yet decided.)
3. **Wire color/label source**: same shape of decision as #2, for wire
   visuals specifically.
4. **Label renderer separation** (§10/§11): does OEP's implementation
   need a genuinely separate label-rendering component, or does V2's own
   evidence (labels drawn inline inside `drawWires`/`buildCard`, no
   separate `label-renderer.js` implementation despite the placeholder
   file existing) argue for folding labels into the module/wire
   renderers instead, per this task's own "create abstractions only
   where the source demonstrates an actual responsibility boundary" rule?
5. **Switch mechanism** (§16): `DiagramStudioSettings` field vs. a
   compile-time constant — a decision to make at implementation start,
   not now.
6. **Resize/alignment-guide visual language**: V2 has no node-resize
   feature and therefore no reference visual for it — OEP's V2-styled
   renderer will need an OEP-original design for these two overlays,
   consistent with V2's visual system (§8) but not a port of anything.

## 21. Implementation acceptance criteria (for the first real V2 renderer task)

1. Diagram scene adapter exists, is unit-tested independent of any
   widget tree, and both #2 and #3 decisions (§20) are resolved and
   documented in its own doc comment before it is built, not discovered
   mid-implementation.
2. The parallel-switch mechanism (§16) exists and defaults to the
   current renderer.
3. At least the canvas host + coordinate system + module/node renderer
   (§15 steps 1–3) render correctly under the V2 switch, verified live
   via manual hot reload against the running reference V2 app.
4. `GraphViewPanel`/`SymbolNodeWidget`/`WirePainter`/every other current
   Engine renderer widget is byte-for-byte unmodified.
5. `flutter analyze` clean; existing test suite (this document's
   baseline) unmodified and passing, apart from documented pre-existing
   failures; new tests added only for the new adapter/renderer code.
6. No wire-route model change attempted (open decision #1 stays open
   unless a separate task explicitly authorizes resolving it first).

## 22. Proposed next task

**AP-DIAGRAM-V2-002 — V2 Diagram Scene Adapter + Parallel-Renderer Switch
(canvas host + coordinate system only).** Scope: resolve open decisions
#2, #3, and #5 (§20); build the diagram scene adapter with unit tests;
build the switch mechanism (default: current renderer); build *only* the
V2 canvas host and coordinate system (§15 steps 1–2) behind the switch,
with no node/wire rendering yet (a blank V2-styled canvas is an
acceptable, honestly-scoped deliverable for that task). This keeps the
first real implementation step small, reviewable, and — critically —
does not require resolving the wire-route model decision (open decision
#1) before useful progress can be made.

## 23. Studio Wire Metadata Editor (AP-DIAGRAM-V2-006)

**Not a V2 renderer task.** AP-DIAGRAM-V2-005 found that
`EngineeringRelationship.metadata['wireColor']`/`['label']` are real,
already-established Engine metadata keys, but disclosed that nothing in
Studio actually wrote them. This task closes that gap on the *editing*
side, independent of which diagram renderer (current or V2) is active.

**Metadata source (unchanged from AP-DIAGRAM-V2-005):**
`EngineeringRelationship.metadata['wireColor']`/`['label']`
(`oep_engine/lib/core/graph/models/engineering_relationship.dart`),
already read by `WireReportGenerator` (AP-DS-004). No new Engine field,
persistence convention, or model was introduced.

**Mutation mechanism:** `UpdateRelationshipPropertiesCommand`
(`oep_engine/lib/core/editing/commands/update_relationship_properties_command.dart`,
ENGINE-TASK-000085) — a real, already-implemented, generic
metadata-patch `EditingCommand` that existed before this task but had
*no caller anywhere in Studio* (confirmed via grep before writing any
code, per this task's own instruction to trace the existing command
architecture first). It merges a `Map<String, Object?>` patch into a
relationship's `metadata`; a `null` value in the patch removes that key
— exactly the "clearing removes the metadata key" behavior this task
required, already built into the command, not implemented specially for
this UI. `DiagramStudioController.updateRelationshipMetadata(id, patch)`
(`diagram_studio_controller.dart`) is a two-line wrapper — `engine.editing.execute(...)`
then `markDirty()` — following the *exact* shape of every other
mutating controller method (`createRelationship`, `moveAnnotation`,
etc.); no new command, no direct `relationship.metadata[...] = ...`
mutation from a widget.

**UI location:** the existing relationship Property Inspector
(`lib/diagram_studio/inspector/engineering_relationship_properties.dart`,
reached via the shared `PropertyInspectorPanel`/`EngineeringInspectable`
selection mechanism already used for every other Engineering Graph
object type). Converted from a read-only `ConsumerWidget` to a
`ConsumerStatefulWidget` — the only structural change — so its two new
`TextField`s (Wire Label, Wire Color) can hold `TextEditingController`s
synced to the selected relationship and re-synced only when the
*selection* changes (a different relationship id), not on every
rebuild, so in-progress keystrokes on one relationship survive unrelated
rebuilds. Every other field in the Inspector is unchanged and still
read-only. Shown for every relationship, not only `connectedTo` ones —
the metadata convention itself has no such restriction.

**Validation:** the Wire Color field accepts only `#RRGGBB`/`#AARRGGBB`
hex, validated with the exact same `wireHexColorPattern`/
`isValidWireHexColor()` the V2 renderer's own `resolveWireStrokeColor()`
uses (`v2_wire_painter.dart`, exported for this reuse) — a single source
of truth, so the Inspector and the renderer can never silently accept
different formats. An invalid value shows an inline `errorText` and is
never sent to the command (verified by test — the underlying metadata
is untouched). Committing happens on `onSubmitted`/`onEditingComplete`
(Enter or focus loss); an empty field commits a `null` patch value,
clearing the key.

**Undo/redo/dirty-state:** all inherited for free from
`engine.editing.execute`/`DiagramStudioController.markDirty()` — the
same centralized pathway (command execution → `markDocumentDirty()` →
debounced Intelligence sync) every other Diagram Studio edit already
uses. No second dirty-state mechanism, no direct
`markDocumentDirty()` call from the Inspector.

**Persistence:** metadata lives on the relationship inside the
Engineering Graph, which is already part of the normal document
save/load cycle — no separate wire-metadata storage was created.

**V2 renderer integration:** unchanged from AP-DIAGRAM-V2-005 —
`adaptDiagramScene(scene, graph: ...)` already reads these same keys;
this task only makes them non-empty in a real, edited document. Live
verification: setting Wire Label/Wire Color on a selected wire with the
V2 canvas enabled shows the label/color exactly as AP-DIAGRAM-V2-005
described (label only while selected, color via the same hex-only
parsing).

**Current renderer:** completely unaffected — the metadata itself is
renderer-independent, and `_useV2CanvasDev` default/behavior was not
touched.

**Remaining limitations:** only literal hex is accepted for color (no
named-color vocabulary, unchanged from V2-005); the Inspector edits one
relationship at a time (no multi-select bulk edit); nothing auto-derives
a label/color from anywhere (category, id, etc.) — every value is
exactly what a user typed, or blank.

## 24. V2 Connection Preview Rendering (AP-DIAGRAM-V2-007)

**Not an interaction task.** This renders the *existing* wire-creation
preview state in V2's visual style; it does not touch how a connection
is created, validated, or completed.

**Existing state consumed (unchanged, not duplicated):**
`DiagramStudioPage`'s own `_connectFromPort`/`_connectionCurrentPoint`/
`_connectionValid` `State` fields — the exact same fields the current
renderer's `ConnectionPreviewPainter`
(`oep_engine/lib/views/widgets/connection_preview_painter.dart`) already
consumes via `GraphViewPanel`'s `connectionPreviewFrom`/`connectionPreviewTo`/
`connectionPreviewValid` parameters. `V2CanvasHost` gained the identical
three parameters, fed from `_portAnchor(_connectFromPort!)` (the same
real, `SymbolPort`-derived source-port geometry AP-DIAGRAM-V2-003
established, reused here, not re-derived) and `_connectionCurrentPoint`
directly. No second wire-creation state machine, no new pointer-position
tracking, no target-port state was introduced — `DiagramStudioPage`
never captures a "target port," only a transient target *node* id inside
its own drag/tap handlers, so none is threaded through here either (per
this task's own "do not invent target-port state" instruction).

**Connection validity:** read as an opaque `bool` from
`_connectionValid`, itself computed by the existing
`ConnectionValidator.canConnect(...)` inside `DiagramStudioPage`'s own
handlers — never recomputed or duplicated by the renderer.

**V2 reference behavior**
(`reference/legacy_wiring_sim_v2/eke-wiring-sim/js/diagram/renderer.js`,
the `wireMode&&wireSrc&&mcX` block, and `js/editor/wire-editor.js`):
- A single straight SVG `<line>` from the source terminal to the live
  mouse position — stroke `#0891b2`, width `1.5`, `stroke-dasharray`
  `"6 3"`, round cap, no fill, **no endpoint dot/circle** (unlike the
  current OEP renderer's own preview, which draws one).
- Appended into the *same* SVG layer as static wires
  (`wsvg.appendChild(pv)`, right after the wire-drawing loop) — i.e.
  above static wires, but (since that whole SVG wire layer sits beneath
  V2's `#mod-layer` in the reference DOM) still beneath module cards.
  This is a deliberate difference from the *current* OEP renderer, where
  `ConnectionPreviewPainter` paints above nodes (`graph_view_panel.dart`)
  — the V2 reference's own layering was followed here since this task's
  scope is "V2 visual treatment," not "match the current renderer's
  z-order."
- **No valid/invalid visual distinction exists in V2 at all** — read
  directly from source: `wire-editor.js` only rejects an invalid/
  duplicate connection at *completion* time (a toast), never during the
  live drag. V2's preview line is always the same cyan dashed line
  regardless of what the eventual connection would be.
- No animation, no glow, no hover/target-port highlighting on the
  preview line itself.

**The valid/invalid adaptation, explicit and documented:** since V2 has
no live valid/invalid preview treatment to copy, but OEP's own
`_connectionValid` is a real, meaningful signal already computed live
during the drag (and acceptance criterion 5 requires it drive the
visual), the smallest faithful adaptation was made: the V2 dash/width/
cap/no-dot styling all stay exactly as V2 defines them, and only the
stroke color switches — V2's own cyan `#0891B2` when valid, a red
`#DC2626` when not. This is not a literal V2 color (none exists to
copy), but it is also not invented from nothing: it's the same
semantic the *current* renderer's own `ConnectionPreviewPainter`
already applies (green/red validity), translated into V2's cyan-based
palette instead of green. See `V2ConnectionPreviewPainter`'s own doc
comment for the same reasoning in code.

**Rendering technology:** a dedicated `CustomPainter`
(`V2ConnectionPreviewPainter`, `v2_connection_preview_painter.dart`) —
matches `V2WirePainter`'s own choice for the same reason (no text, no
per-instance interaction). Dashing is hand-drawn segment-by-segment
(`Canvas` has no native dash API) but the underlying geometry is still
the single straight `from`->`to` line V2's own single `<line>` element
describes — not a new routing/geometry concept.

**Coordinate integration:** no new transform. The painter is placed
inside `V2CanvasHost`'s existing `SizedBox(width: contentWidth, height:
contentHeight)` scene-space child, the same `InteractiveViewer`-driven
coordinate system every other V2 layer (diagnostic grid, wires, cards)
already uses — pan/zoom apply to it automatically, with zero
painter-side transform code, exactly like `V2WirePainter`.

**Layer ordering (`V2CanvasHost`'s `Stack`, top realized last):**
diagnostic bounds/origin → static wires (`V2WirePainter`) → connection
preview (`V2ConnectionPreviewPainter`, `IgnorePointer`-wrapped for the
same reason `GraphViewPanel`'s own preview layer is — a bare full-canvas
`CustomPaint` would otherwise silently absorb the second port tap that
completes the connection) → module cards.

**Target-port handling:** none — see "Existing state consumed" above;
no such state exists to consume, and none was invented.

**Animation:** none. Confirmed from the V2 reference source that no
animation exists on the preview line itself (V2's `startFlowAnim`/
`addFlowOverlay` machinery is for *completed, selected/traced* wires
only, an entirely separate, already-out-of-scope system — see V2-004's
own doc comment on flow animation). No timer/ticker/AnimationController
was introduced.

**Interaction architecture preservation:** `_connectFromPort`/
`_connectionCurrentPoint`/`_connectionValid` remain plain
`DiagramStudioPage` `State` fields, untouched. No Riverpod migration. The
E1 `_cursorScenePositionNotifier`/`ValueListenableBuilder` optimization
is unrelated to this state (it isolates the coordinate-readout rebuild
scope, not connection-preview state) and was not touched.

**Remaining limitations:** no endpoint dot (V2 has none, so none was
added); no target-port highlight (no source data); reconnect still uses
only the current renderer's own `ReconnectHandle`s — no V2 reconnect
visual exists yet, by this task's own explicit exclusion.

## 25. V2 Selection and Hover Visual Integration (AP-DIAGRAM-V2-008)

**Selection authority (unchanged, not duplicated):** the Engine's own
`GraphSelection`/`registry.selection`, exactly as before —
`StudioSceneNode.selected`/`StudioSceneWire.selected` are still a
direct, unmodified pass-through from `DiagramNodeVisual.selected`/
`DiagramWireVisual.selected` (`diagram_view.dart`:
`selection?.containsNode(...)`/`containsRelationship(...)`). No second
selected-id collection, no V2-specific selection manager, no Riverpod
mirror was created.

**Module selection — the actual correction this task made.** V2's own
`css/main.css` defines two *different* card glows that were conflated
in the original AP-DIAGRAM-V2-003 pass:
- `.mod-card.mod-selected` (`js/editor/module-editor.js`, set when
  `selM === m.id` — the module *itself* is selected, via V2's own
  inspector click) — cyan: `box-shadow:0 0 0 2px var(--cyan),0 0 0 4px
  rgba(34,211,238,.2),0 0 12px rgba(34,211,238,.15)` (`--cyan:#22d3ee`).
- `.mod-card.wire-selected` (`js/editor/selection-manager.js`'s
  `selWire()` — set on a *wire's two endpoint cards* when that **wire**,
  not the module, is selected) — amber: `box-shadow:0 0 0 2px
  var(--amber),0 0 0 4px #fde68a,0 0 0 6px var(--amber)`.

`StudioSceneNode.selected` is the direct analog of `selM`/
`mod-selected` (a module the user directly selected), **not**
`wire-selected` — but V2-003's `V2ModuleCard` applied the amber
`wire-selected` values to it. Corrected in this task to the real cyan
`mod-selected` glow (`v2_module_card.dart`). The `wire-selected`
amber-card-highlight behavior itself (a selected *wire* visually
lighting up its two endpoint cards) was deliberately **not**
reproduced — doing so would require `V2ModuleCard` to read something
beyond `StudioSceneNode.selected` (a wire's own selection state plus
its endpoint node ids), which this task's own instruction explicitly
restricted against ("use `StudioSceneNode.selected` as the sole
selection input"). Documented here as a known, intentionally deferred
V2 nuance, not an oversight.

**Wire selection — reviewed, already correct.** `V2WirePainter`'s
existing selected-wire treatment (AP-DIAGRAM-V2-004) was re-checked
against `drawWires()`'s `isSel` branch and found to already match
exactly: amber `#f59e0b`, 8px-wide, 0.4-opacity glow underneath a 2.6px
(vs. 1.6px normal) stroke. No change was made — per this task's own
instruction 6 ("if it is already complete, do not rewrite it
unnecessarily").

**Hover — exhaustively investigated, deferred.** Grepped both
`oep_engine` and `oep_studio` for any hovered-node or hovered-wire
identity: none exists. The only hover state anywhere in the current
system is **port-level**: `ViewState.hoveredPort`
(`_handlePortHoverEnter`/`_handlePortHoverExit`, driven by
`SymbolNodeWidget`'s own per-port `MouseRegion`,
`oep_engine/lib/views/widgets/symbol_node_widget.dart`). `GraphViewPanel`'s
own background `MouseRegion.onHover` only ever updates
`_cursorScenePosition` (the E1-optimized raw pointer position) — it does
not identify a hovered node or wire. Reproducing V2's card/wire hover
would require inventing a new whole-node/whole-wire hit-testing
mechanism, which this task's own stop conditions explicitly forbid
("V2 hover requires a new global hit-testing architecture" is stop
condition 2). Separately, even if that identity existed, V2's own
`css/main.css` has **no** `.mod-card:hover` or wire-hover rule at all —
the only hover CSS on the whole canvas is `.t-dot:hover{transform:
scale(1.5)}` (a single port dot) and `.resize-handle:hover`. So module/
wire hover is deferred for two independent, source-verified reasons:
no OEP authority to consume, and no V2 visual to reproduce even if
there were one.

**Selection/hover precedence:** not applicable — with hover deferred,
only the plain selected/not-selected states exist for both modules and
wires; no combination logic was needed or added.

**Rendering/layering:** no change to `V2CanvasHost`'s existing Stack
order (diagnostic → wires → connection preview → cards) — the
correction was entirely inside `V2ModuleCard`'s own `BoxDecoration`, no
new layer.

**Performance/rebuild scope:** zero new state, zero new listeners —
`node.selected` was already a plain field read on every
`V2ModuleCard` build, same as before the color correction. No Riverpod
mirror, no per-frame rebuild, no `AnimatedBuilder`. The E1
`_cursorScenePositionNotifier`/`ValueListenableBuilder` optimization is
untouched (this task never reads cursor position at all).

**Remaining V2 gaps:** module/wire hover (deferred, see above); the
`wire-selected` amber-card-highlight-on-connected-modules effect
(deliberately not reproduced, see above); no selection *animation*
(V2's own CSS has none beyond the static `box-shadow`, so none was
added here either).

## 26. V2 Module Port Rendering and Port-State Visuals (AP-DIAGRAM-V2-009)

**Port data (unchanged, not duplicated):** `StudioScenePort.x`/`.y`,
resolved by `adaptDiagramScene` exactly as AP-DIAGRAM-V2-003 established
(`SymbolProvider.resolve(...).ports` → `fallbackPorts(...)`) — verified
still node-local normalized `0..1`, multiplied by `node.width`/`.height`
for placement, same as before. No second port-position source was
created; port identity/direction/position all remain exactly as
resolved by the existing adapter.

**Port position/size:** confirmed correct and unchanged — 7x7 circle at
`port.x! * node.width - 3.5` / `port.y! * node.height - 3.5` (centering
the 7px marker on the resolved point). Only the **border** was wrong:
V2-003 used a white 1px border; V2's own `.t-dot` is `border:1.5px solid
#0d0d0d` — corrected in this task.

**Port fill color — genuinely unresolved, left alone.** V2's own
`.t-dot` fill comes from `background:${h(t.c)}` in `renderer.js` — each
*terminal* has its own wire-color-code field (`t.c`) on V2's module
model, the fill is set per-terminal, not per-direction. Neither `Port`
nor `SymbolPort` (`oep_engine/lib/core/graph/models/port.dart`,
`oep_engine/lib/core/symbols/models/symbol_port.dart`) has any color
field or metadata convention for this — verified by reading both
classes in full. Since no real OEP data exists to reproduce V2's actual
rule, the existing Studio-owned direction-based fill (`v2PortColor`,
established V2-003) was left exactly as it was rather than fabricating
a color from nothing.

**Port direction:** `StudioScenePort.direction` continues to drive only
the existing fill-color palette (unchanged); V2's own `.t-dot` CSS has
no direction-based rule at all (fill is purely terminal-color-code
driven, as above) — so no additional direction-based visual was added
beyond what already existed.

**Port labels:** not rendered. V2 does show terminal names, but only in
non-canvas UI (the module's own info panel/connection list — `.t-lbl`,
`.sw-terminals` — never as text next to the on-canvas dot itself).
Confirmed by reading `main.css`'s full `.t-dot`/`.t-lbl` rule set: no
canvas-adjacent port-name text exists in V2's reference renderer, so
none was added to `V2ModuleCard` either.

**Hovered port — real source, real V2 rule, implemented.**
`ViewState.hoveredPort` (`oep_engine/lib/core/viewstate/view_state.dart`)
is a real, already-authoritative `PortReference?`, set by
`DiagramStudioPage._handlePortHoverEnter`/`_handlePortHoverExit` — the
exact same per-port `MouseRegion` signal `SymbolNodeWidget`'s own
`_PortMarker` already consumes for the current renderer
(`hoveredPort == PortReference(...)` in `symbol_node_widget.dart`).
Threaded straight through `V2CanvasHost` → `V2ModuleCard` →
`_V2PortDot` as a plain constructor parameter — the *same* mechanism
`GraphViewPanel` already uses (a build-time value comparison, not a new
listener). V2's own rule: unconditional `.t-dot:hover{transform:
scale(1.5)}` when no connection is pending; V2's `.wh` class (green
glow, `js/editor/wire-editor.js`'s `mouseenter`) adds a glow only
`if((wireMode&&wireSrc)||leadPlaceMode)` — the lead-placement half of
that condition belongs to the multimeter/`ProbeOverlay` subsystem, out
of scope here, so this task's `.wh` equivalent triggers only on the
wire-creation half of that condition.

**Active wire-creation source port — real source, real V2 rule,
implemented.** `DiagramStudioPage._connectFromPort` (already consumed
by AP-DIAGRAM-V2-007's connection preview) threaded through the same
path as `hoveredPort`. Matches V2's `.wf` class
(`wire-editor.js`: `dot.classList.add('wf')` when a terminal becomes
the pending wire's source) — cyan glow, scale 1.6, and takes precedence
over the hover glow when a port is both the active source *and*
currently hovered (matches V2's own DOM: a dot can carry both `wf` and
`wh` classes simultaneously, but `wf`'s stronger scale/glow visually
dominates).

**Selected port — investigated, does not exist for Diagram Studio.**
`oep_engine/lib/core/selection/focus_state.dart`'s `FocusState.port` is
a real Engine concept (`FocusKind.port`), but grepped across all of
`oep_studio/lib/diagram_studio/` and found **zero** reads or writes —
Diagram Studio never populates or consumes it. Per this task's own
instruction ("if no selected-port state exists, do not invent one"),
no selected-port visual was implemented.

**Precedence (matches V2's own DOM/CSS cascade, not invented):** active
source > hovered-during-pending-connection > plain hover > normal.
Verified in code (`_V2PortDot.build()`'s own `if`/`else if` chain) and
tested directly (`v2_module_card_port_test.dart`'s "hovering the active
source port itself" case).

**A known, honestly-documented limitation, not fixed in this task:**
none of `hoveredPort`/`activeSourcePort` can actually change while the
V2 canvas is the *mounted* renderer, because the port-level
`MouseRegion`s and port-tap gesture handlers that produce those signals
today live only inside `SymbolNodeWidget`/`GraphViewPanel` (the current
renderer), which isn't mounted while V2 is showing. This is the same
limitation already disclosed for AP-DIAGRAM-V2-007's connection preview
— these V2 states render correctly *whenever the existing state happens
to be set*, but nothing in the V2 tree can set that state itself yet
(would require real port hit-testing on `V2ModuleCard`'s ports, which
this task's own stop conditions explicitly forbid). A future
interaction-integration task's job, not this one's.

**Rendering technology:** a small dedicated `_V2PortDot` `StatelessWidget`
(private to `v2_module_card.dart`), not a `CustomPainter` — matches
`V2ModuleCard`'s own established choice for the same reasons (this is
inside an existing widget tree, no new painting surface needed). No
`MouseRegion`/`GestureDetector` — this widget does no hit-testing of its
own, per this task's explicit restriction.

**Layering:** unchanged — ports were already painted as the last
children inside each `V2ModuleCard`'s own `Stack` (above the card body,
alongside the label), which is itself painted above wires/connection
preview in `V2CanvasHost`'s own `Stack`. No reordering was needed or
made; `V2WirePainter`/`V2ConnectionPreviewPainter` were not touched.

**Pan/zoom integration:** no new transform — ports remain plain
`Positioned` children inside the same `SizedBox(width: contentWidth,
height: contentHeight)` scene-space subtree `InteractiveViewer` already
transforms for every other V2 layer; `Transform.scale` (used for the
hover/active-source visual states) scales around the marker's own
center and does not affect its `Positioned` offset (verified directly
by test — `v2_module_card_port_test.dart`'s "unaffected by state" case).

**Performance/rebuild scope:** zero new state, zero new listeners.
`hoveredPort`/`activeSourcePort` are plain fields read at build time,
exactly like `node.selected` already was — no `ValueListenableBuilder`,
no `AnimatedBuilder`, no Riverpod mirror, no per-frame rebuild
introduced. Given the "known limitation" above (these values can't
currently change while V2 is mounted), there is today no rebuild
trigger to worry about in practice either — but the implementation
itself introduces none regardless of that.

**Remaining port-related gaps:** port fill color (no OEP data — see
above); module/wire hover (still deferred, AP-DIAGRAM-V2-008); the
lead-placement (`'R'`/`'B'` multimeter) port states (a separate OEP
subsystem, `ProbeOverlay`, not this task's concern); no port
interaction/hit-testing on the V2 path at all (by this task's own
explicit restriction — a future task's job).

## 27. V2 Interaction-State Visual Integration (AP-DIAGRAM-V2-010)

A full, source-verified inventory of every interaction visual this
task's own instructions asked about, each classified A (already
implemented correctly) / B (real V2 visual + real OEP state, implement)
/ C (real V2 visual, no authoritative OEP state) / D (needs new
interaction architecture, out of scope) / E (not actually present in
V2). **Only Category B items were implemented.**

| Interaction visual | V2 source checked | Classification | Disposition |
|---|---|---|---|
| Module selection | `.mod-card.mod-selected` | A | Already correct (AP-DIAGRAM-V2-008) |
| Wire selection | `drawWires()`'s `isSel` | A | Already correct (AP-DIAGRAM-V2-004) |
| Wire-selected connected-module highlight | `.mod-card.wire-selected` | D-adjacent, deliberately deferred | Would need `V2ModuleCard` to read a wire's selection + endpoint ids, beyond `StudioSceneNode.selected` — explicitly excluded by AP-DIAGRAM-V2-008's own instruction; unchanged here |
| Module hover | no `.mod-card:hover` rule exists in `main.css` | E | Confirmed absent from V2 again this task; unchanged, still deferred (also no OEP hovered-*node* authority, per V2-008) |
| Wire hover | no wire-hover rule in `main.css`/`renderer.js` beyond the wide invisible SVG hit-path (interaction only, no distinct paint) | E | No visual to reproduce |
| Port hover / active source | `.t-dot:hover`, `.wf`, `.wh` | A | Already correct (AP-DIAGRAM-V2-009) |
| Selected port | `FocusState.port` exists in Engine, never populated by Diagram Studio | Confirmed still N/A | Unchanged (AP-DIAGRAM-V2-009's own finding, re-verified) |
| **Module dragging** | `.mod-card.dragging` (`css/main.css:137`, `module-editor.js`) | **B** | **Implemented** — `V2ModuleCard.dragging`, sourced from `_dragNodeIds` |
| Module resizing | `.resize-handle` — read in full: `/* GENERIC RESIZE HANDLE — appended by JS to any panel that opts in */`, used only by `js/app.js`'s floating-panel drag-to-resize (multimeter/inspector panels), never a canvas module | E | V2 modules are not resizable at all; no canvas-node resize visual exists to reproduce. `StudioSceneNode` also carries no size-editing signal for the V2 path |
| Box selection (marquee) | grepped `main.css` and every `js/` file for `marquee`/`box-select`/`selection-rect` | E | No such concept anywhere in the V2 reference — modules are selected one at a time via click; nothing rendered for this in V2 |
| Connection preview | `wireMode&&wireSrc&&mcX` line | A | Already correct (AP-DIAGRAM-V2-007) |
| Connection-preview target-port highlight | no such highlight in `renderer.js`'s preview block — the preview is just the dashed line, no target-terminal treatment beyond the terminal's own general `:hover`/`.wh` (already covered above) | A (nothing further needed) | No gap — V2 has nothing beyond what V2-007/009 already cover |
| Wire-edit-mode route vertices/segment handles | `routeEditMode&&isSel` block in `drawWires()` — real visual (segment hit-lines, highlight overlays, midpoint handle dots, `#22d3ee`-based) | **C**, deliberately not attempted | V2's segment handles operate on `getMovableSegs()` — segments V2 classifies as "movable" under its own differential per-segment-offset route model (`wireRoutes[id]`). OEP's `_wireEditWorkingPoints` is a plain absolute point list with no equivalent "which segments are movable" classification. Reproducing V2's exact handle set would require either (a) inventing a movable-segment classifier Studio-side (a real algorithm, not a "smallest correction" — same shape of risk this document's own §13 already flagged and declined to resolve for the base route model), or (b) drawing a generic vertex-per-point overlay that doesn't actually correspond to V2's own segment concept, which would be presenting an invented visual as if it were V2's. Neither is a safe "implement the smallest correction"; documented here as the conflict this task's own §7 instructed to stop at, not papered over |
| Reconnect | grepped every `js/` file and `main.css` for `reconnect` | E | No reconnect concept exists in V2 at all — its model is delete-and-recreate, not drag-an-existing-endpoint. `_reconnectRelationshipId`/`_reconnectIsSourceEnd`/`_reconnectCurrentPoint` have no V2 visual to map to |
| Alignment guides | grepped every `js/` file and `main.css` for `guide`/`snap-line`/`align` (excluding CSS `align-items` false positives) | E | No guide-line visual exists in V2 |
| Wire/flow animation | `startFlowAnim`/`addFlowOverlay` | Already excluded (AP-DIAGRAM-V2-004/005's own scope) | Unchanged — would need a ticker/AnimationController, explicitly out of scope by this task's own stop condition 10 even if otherwise in-scope |

**Rendering architecture:** unchanged — `V2CanvasHost`/`V2ModuleCard`/
`_V2PortDot`/`V2WirePainter`/`V2ConnectionPreviewPainter` remain
separate, single-purpose components. No "InteractionController" or
similar was created; `dragNodeIds` is threaded through exactly like
`hoveredPort`/`activeSourcePort` already were — a plain read-only field,
page → `V2CanvasHost` → `V2ModuleCard`.

**Rebuild scope:** zero new listeners. `dragging` is a plain
per-card `bool` computed from `Set.contains` at build time, same
mechanism as every other state flag this renderer already reads
(`node.selected`, `hoveredPort ==`, etc.) — no `ValueListenableBuilder`,
no `AnimatedBuilder`, no Riverpod state. The E1
`_cursorScenePositionNotifier` optimization is untouched (module drag
doesn't read cursor position through this widget at all — it reads
`_dragNodeIds`, a plain `Set<String>?` `State` field already updated by
the existing, unmoved drag-handling code).

**Interaction-state migration status:** none. All ~40 fields listed in
this task's own inventory remain exactly where they were —
`DiagramStudioPage`'s own `State`. This task added exactly one new
read-only parameter path (`dragNodeIds`) reusing an existing field,
matching the same pattern `hoveredPort`/`activeSourcePort`/connection-
preview state already established.

## 28. V2 Wire-Edit Model Resolution — CASE C, blocked (AP-DIAGRAM-V2-011)

**V2 wire-edit reconstruction is blocked by an Engine model mismatch. No
Studio shadow route model was introduced.** This section is the formal
record required by that decision — see acceptance criteria below for
what this task actually delivered (documentation + one empirical test,
zero renderer code).

### V2's route model (`js/diagram/renderer.js`, `js/editor/routing-editor.js`, `js/app.js`, `js/storage/project-{saver,loader}.js` — read in full)

- **Representation:** a wire's rendered path is **recomputed from
  scratch on every single `drawWires()` call** (`route(w)`), from the
  two terminals' *current* scene positions plus each module's `exit`
  direction, using dynamic lane allocation (`allocX`/`allocY`, mutable
  `usedX`/`usedY` `Set`s reset once per full redraw pass — allocation is
  therefore order-dependent across *all* wires, not per-wire).
- **Manual edits are never absolute points.** `wireRoutes[w.id]` is a
  sparse `{segmentIndex: numericOffset}` map. `getMovableSegs(pts)`
  classifies which segments of the *freshly computed* path are
  "movable" (interior segments, not the two terminal stubs) and assigns
  them positional indices `0..n`; `route()` reapplies each stored offset
  to whichever segment currently sits at that index, `if(seg.axis==="y")
  {c[i1].y+=off;c[i2].y+=off} else {…x…}`.
  **The offsets are differential and index-relative to a path that gets
  rebuilt every render** — they are not tied to any absolute coordinate
  or persistent point identity.
  - Selected vertex: not a first-class concept — `routing-editor.js`
    tracks `selSeg` (`{wid, segIdx, axis}`), a **selected segment**, not
    a vertex; there is no separate vertex-selection state in the V2
    reference at all.
  - Handles: rendered live, every redraw, from the *current* `movable`
    array (`drawWires()`'s `routeEditMode&&isSel` block) — a wide
    invisible hit-line per segment, a visible highlight overlay, and a
    midpoint dot, always recomputed, never cached.
  - Drag: `app.js`'s pointer handler increments
    `wireRoutes[selSeg.wid][selSeg.segIdx]` by the drag delta and
    re-invokes `drawWires()` — every frame reruns the *entire*
    recompute-then-offset pipeline above.
  - Undo/redo: **V2 has no undo/redo system at all** (confirmed —
    no `undo`/`redo`/history/command-stack code exists anywhere in the
    reference). A route edit is simply a live mutation to the
    `wireRoutes` object.
  - Persistence: `wireRoutes` (the differential offset map, keyed by
    wire id) is saved and restored verbatim
    (`project-saver.js`/`project-loader.js`) — **V2 persists offsets,
    never absolute points**, for an edited wire.
  - **Node movement:** since the base path is recomputed from the
    node's *current* position on every render, moving a node
    automatically reflows the whole route, and the stored offsets keep
    nudging whatever segments end up at the same index in the new path.
    This "live reflow + reapplied relative nudge" behavior is the
    feature the V2 reference actually implements — not an incidental
    detail.

### OEP's route model (`diagram_view.dart`, `diagram_layout_state.dart`, `set_wire_route_command.dart`, `move_nodes_command.dart` — read in full)

- **Representation:** `DiagramView.render()`:
  `points = layout?.wireOverrideOf(relationshipId) ?? routing.route(...)`.
  With **no** override, a wire *is* live-routed every render, much like
  V2's normal case. But **once an override exists, it is used verbatim,
  forever, and routing is never consulted again for that wire** — there
  is no reapplication, no differential offset, no "movable segment"
  concept at all.
- `SetWireRouteCommand` (the command behind
  `DiagramStudioController.setWireRoute`, itself behind the existing
  `WireEditHandles` drag interaction) writes the **full absolute point
  list** into `DiagramLayoutState.wireOverrides[relationshipId]` —
  confirmed by reading the command in full.
- **Node movement:** grepped every command in
  `oep_engine/lib/core/editing/commands/` for `wireOverride` — the
  *only* file that touches it is `set_wire_route_command.dart` itself.
  `MoveNodesCommand` never reads or writes `wireOverrides`. **A manually
  routed wire's stored points are completely unaffected by the
  connected node's position changing** — confirmed empirically by a new
  test (see below), not just by reading source.
- Undo/redo: `SetWireRouteCommand.revert()` restores the exact previous
  override (or its absence) — a normal, working `EditingCommand`, fully
  compatible with the existing undo/redo stack.
- Persistence: `DiagramLayoutState.wireOverrides` round-trips through
  `toJson`/`fromJson` as absolute point lists — confirmed already
  exercised by existing persistence tests elsewhere in this suite.

### Formal comparison

| Capability | V2 | OEP | Compatible? |
|---|---|---|---|
| Absolute route points | Never stored (recomputed every render) | Stored verbatim once an override exists | **No** — opposite storage models |
| Relative segment offsets | The *only* persisted edit representation | Does not exist at all | **No** |
| Segment movement | Reapplies an offset to whichever segment lands at a given index in a freshly-computed path | Directly mutates specific absolute points via `WireEditHandles`'s corner/segment drag, written straight into the override | Superficially similar UI gesture, incompatible underlying representation |
| Vertex movement | No vertex concept (segment-offset only) | First-class (`_wireEditSelectedVertex`, corner handles) | **No** — OEP has a concept V2 doesn't |
| Node-movement preservation | Route always reflows; offsets persist as relative nudges | Override is inert to node movement — **verified empirically**, see test below | **No — the load-bearing incompatibility** |
| Dynamic rerouting | Every render, unconditionally (until overridden, and even offsets are *reapplied* each render) | Only when no override exists; once set, routing never runs again for that wire | **No** |
| Route persistence | Differential offsets, index-relative | Absolute points | **No** |
| Route restoration | Offsets reapplied to a freshly recomputed path on load | Points loaded and used as-is, no recomputation | **No** |
| Undo/redo | Does not exist in V2 at all | Full command-based undo/redo, already working | N/A (nothing to compare against) |
| Selected vertex | Does not exist in V2 (segment-only) | Exists (`_wireEditSelectedVertex`) | **No** — OEP concept has no V2 analog |
| Selected segment | `selSeg{wid,segIdx,axis}` | No direct analog (OEP's `_wireDragSegmentIndex` addresses a segment by *position in the current point list*, not by a stable "movable index" independent of geometry) | Partial, but the index semantics differ (see below) |
| Route handles | Recomputed live from the *current* freshly-routed path every render | Recomputed live from the *current* override/points every render | Superficially compatible rendering pattern, but over incompatible underlying data |
| Route allocation | Dynamic, cross-wire, order-dependent lane allocation (`allocX`/`allocY`) | `OrthogonalRoutingProvider`, a different algorithm entirely (frozen Engine) | **No**, and irrelevant once an override exists in either system |

### Why a Studio adapter cannot solve this (CASE B ruled out)

A lossless Studio-side adapter would need to derive, at render time, "V2
differential offsets relative to a freshly-recomputed base path" from
OEP's absolute override points — but OEP's Engine **never recomputes a
base path once an override exists** (`DiagramView.render`'s own
short-circuit, frozen). Deriving V2-shaped offsets would require Studio
independently reimplementing `OrthogonalRoutingProvider`'s output
client-side just to have something to diff against — a second,
Studio-owned routing computation that could silently diverge from what
Engine would actually produce. That is exactly the "shadow route model"
Phase 6 of this task forbids, not a legitimate adapter: it doesn't
*translate* OEP's real data, it *invents a parallel computation* OEP
has no record of and does not participate in. Separately, node-movement
behavior itself could not be made to match V2 without also changing
*when* Engine re-routes an overridden wire — which is
`DiagramView.render`'s own logic, frozen.

### What would theoretically be required in Engine (documented, not pursued)

`DiagramLayoutState.wireOverrides` would need to become — or be joined
by — a differential/index-based representation, and
`DiagramView.render` would need to stop short-circuiting on
"override present" and instead *always* run `routing.route(...)`, then
reapply stored offsets to the result (mirroring V2's `route()` exactly).
This is a genuine Engine architecture change (new layout-state shape,
new render-time behavior, likely a routing-provider contract change to
expose "movable segments" the way V2's router does) — explicitly out of
this task's authority, and not attempted.

### What the current (Engine, frozen) renderer already does

Unchanged and unaffected either way: `GraphViewPanel`/`WireEditHandles`
already implement OEP's own real absolute-point wire-edit UX (corner
drag, segment drag, insert/remove vertex) against `SetWireRouteCommand`
— a complete, working feature on its own terms, just not V2's terms.
This task did not touch it.

### Node-movement test (empirical, not just source-reading — task's own Phase 11 requirement)

`test/diagram_studio/controller/diagram_studio_wire_route_model_test.dart`
(new): creates two nodes and a wire, sets a manual multi-segment route
via the real `SetWireRouteCommand` (through
`DiagramStudioController.setWireRoute`, the exact path the existing
`WireEditHandles` interaction already uses), moves one connected node
900 units away via the real `MoveNodesCommand`, and asserts the wire's
stored override points are **byte-for-byte unchanged** — confirming, by
executing real Engine commands rather than only reading source, that
OEP's model cannot reproduce V2's "edited routes still reflow with node
movement" behavior. Test passes, confirming the CASE C classification.

### Architectural recommendation

Do not build a V2-style route editor over the current model. Two real
options exist for a future task, both explicitly Engine-authority
decisions outside this document's scope to make unilaterally:
1. **Leave OEP's absolute-override model as the permanent design** —
   it already works, is undo/redo-compatible, and is simpler to reason
   about than V2's index-fragile differential scheme (V2's own
   `getMovableSegs` index mapping silently breaks/no-ops if a wire's
   topology or exit directions change between edits — a real fragility
   OEP's model doesn't share). In this case, a *V2-styled visual* for
   OEP's *own* absolute-point wire-edit interaction (matching V2's
   handle/segment-highlight *appearance* while keeping OEP's own
   semantics, similar in spirit to how V2-004/005's wire rendering
   already adapts V2 visuals onto OEP's own absolute point lists) is
   still possible as a future, separately-scoped task — that is a pure
   rendering exercise, not a model change, and was not attempted here
   only because this task's own scope was the model-compatibility
   question first.
2. **Redesign `DiagramLayoutState`'s route representation to be
   differential**, matching V2 — a real Engine/SDD-level architecture
   decision (schema change, persistence migration, render-time
   behavior change), requiring explicit authorization and design review
   before any implementation task begins.

This document takes no position on which option is preferable — that is
a product decision, not an architectural fact this analysis can settle
on its own.

## 29. V2 Wire-Edit Visual Reconstruction Over OEP's Existing Model (AP-DIAGRAM-V2-012)

**This is option 1 from §28's recommendation, scoped to visuals only.**
V2 visual language is adapted to OEP route semantics; V2 differential
route semantics are not implemented. The §28 CASE C decision stands
unchanged — nothing here revisits it.

**V2 visual source** (`renderer.js`'s `routeEditMode&&isSel` block
inside `drawWires()`, read again in full for this task): per segment, a
visible highlight line (`stroke:isActiveSeg?"#22d3ee":"rgba(34,211,238,.35)"`,
width `3`/`2`) and a midpoint handle dot (`r:isActiveSeg?"5":"3.5"`,
fill `isActiveSeg?"#22d3ee":"rgba(34,211,238,.7)"`, `stroke:"#0e7490"`).
V2's own "active" (`isActiveSeg`) means *persistently selected*
(`selSeg`), not merely mid-drag — V2 has no separate transient
drag-highlight beyond its own selection state.

**OEP interaction semantics consumed, unchanged:** `_wireEditWorkingPoints`
(the exact absolute point list `WireEditHandles` already renders and
`SetWireRouteCommand` already commits — nothing new was read or
computed), `_wireEditSelectedVertex` (persistent vertex selection, used
for "Remove Vertex"), `_wireDragCornerIndex`/`_wireDragSegmentIndex`
(set only while a handle is actively being dragged). All four are
`DiagramStudioPage` `State` fields, untouched, read-only from
`V2WireEditOverlay`.

**Visual mapping**

| OEP concept | V2 visual analogue | Safe to adapt? | Why |
|---|---|---|---|
| Wire-edit mode active | Route-edit segment highlight/handle appearance | Yes | Same underlying purpose — "these are the editable parts of this wire" — regardless of route-model differences |
| OEP segment (between two consecutive absolute points) | V2 segment (`getMovableSegs` entry) | Yes, geometrically | Both are "the line between two adjacent route points" at the moment of rendering; only the *persistence*/*recomputation* semantics differ (§28), not the instantaneous geometry a handle sits on |
| OEP segment drag (`_wireDragSegmentIndex`) | V2 "active" segment (`isActiveSeg`) | Yes, as the closest honest analog | V2's "active" means *selected*, not *dragging* — OEP has no persistent segment-selection state to read instead, so "currently being dragged" is the nearest real OEP signal, not a literal copy of V2's semantics. Documented, not silently assumed equivalent |
| OEP vertex/corner (`_wireEditSelectedVertex`, `_wireDragCornerIndex`) | **No V2 analogue exists** | N/A — retained as OEP's own concept | V2 has no vertex-selection state at all (confirmed, re-read `routing-editor.js`/`wire-editor.js` — only `selSeg`). Rather than dropping OEP's real, working vertex-selection feature to force a literal V2 match, this overlay extends V2's *palette* (the same `#22d3ee`/`rgba(34,211,238,…)` family) onto OEP's own vertex handles for visual consistency — a styling choice, not a fabricated V2 behavior |
| Selected vertex | Same palette, larger/brighter (same visual "weight" V2 gives its own active state) | Yes, as styling only | No V2 rule to contradict — V2 simply doesn't have this concept, so no V2 rule is being misrepresented |
| Fixed endpoint anchors (index 0, last) | No V2 analogue (V2's route always starts/ends at the same computed terminal points, never user-editable) | Retained as OEP's own concept, dimmed | Matches `WireEditHandles`'s own established convention (`isAnchor`, non-draggable) — rendered small/muted, not styled as if editable |
| Active drag (corner or segment) | V2's `isActiveSeg` glow/size | Yes | Direct visual reuse; drives from OEP's real transient drag state, not a fabricated one |
| Route preview during drag | **Not implemented** | N/A | The current renderer's own `WireEditHandles` does not redraw the wire's *stroke* during a drag either (`WirePainter` still draws the last-committed `scene.wires` points; only the handles themselves move) — `V2WirePainter` was left exactly as unchanged for the same reason, matching that existing, accepted OEP UX rather than inventing a live-stroke-follows-drag behavior neither renderer has today |
| Endpoint visual | Small dimmed anchor dot (see above) | Partial | V2 has no distinct terminal-vs-interior-point visual either (its terminals are plain path endpoints, not decorated) — OEP's dimmed anchor is a modest addition for legibility, not a V2 rule |

**Route model preserved, no shadow model:** `V2WireEditOverlay` performs
zero geometry computation of its own — it draws lines/dots directly at
the `Point2D`s it's given. No differential offsets, no `wireRoutes`-style
persistence, no alternate route authority, nothing stored anywhere new.
Confirmed by inspection: the painter has no fields beyond the four
read-only inputs above, and no method that writes anything.

**Undo/redo:** unaffected — `SetWireRouteCommand`/`DiagramStudioController`
were not touched. Since the overlay only reads `_wireEditWorkingPoints`
(itself re-seeded from the committed relationship's points whenever wire
edit mode is (re-)entered — `_reseedWireEditPoints`, unchanged), an
undo/redo that changes the committed route is reflected correctly the
next time the overlay paints, same as `WireEditHandles` already behaves.

**Node movement:** unaffected, by design — this task changed nothing
about *when* or *whether* a route reflows (§28's CASE C stands). If a
wire has no override, moving a node still live-reroutes it exactly as
before, and the overlay (only ever shown while that specific wire is
being edited) draws whatever `_wireEditWorkingPoints` currently holds —
OEP's real, current geometry, never a V2-style differential guess.

**Pan/zoom:** no new transform. `V2WireEditOverlay` is placed inside
`V2CanvasHost`'s existing scene-space `SizedBox`, the same
`InteractiveViewer`-transformed subtree every other V2 layer already
uses — verified by the existing coordinate-system tests plus the new
`v2_canvas_host_wire_edit_test.dart` cases, which construct the host
directly (no live pan/zoom interaction needed to prove the geometry is
untransformed at the painter level, consistent with every prior V2
painter's own test pattern).

**Layering:** painted above module cards — a deliberate difference from
V2's own DOM order (V2's segment handles technically live inside its
wire SVG layer, beneath its module layer) but matching the *current*
renderer's own choice (`WireEditHandles` also paints after the node loop
in `GraphViewPanel`'s `Stack`) for a concrete reason: handles hidden
under a card are not usable, and this task's own instruction permitted
"a minimal layering adjustment" without requiring a literal DOM-order
match to a reference that predates any hit-testing on this Studio-owned
overlay anyway (this painter does no hit-testing at all — see below).

**Performance/rebuild scope:** zero new listeners, zero new state.
`wireEditWorkingPoints`/`wireEditSelectedVertex`/
`wireEditActiveCornerIndex`/`wireEditActiveSegmentIndex` are plain
constructor parameters threaded from the page exactly like every other
V2 painter input (`hoveredPort`, `dragNodeIds`, etc.) — no
`ValueListenableBuilder`, no `AnimatedBuilder`, no Riverpod state. The
E1 `_cursorScenePositionNotifier` optimization is untouched (this
overlay never reads cursor position).

**No hit-testing, no interaction:** `V2CanvasHost` wraps the overlay in
`IgnorePointer`, identical to `V2ConnectionPreviewPainter`'s own
pattern — dragging a V2-rendered handle is not possible today (matches
the same "these V2 states can only change via the current renderer's
own handlers" limitation already disclosed for V2-007/009/010's own
overlays).

**Remaining wire-edit gaps:** V2's own route-edit segment-selection
persistence (`selSeg`) has no OEP equivalent to read (only transient
drag state) — documented above as the "active segment" mapping's own
honest limitation, not fabricated; no interaction/hit-testing on the V2
canvas for any of this (by this task's own explicit restriction); no
V2-style route-edit-mode toolbar/status text (out of this task's visual
scope, matches every prior task's own "no broad chrome" restriction).

## 30. Real V2 Canvas Interaction (AP-DIAGRAM-V2-013)

**Why this task exists:** every V2 visual built through AP-DIAGRAM-V2-012
(selection glow, port hover/active-source, connection preview, drag
shadow, wire-edit handles) could only ever be *observed*, never
*triggered*, while looking at the V2 canvas — `V2ModuleCard`'s ports and
`V2WirePainter`'s wires had no `GestureDetector`/`MouseRegion` of their
own, so all of that state could only change via the current renderer's
widgets (`GraphViewPanel`/`SymbolNodeWidget`), which aren't mounted
while V2 is showing. Confirmed directly by the user: switching to V2
mode, nothing could be selected, dragged, or connected. This task closes
that specific gap for the base interactions (select, drag, connect,
deselect) — not the more advanced ones (wire-edit dragging, reconnect,
box-select, resize), which remain visual-only, listed below.

**What was added, and to what it forwards (no new logic anywhere):**

| Gesture | Widget | Forwards to (unchanged `DiagramStudioPage` method) |
|---|---|---|
| Tap a module card | `V2ModuleCard.onTap` | `_handleNodeTap` |
| Drag a module card | `V2ModuleCard.onDragStart/Update/End` | `_handleNodeDragStart/Update/End` |
| Hover a port | `_V2PortDot` (`MouseRegion`) | `_handlePortHoverEnter`/`_handlePortHoverExit` |
| Tap a port | `_V2PortDot` (`GestureDetector`) | `_handlePortTap` (drives the existing two-click wire-creation flow) |
| Drag from a port | `_V2PortDot` (`GestureDetector`) | `_handlePortDragStart/Update/End` (drives the existing drag-to-connect flow) |
| Tap empty canvas or a wire | `V2CanvasHost`'s new background `GestureDetector` | `_handleBackgroundTap` (itself calls `DiagramHitTesting.relationshipAt` — the *same* wire hit-test the current renderer's own background layer already uses, so wire selection needed no new code at all) |

Every callback defaults to `null`; a `V2CanvasHost`/`V2ModuleCard`
constructed without them (every existing test from V2-007 through
V2-012, plus this task's own visual-only test cases) remains exactly as
non-interactive as before — nothing about the *default* behavior of
these widgets changed, only their *capability* when a caller opts in.

**A real bug this task's own tests caught, fixed:** `_V2DiagnosticPainter`'s
and `V2WirePainter`'s `CustomPaint`s had no `IgnorePointer`. A bare
`CustomPaint`'s default `hitTest()` is opaque (documented already in
`V2ConnectionPreviewPainter`'s and `V2WireEditOverlay`'s own doc
comments for exactly this reason), so both layers were silently
absorbing every pointer event before it could reach the new background
`GestureDetector` beneath them — the background-tap test failed against
the real render tree (not just logically) until both were wrapped in
`IgnorePointer`, matching the pattern already established for the
connection-preview and wire-edit overlays.

**Coordinate handling:** no new transform, and no zoom-adjustment math
was added to any drag handler — `details.delta` from a `GestureDetector`
nested inside `InteractiveViewer`'s transformed subtree is already
reported in that subtree's local (scene) coordinate space by Flutter's
own gesture-hit-testing machinery, the same reason the current,
frozen `SymbolNodeWidget`'s `onPanUpdate: (details) => onDragUpdate(details.delta)`
has never needed explicit zoom compensation either — verified by
reading that widget again for this task, not assumed.

**Layering / hit-test order:** module cards are painted (and therefore
hit-tested) *after* wires and the background layer in `V2CanvasHost`'s
`Stack`, so a tap on a card is claimed by that card's own opaque
`GestureDetector` before the background layer ever sees it — `RenderStack`
stops testing lower (earlier-painted) children once a topmost one
claims the hit. This is the same mechanism (and the same layering
choice) the current renderer's own `GraphViewPanel` already relies on,
verified directly by a new test (`v2_canvas_host_interaction_test.dart`'s
"does not also trigger onBackgroundTap" case).

**Still visual-only, deliberately, this task's own scope boundary:**
wire-edit-mode handle dragging (`V2WireEditOverlay` still has no
`GestureDetector` — AP-DIAGRAM-V2-012's own scope limit, not revisited
here), reconnect, box-select-drag, resize handles — none of these had
real V2 visuals to begin with either (§27's own inventory), so there
was nothing to wire interaction into yet. A future task's job, once
(if) their visuals are built.

**Performance/rebuild scope:** no new page-wide state, no new Riverpod
providers, no new `ChangeNotifier`. Every gesture forwards to a
`DiagramStudioPage` method that already existed and already drives
`setState`/`engine.registry.selection` exactly as it does for the
current renderer — this task added zero new rebuild triggers, only new
*paths* to the same existing ones. The E1
`_cursorScenePositionNotifier` optimization is untouched (none of these
handlers read or write it).

**Remaining gap, explicitly:** with V2 interaction now real, the
"observe-only" limitation documented in §§25/26/29 no longer applies to
node selection, node dragging, port hover, or wire creation/selection —
but still fully applies to wire-edit-mode handles, reconnect,
box-select, and resize, since none of those have interaction wired in
yet.

## 31. V2 Wire-Edit Handle Interaction (AP-DIAGRAM-V2-014)

**Existing OEP wire-edit handlers identified and reused verbatim (no
new logic):** `_handleWireVertexTap(int index)` (tap-to-select a
corner), `_handleWireCornerDragStart/Update/End` (drag a corner —
mutates `_wireEditWorkingPoints` via `WireEditing.dragCorner`, frozen
Engine, then commits via `DiagramStudioController.setWireRoute` on
drag-end), `_handleWireSegmentDragStart/Update/End` (drag a segment
midpoint — `WireEditing.dragSegment`, same commit path). All six were
already fully implemented and already wired to the current renderer's
own `WireEditHandles`; this task added zero new methods to
`DiagramStudioPage`.

**Existing OEP wire-edit state identified (unchanged, not migrated):**
`_wireEditWorkingPoints` (the live absolute point list being edited),
`_wireEditSelectedVertex` (persistent corner selection),
`_wireDragCornerIndex`/`_wireDragSegmentIndex` (which handle is
actively being dragged), `_wireDragBasePoints`/`_wireDragTotalDelta`
(drag-session scratch state, read only by the handlers above, never by
the V2 layer).

**V2 overlay interaction surface — a new sibling widget, not a change
to the existing painter.** `V2WireEditOverlay` (AP-DIAGRAM-V2-012)
remains exactly what it was: a pure-paint `CustomPainter`, still wrapped
in `IgnorePointer`, still with no hit-testing of its own — confirmed
unchanged by this task. A new widget, `V2WireEditHandles` (same file),
supplies the real interaction: one `Positioned`+`GestureDetector` per
corner (10x10 hit target) and one per segment midpoint (8x8), sizes and
the anchor tap-vs-drag split (index 0 and the last point are tappable
but not draggable) copied verbatim from the current, frozen renderer's
own `WireEditHandles` — not redesigned, not reinterpreted.

**Semantic mapping (OEP semantics used as-is, no invented V2
semantics):**

| OEP concept | V2 visual it drives | Interaction added |
|---|---|---|
| `_wireEditSelectedVertex` | The "selected control" cyan highlight `V2WireEditOverlay` already drew (AP-DIAGRAM-V2-012) | Now settable via a real tap — `onVertexTap` → `_handleWireVertexTap` |
| `_wireDragCornerIndex` | The "active control" cyan highlight (larger/brighter) | Now settable via a real drag — `onCornerDragStart/Update/End` → the existing corner-drag handlers |
| `_wireDragSegmentIndex` | The "active segment" cyan highlight (V2's own `isActiveSeg`) | Now settable via a real drag — `onSegmentDragStart/Update/End` → the existing segment-drag handlers, confirmed already supported by OEP (Phase 7's own question resolved: yes, `_handleWireSegmentDragStart/Update/End` already exist and already work) |

No V2 semantic was invented to fill a gap — every mapping above already
had both a real V2 visual (from V2-012) and a real, already-working OEP
handler; this task's only job was connecting the two.

**Hit-testing mechanism:** real Flutter widgets — `GestureDetector`
`onTap`/`onPanStart`/`onPanUpdate`/`onPanEnd` — not custom
`CustomPainter.hitTest()` math, not a new route-hit-test service, not a
second geometry model. `DiagramHitTesting` (Engine, used for wire
*selection*, AP-DIAGRAM-V2-013) was not involved here — wire-edit handle
hit-testing is inherently per-point/per-segment, not a "what's under this
pixel across the whole scene" query, so the current renderer's own
`WireEditHandles` widget-per-handle approach was the correct thing to
mirror, not `DiagramHitTesting`.

**Pointer-event layering:** `V2WireEditHandles` is mounted as the
topmost `Stack` child in `V2CanvasHost` — above module cards — so a
handle is never hidden under a card's own opaque `GestureDetector` (a
concern this task's own instructions specifically raised, given
AP-DIAGRAM-V2-013 already found layering bugs once). Re-verified the
diagnostic and wire-painter `IgnorePointer` wrapping from V2-013 is
still intact (unchanged); `V2WireEditOverlay`'s own `IgnorePointer` is
also unchanged — only `V2WireEditHandles` (the new sibling) is
interactive.

**Coordinate handling:** no new transform. Handle positions are
computed directly from the given `points` (already scene-space,
identical to what `V2WireEditOverlay` already paints), placed via plain
`Positioned` inside the same `InteractiveViewer`-transformed subtree
every other V2 layer uses. Drag deltas use `details.delta` directly, the
same convention established (and explained) in AP-DIAGRAM-V2-013 — no
zoom-adjustment math was added or was needed.

**Drag behavior:** during an active drag, `_wireEditWorkingPoints` is
the *only* geometry source — the V2 handles widget re-renders from
whatever that field currently holds after each `setState` the existing
handler already performs; no parallel copy of the route exists in the
V2 layer. Commit happens exactly where it always did: `..DragEnd()`
calls the existing `DiagramStudioController.setWireRoute`.

**Segment behavior:** OEP already supports segment dragging (confirmed
by reading `_handleWireSegmentDragStart/Update/End` — real, working,
already used by the current renderer), so this was wired directly; no
new segment model, no differential offsets, no V2 `wireRoutes`-style
persistence.

**Undo/redo:** unmodified — `SetWireRouteCommand`/`DiagramStudioController`
were not touched by this task, exactly as V2-012's own review already
confirmed for the read side; this task only adds the write-triggering
gesture on top of the same, already-undo/redo-compatible commit path.

**Node-movement behavior:** unaffected, verified by re-running
`diagram_studio_wire_route_model_test.dart` (AP-DIAGRAM-V2-011) — still
passes unchanged. A manually-routed wire's stored points still do not
reflow when a connected node moves; this task did not touch
`DiagramView.render`, `MoveNodesCommand`, or `wireOverrides` in any way.
CASE C stands.

**Pan/zoom:** verified structurally (no separate transform exists for
this widget to get out of sync with) and by the new
`v2_wire_edit_handles_test.dart`'s "pure function of points" case —
handle position depends only on the `points` list given, never on any
viewport/transform state read independently.

**Rebuild scope:** zero new state, zero new listeners, zero new
providers. Every gesture forwards directly to an existing
`DiagramStudioPage` method that already calls `setState` exactly as it
did for the current renderer — this task added no new rebuild triggers.
The E1 `_cursorScenePositionNotifier` optimization is untouched (no
handler here reads or writes it).

**Shadow-route-model confirmation:** none exists. `V2WireEditHandles`
holds no `List<Point2D>` field of its own beyond the `points` parameter
it's given each build (read, never mutated, never cached) — verified by
inspection: the widget has no other state, no `StatefulWidget`, no
persistence call anywhere in its source.

**A build-environment note, not a code issue:** `flutter build windows
--debug` could not complete during this task's own verification pass —
the developer's own `flutter run -d windows` session (kept open per this
task's hot-reload workflow requirement) held the `.exe` file lock,
producing `LINK : fatal error LNK1168`. `flutter analyze` was clean and
the full test suite passed; this is a file-lock artifact of the
required manual-verification workflow, not a code defect.
