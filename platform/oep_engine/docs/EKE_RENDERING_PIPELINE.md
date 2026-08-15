# EKE Rendering Pipeline (ENGINE-TASK-000070)

How `apps/simulator/diagram/renderer.js` actually draws a diagram, and
what that means for the Engineering Engine's View/rendering layer. No
DOM/CSS/SVG implementation detail is proposed for migration — only the
*sequence* and *concepts* are analyzed.

---

## Technology (not migrated, noted for context only)

Hybrid **DOM + SVG**, no canvas for the diagram itself — components
render as absolutely-positioned DOM elements (`.mod-card`), wires render
as an SVG `<path>` overlay (`#wire-layer`). The one real `<canvas>` is the
minimap. This is purely an implementation detail (explicitly forbidden to
migrate per WORK_PACKAGE_019/020); the Engineering Engine's
`DiagramScene` + Flutter `CustomPainter`/`flutter_svg` approach (ADR-003)
is architecturally unrelated and intentionally so.

## Scene generation

There is no separate "build a scene description, then render it" step in
the reference — `renderer.js` computes layout and paints in the same
pass. Concretely: `placeCards()` creates any missing DOM cards and
repositions all of them from the current `positions` map; `drawWires()`
clears the SVG layer and rebuilds every wire's path fresh (not
incrementally). This conflates what the Engineering Engine deliberately
separates: `DiagramView.render(graph) -> DiagramScene` (pure data, no
painting) versus the Demonstration Host's `CustomPainter`/widget tree
(paint only). That separation (ADR-003) is a genuine improvement,
confirmed as worth keeping by this analysis — the reference's
conflated approach makes swapping renderers or testing layout logic
without a DOM harder than it needs to be.

## Rendering sequence (per `drawWires()` call)

1. Clear the SVG wire layer.
2. Reset routing-allocation state (`usedX`/`usedY` — tracks which grid
   lanes are already occupied, so parallel wires don't overlap).
3. For each wire: compute an orthogonal route (`route(w)`) → draw a glow
   path first (if selected or traced) → draw the main colored path → draw
   a bicolor stripe overlay (for striped wire-color codes, e.g. `R/W`) →
   in Route Edit mode, draw segment-handle markers; otherwise draw a wide,
   invisible hit-path for easier clicking → draw the flow-current overlay
   (if animating) → draw a label badge (if selected) → draw meter-lead dot
   markers (if probes are placed) → append the assembled group to the SVG.
4. `placeCards()` (separate call, components): create any missing cards,
   then reposition every card from the `positions` layout map. Cards are
   mutated in place, never destroyed and recreated on every redraw.

## Component rendering

Type-specific card builders (`buildCard`/`buildStdCard`/`buildBulbCard`/
`buildConnCard`) — components are not one generic shape; a lamp/bulb card
and a connector card render meaningfully differently from a standard
component card. This maps naturally onto the Engineering Engine's
Symbol Library (SDD-028): different `SymbolCategory`/`geometry` per
symbol already gives the Demonstration Host the same "not everything
looks the same" capability, achieved through data rather than
type-specific builder functions — an improvement, not a gap.

## Wire rendering

Orthogonal auto-routing (see `EKE_ALGORITHMS.md` for the algorithm
itself) with lane allocation to avoid overlapping parallel runs,
bicolor/striped rendering for compound wire-color codes, and a
wide-invisible-hit-path trick so a thin visual line still has a generous
click target. The Demonstration Host's Phase 1 `WirePainter` currently
draws only straight lines between node centers — this is the single
biggest concrete rendering gap versus the reference.

## Layer / z-ordering

DOM stacking order plus one CSS class bump (`.dragging` raises z-index
during a drag) — components implicitly layer above the SVG wire plane
because of element order in the document, not an explicit z-index
scheme. Nothing here needs migrating; the Engineering Engine's
`SymbolRenderingMetadata.layer` field (SDD-028, already implemented in
Phase 1) is a more principled, explicit answer to the same problem.

## Highlight & selection rendering

Fully described in `EKE_INTERACTION_MODEL.md` — amber glow for the
single selected wire, green glow for anything in the traced-path set,
10%-opacity dimming for everything else when either is active. The
dimming behavior is the one concrete gap flagged for migration.

## Grid

Not rendered as a visible background grid in what was found — the "grid"
that exists is a 10px position-snapping behavior during drag, not a
drawn grid overlay. (If a visible grid exists elsewhere in the CSS
layer, it wasn't confirmed in this pass; treat as unconfirmed rather than
absent.)

## Viewport, zoom, pan

Covered in full in `EKE_INTERACTION_MODEL.md`. Rendering-relevant point:
zoom/pan apply a single CSS transform to a `#scene` wrapper rather than
recomputing per-element positions — meaning pan/zoom performance is
"free" (GPU-composited transform) regardless of diagram size, while
`drawWires()`'s full-rebuild-every-time approach is the part that scales
with element count.

---

## Performance observations

- **Pan/zoom is O(1)** regardless of diagram size (single CSS transform).
- **`drawWires()` is a full rebuild on every call**, not incremental —
  acceptable at the reference's scale (a single vehicle's wiring diagram,
  tens of components) but would not scale gracefully to a much larger
  graph without becoming a redraw bottleneck, since every wire's route is
  recomputed from scratch even if only one wire or one selection changed.
- **No render loop** — this is a genuine strength, not a limitation
  (there's nothing to optimize away; work only happens when state
  actually changes), except for the one current-flow animation, which
  correctly starts/stops based on whether anything needs animating rather
  than running unconditionally.
- **Card mutation-in-place** (`placeCards()` only creates missing cards)
  avoids DOM churn on every redraw — a sound pattern regardless of
  target framework.

## Migration recommendations

1. **Keep the scene/paint separation the Engineering Engine already has**
   (`DiagramView.render` → `DiagramScene` → host painter) — the reference
   analysis confirms this is an improvement over the reference's
   conflated approach, not a stylistic risk.
2. **Migrate orthogonal wire routing with lane allocation** — currently
   the largest concrete rendering gap (Phase 1's `WirePainter` draws
   straight lines only). See `EKE_ALGORITHMS.md` for the algorithm shape.
3. **Migrate "dim everything not selected/highlighted"** as a `DiagramScene`
   concept (e.g. an opacity/dimmed flag alongside `selected`/`highlighted`
   on `DiagramNodeVisual`/`DiagramWireVisual`) — small, high-value,
   directly portable.
4. **Consider incremental scene diffing before this becomes a bottleneck**,
   not because the reference needs it (its scale doesn't demand it) but
   because Flutter's `CustomPainter` repaint cost scales similarly with
   primitive count — worth a `shouldRepaint` check keyed on scene identity
   rather than assuming Flutter's default behavior is sufficient at
   larger graph sizes. This is a forward-looking recommendation, not
   something the reference demonstrates a need for.
5. **Do not migrate DOM/CSS/SVG mechanics** — already excluded by scope,
   restated here for completeness since this document's subject is
   rendering.
