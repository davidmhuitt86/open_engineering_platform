# EKE Interaction Model (ENGINE-TASK-000069)

How the reference simulator's interactions are structured and how they
cooperate — not the DOM/CSS mechanics, which are explicitly out of scope
to migrate.

---

## The organizing principle: exclusive modes over global state

There is no central state store/reducer. A handful of global mutable
variables (`editMode`, `wireMode`, `routeEditMode`, `selW`, `selM`,
`selSeg`, `keyPos`, `scale`/`tx`/`ty`) drive the entire application, and
exactly one "edit mode" is active at a time: **normal**, **Layout Edit**
(`E`), **Wire** (`W`), or **Route Edit**. Each mode unlocks a different
interaction set (drag-to-move only in Layout Edit; click-to-connect only
in Wire mode; segment-nudge only in Route Edit) and every state change is
followed by an explicit imperative re-render (`drawWires()`/`applyT()`) —
there is no reactive/observer re-render triggered automatically by state
mutation.

This is a coherent, simple architecture for a single-page app, but it is
the direct opposite of the Engineering Engine's design: `SelectionService`
and `NavigationService` expose typed `Stream`s that consumers subscribe
to (SDD-026), and `EngineRegistry` mediates all capability access. The
reference's global-variable approach is explicitly **not** being migrated
— see `EKE_GRAPH_COMPARISON.md` "Improved concepts."

## Selection

Single-selection only, and independently tracked per kind: `selW` (one
wire) and `selM` (one module) are separate variables — selecting a module
does not clear a wire selection and vice versa. Selecting a wire toggles
it (click again to deselect); selecting a module opens its info panel.
**No multi-selection exists anywhere** — not a documented future goal,
just genuinely absent. Selection propagates directly and synchronously to
the property inspector and the right-sidebar Circuit Trace panel — no
event bus, just a function call chain.

Engineering Engine parallel: `SelectionService.current` (a single
`SelectionState`) already matches this "exactly one thing selected"
model — Phase 1 deliberately kept selection singular, and this analysis
confirms that's consistent with the reference's proven interaction shape
rather than an oversight. Multi-selection would be new design work, not a
migration.

## Hover

Minimal — only terminal dots get a hover affordance (`.wh` class), and
only while in Wire mode or lead-placement mode (a visual cue that "you
can click here right now"). No general hover-to-preview or hover-to-
tooltip behavior exists for components or wires.

## Highlighting

Cleanly split three ways, confirmed by code tracing (not just the
design docs):

1. **`selection-manager.js`** — click-driven, holds `selW`/`selM` only.
2. **`path-highlighter.js`** — algorithmic. `PathHighlighter.showPowerPath
   /showGroundPath/showChargingPath/showCircuit` compute a wire-id set via
   diagnostics modules (`PowerPath`, `GroundPath`, `PathFinder`,
   `CircuitTracer`) and assign it to a global `tracedWires` Set — this
   module never touches rendering directly.
3. **`renderer.js`** — the sole consumer of both. `drawWires()` applies:
   full-opacity + amber glow for `selW`, full-opacity + green glow for
   anything in `tracedWires`, and 10%-opacity dimming for everything else
   whenever either a selection or a trace is active.

This traversal-computes/state-holds/renderer-paints three-way split is
the single cleanest interaction pattern found in the reference and is
already the shape the Engineering Engine adopted independently:
`NavigationService.highlightPathBetween` computes a path via
`GraphTraversal.findPath` and emits a `NavigationEvent`; the
Demonstration Host (acting as the "renderer") applies `runtime.highlighted`
to the graph and repaints. The one behavior worth migrating that Phase 1
doesn't yet have: **dimming everything not selected/highlighted**, which
meaningfully improves legibility on a busy diagram and was not part of
the Phase 1 scene model.

## Dragging

Drag-to-move exists **only** in Layout Edit mode; in every other mode,
cards are not draggable at all — this is a deliberate guard against
accidental layout changes while wiring or navigating. Movement snaps to a
10px grid and only ever touches layout/position data, never the graph
(confirmed directly in code, matching the documented rule). Wires
attached to a moved component re-route automatically after the drag.

## Connection

Click-click, not drag-to-wire: toggle Wire mode → click source terminal →
live dashed preview line tracks the cursor → click destination terminal →
wire created, duplicate connections rejected with a toast, Wire
Properties modal auto-opens. This is real, working, deliberately
lightweight interaction — worth migrating close to as-is (see
`EKE_WORKFLOWS.md` "Connect Components").

## Keyboard shortcuts

A global keydown handler with roughly 15 bindings: mode toggles (`E`
Layout, `W` Wire, `F` Fit View), utility (`/`/`?` Search, `L` Legend,
`Ctrl+Shift+G` Graph Inspector), key-position selection (`0`–`3`),
`Delete` (context-sensitive — deletes selected wire outside edit mode),
and Route-Edit-mode-specific arrow-key nudging (Shift = 4× step, `R`
reset). `Escape` is notably designed as a **cascade**: it closes
lead-placement, then route-edit, then wire-mode, then any open modal,
then search, then the module panel, then wire selection — one key that
"backs out" one layer at a time rather than a blunt "close everything."
This cascade pattern is a genuinely good, migratable UX idea independent
of any specific binding.

## Context menus

Right-click on a wire or a module opens a shared context menu
(`#ctx`), with its item list filtered by target type (Edit/Trace/Route/
Probe(+)/Probe(−)/Delete for wires; a corresponding set for modules).
One shared menu element, contextually populated, rather than separate
menus per element type — a reasonable pattern to preserve.

## Viewport (pan/zoom)

Three plain numeric globals (`scale`, `tx`, `ty`) applied as a single CSS
transform. Zoom is available via Ctrl/Cmd+scroll-wheel (zoom-to-cursor —
the zoom center is the cursor position, not the viewport center), toolbar
buttons, and two-finger pinch on touch. Pan is drag-background, Space+drag
(available in any mode, an important escape hatch so panning never
requires leaving Wire or Route Edit mode), middle-mouse-button drag, or
one-finger touch-drag. "Fit View" computes a scale that fits the content's
bounding box into the current viewport. All of this is **on-demand,
imperative** — there is no per-frame render loop for the diagram itself
(the one exception, current-flow dash animation, does use
`requestAnimationFrame`, started/stopped based on whether any wire
currently carries flow).

Engineering Engine parallel: the Demonstration Host's `InteractiveViewer`
already covers basic pan/zoom (Phase 1). Zoom-to-cursor and Fit-View are
the concrete, well-defined gaps to migrate.

## Undo / Redo

**Functionally absent**, despite `editor/undo-redo.js` defining a complete,
correctly-designed `UndoRedoStack` class (execute/undo/redo/canUndo/
canRedo, max depth 50, exactly the Command pattern) — it is never
instantiated or imported anywhere; no edit action creates a command or
pushes to any stack. Every edit (move, add/delete component, add/delete
wire, route nudge) is an immediate, irreversible mutation of global state.

This is worth calling out plainly as a gap rather than a design choice
to imitate: the reference itself documents a Command-pattern intent it
never followed through on. If/when real editing is implemented in the
Engineering Engine (explicitly out of scope for this work package), the
Command pattern shape the reference sketched is sound and worth using —
just actually wiring it up this time.

## How it all cooperates — summary

```
Global mode (exclusive)
  -> gates which interactions are even possible (drag only in Layout Edit,
     click-to-wire only in Wire mode, nudge only in Route Edit)
  -> Escape cascades back out one layer at a time

Selection (selW / selM, independent)
  -> syncs directly to Property Inspector + Circuit Trace panel

Highlighting (path-highlighter, independent of selection)
  -> computes tracedWires via diagnostics traversal

Renderer (sole consumer of both selection and highlight state)
  -> applies visual treatment, on explicit re-render calls only

Viewport (scale/tx/ty, independent of all the above)
  -> pan available in every mode via Space/middle-click, an important
     safety valve so navigation never fights with editing modes
```

No reactive framework, no central store — direct function calls against
shared globals, gated by an exclusive mode flag. Simple, and it works for
a single-page app of this size; the Engineering Engine's stream-based
services (SDD-026) are a deliberate improvement for a multi-consumer,
multi-View architecture, not a stylistic preference.
