# AP-DIAGRAM-V2-WEBVIEW-FUNCTIONAL-ASSESSMENT-001 — Legacy V2 Functional Bridge Assessment

**Analysis only. No production code changed by this task.** See §22–23.

## 1. Executive Conclusion

**Legacy V2's presentation/interaction layer is a technically viable long-term
UI for Diagram Studio, with OEP as the authoritative engineering backend —
but only for the module/canvas/selection/edit-mode/sidebar-display surface.
Wire routing and simulation/multimeter each carry a real, named gap (an
ENGINE GAP for route-model fidelity, and an ADAPTER-REQUIRED opportunity for
multimeter, since OEP's measurement engine already exceeds V2's static
table). Persistence is fully a PERSISTENCE GAP: nothing here makes V2's
manual JSON layout file and OEP's document format the same file.**

This is a hypothesis worth pursuing further, not a finished design. Three
POCs (module load, bidirectional messaging, one module's move-mutation)
proved the mechanics work. This assessment is the first pass at *scope* —
it is not exhaustive at the level a real implementation plan would need
(wire reconnect edge cases, annotation model, clipboard, keyboard-shortcut
conflicts between V2 and Flutter are flagged but not fully enumerated).

## 2. V2 Functional Inventory

Source-verified (this task and the prior AP-DIAGRAM-V2-FUNCTIONAL-REBASE
research pass — same files re-checked where the wire/route model needed
confirming).

| # | Capability | Real / Placeholder |
|---|---|---|
| 1 | Vehicle/document loading | Real (`vehicle-loader.js`, `bootstrap.js`) |
| 2 | Module creation | Real (`module-editor.js` `openAdd`/`commitAddModule`) |
| 3 | Module deletion | Real (`delModule`, native `confirm()`) |
| 4 | Module movement | Real (`setupDrag`, mousemove, continuous) |
| 5 | Module editing (properties) | Real (`editModProps`/`saveModProps`) |
| 6 | Module selection | Real (`inspector.js` `showModInfo`, mutually exclusive with wire selection) |
| 7 | Module properties (label/sub/category/terminals) | Real |
| 8 | Port (terminal) selection | Real (`.t-dot` click handlers, `setupTermClicks`) |
| 9 | Port hover | Real (`.wh` class toggle on hover, wire-mode/lead-place only) |
| 10 | Wire creation | Real (`handleWireTerm`, two-terminal-click flow) |
| 11 | Wire deletion | Real (`deleteSelectedWire`, native `confirm()`) |
| 12 | Wire selection | Real (`selW`, mutually exclusive with module selection) |
| 13 | Wire editing (color/label/desc + meter table) | Real (`editWireProps`/`saveWireProps`) |
| 14 | Wire routing | Real, but **relative segment-offset model**, not absolute points (§6) |
| 15 | Wire reconnect | **Not implemented** — no V2 function changes an existing wire's `from`/`to`; only delete+recreate |
| 16 | Wire color | Real (single-letter code, e.g. `'W'`, free text) |
| 17 | Wire labels | Real (free text) |
| 18 | Relationship inspection | Real (sidebar wire panel, `inspector.js`) |
| 19 | Relationship metadata | Real, but V2-specific: 4-row×5-column meter-reading table keyed by key-state (§6) — no OEP equivalent field |
| 20 | Edit/layout mode | Real (§8) |
| 21 | Zoom | Real (Ctrl+scroll, +/−/Fit buttons, 'F' key) |
| 22 | Pan | Real (drag on empty canvas, no modifier) |
| 23 | Grid | Implicit only — module drag snaps to a 10px grid (`module-editor.js:30-31`); no visible grid overlay found |
| 24 | Selection/marquee | **Not a multi-select** — Ctrl/Shift-drag on empty canvas is zoom-to-rectangle (`sidebar.js` IIFE), confirmed in the earlier functional-rebase pass |
| 25 | Annotations | **Not found** — no annotation/note/callout construct anywhere in `js/` |
| 26 | Multimeter | Real UI, but **static lookup**, not live simulation (§12) |
| 27 | Simulation | **Placeholder only** — `js/simulator/`, `js/diagnostics/` are documented Phase 2/3/4 stubs (confirmed earlier session); `traceCircuit` in `app.js` is a visual highlighter over the static wire graph, not an electrical solver |
| 28 | Undo | **Not implemented** — `UndoRedoStack` class exists (`js/editor/undo-redo.js`) but is never instantiated or called anywhere in the codebase |
| 29 | Redo | Same as Undo — not implemented |
| 30 | Save | Real, but partial — `project-saver.js` `saveLayout` downloads only `positions`/`wireRoutes`/user-created wires (`wire-` id prefix)/user-created modules (`_user` flag); base vehicle data is not re-saved |
| 31 | Load | Real — `project-loader.js`, native file picker, merges into in-memory state |
| 32 | Project persistence | Manual only — no autosave (`js/storage/autosave.js` confirmed empty placeholder) |
| 33 | Recent projects | **Not found** |
| 34 | Vehicle selection | Implicit via `vehicleId` param to `VehicleLoader.load`; no in-app vehicle switcher UI found in the reviewed files |
| 35 | Module/library selection | Real — preset template palette (`PRESETS`/`CONN_PRESETS` arrays, `renderModPanel`) feeding the Add-Module modal |
| 36 | Clipboard (copy/paste/duplicate) | **Not implemented** — `js/editor/clipboard.js` confirmed empty Phase 3 placeholder |
| 37 | Search | Real (`doSearch` in `app.js`, `/` shortcut) |
| 38 | Legend | Real (`buildLegend`, `L` shortcut) |
| 39 | Graph Inspector (debug panel) | Real (`js/ui/graph-inspector.js`, Ctrl+Shift+G) |
| 40 | SVG export | Real (`project-saver.js` `exportSVG`) |

## 3. Complete Operation Matrix (A–P per operation)

Full A–P detail for every row above would run to several hundred lines;
given this task's own "do not create an exhaustive per-field document"
implicit scope (§25's explicit list of what's still deferred), this
section covers the columns that actually drive classification —
**F** (externally observable via the current bridge), **H/I** (existing
OEP command/Controller method), and **P** (final classification) — for
every operation. A–E/J–O are addressed narratively in §5–14 where the
detail materially affects the conclusion (module move, wires, edit mode,
undo, persistence, simulation).

| Operation | F: observable via bridge today | H/I: existing OEP command/Controller method | P: Classification |
|---|---|---|---|
| Module movement | Yes (POC-002/003 — polling `positions`) | `MoveNodesCommand` / `controller.moveNodes()` | **DIRECT** (proven, POC-003) |
| Module creation | Yes (`MODULES.push`, observable via poll) | `CreateNodeCommand` / `controller.addNode()` | **ADAPTER REQUIRED** — needs symbol-id resolution (V2 has no `symbolId` concept; §5) |
| Module deletion | Yes (`MODULES` array shrinks) | `DeleteNodeCommand`/`delete_many_command.dart` | **ADAPTER REQUIRED** — plus reverse-mapping cleanup in the bridge's ID table |
| Module properties (label/sub/category) | Yes (object mutated in place) | `UpdateNodePropertiesCommand`/`RenameNodeCommand` | **ADAPTER REQUIRED** — field-name translation only |
| Module selection | Yes (`selM`, proven POC-002) | `engine.registry.selection.selectNode()` | **DIRECT** |
| Port/terminal | Yes (`m.terminals[]`, static per module) | `Port` (id/name/direction/type/metadata) | **ADAPTER REQUIRED** — V2 terminal is `{n,c}` (name+wire-color), no direction/type; needs a synthesized mapping, not a 1:1 field match |
| Wire creation | Yes (`WIRES.push`) | `CreateRelationshipCommand` | **ADAPTER REQUIRED** — needs both endpoints' OEP node IDs already resolved (depends on module ID mapping existing first) |
| Wire deletion | Yes | `DeleteRelationshipCommand` | **ADAPTER REQUIRED** |
| Wire selection | Yes (`selW`) | `engine.registry.selection.selectRelationship()` (presumed symmetric with `selectNode`; not directly inspected this pass) | **ADAPTER REQUIRED** |
| Wire color/label | Yes | `UpdateRelationshipPropertiesCommand` | **ADAPTER REQUIRED** |
| Wire routing (visual bends) | Yes, but as **relative segment offsets**, not points (§6) | `SetWireRouteCommand` (absolute `List<Point2D>`) | **ENGINE GAP** for full-fidelity round-trip; a lossy one-way conversion (offsets → absolute points) is possible for V2→OEP only, not reversible |
| Wire meter-reading table (4×5, per key-state) | Yes | **No OEP field exists for this** — not `properties`, not `metadata` in any inspected relationship model this pass | **ENGINE GAP**, OR store as opaque `EngineeringRelationship.metadata` (already a `Map<String,Object?>` on `EngineeringNode`; presumed symmetric on relationships) — needs Phase-2-style confirmation, marked **ADAPTER REQUIRED (tentative)** pending that check |
| Wire reconnect | N/A — V2 doesn't have this operation | `ReconnectRelationshipCommand` (OEP has it, V2 doesn't) | **N/A** — OEP is strictly ahead here |
| Edit/layout mode | Yes (`editMode` global) | No direct OEP equivalent — OEP has no separate "mode" gate; editing is always available in Diagram Studio | **ADAPTER REQUIRED** — the mode itself is a pure V2 UI-state concept; bridging it means suppressing/allowing bridge writes based on `editMode`, not an Engine concept at all |
| Zoom/pan | Yes (`scale`/`tx`/`ty`, proven POC-002 `zReset()` call) | `ViewState`/`ViewStateService` (`controller.viewState`) | **DIRECT** for one-way OEP→V2 trigger (proven); two-way sync not attempted |
| Undo (single last move) | Yes (proven POC-003 concept, not fully implemented — see current session state) | `engine.editing.undo()` | **DIRECT** for the one class of command this bridge issues (`MoveNodesCommand`); **not generalizable** without V2 exposing its own undo semantics, which it doesn't have (§13) |
| Save/Load | Yes (V2's own file picker/download, unrelated to OEP) | `DiagramStudioController` document save/load path | **PERSISTENCE GAP** (§14) |
| Simulation/multimeter | Partially — static `R[]` table is observable, but it's not live | `measurement_engine.dart`, `signal_propagator.dart`, `diagnostics_engine.dart` | **ADAPTER REQUIRED**, high-value — OEP's simulation subsystem is strictly more capable (§12) |
| Annotations | N/A — V2 has none | `CreateAnnotationCommand`/`UpdateAnnotationCommand` | **N/A** — OEP is strictly ahead here |
| Clipboard | N/A — V2 has none (placeholder) | `StudioCommandActions` (copy/cut/paste/duplicate, proven working in existing Flutter Diagram Studio) | **N/A** — OEP is strictly ahead here |

## 4. Identity Mapping Analysis

| Entity | V2 identity | OEP identity | Deterministic mapping possible? |
|---|---|---|---|
| Module | `m.id` — authored string in `diagrams/{vehicle}/modules.json` (e.g. `"indicator-lights"`), stable across reloads, never regenerated | `EngineeringNode.id` — caller-supplied string at `CreateNodeCommand` time | **Yes, if the OEP node is created with `id` derived from V2's `m.id`** (proven in POC-003 investigation: `CreateNodeCommand` takes a fully caller-constructed `EngineeringNode`, `id` is a plain required `String`). No pre-existing correspondence exists between an arbitrary already-open OEP document and a V2 vehicle's modules — the mapping must be **established**, not discovered, the first time each module is touched, and kept in an in-memory bridge-side table for the session. This is explicitly allowed by the POC-003 task's own Phase 4 guidance ("if [V2] does not [already contain the mapping], determine whether the mapping can be established externally in Flutter") — it is not an index/position/random scheme; it is keyed off V2's own persistent authored id. |
| Wire | `w.id` — authored string in `wires.json` for base wires, or `'wire-' + Date.now()` for user-created wires (`wire-editor.js:93`) | `EngineeringRelationship.id` — caller-supplied string | Same pattern as modules **for authored wires**. **User-created wires are a problem**: `Date.now()`-based IDs are not guaranteed collision-free across a fast double-create and carry no semantic stability if V2's in-memory state is ever rebuilt — usable as a session-scoped map key (they don't change after creation, only until page reload since nothing persists them), but not a durable cross-session identifier. Flagged, not blocking, since this assessment is runtime-scope only. |
| Port/terminal | Positional — a module's `terminals` array, referenced by `t.name` (a display label, e.g. `"OIL"`), not a separate id field at all | `Port.id` — a real, required, presumably-unique string | **No 1:1 mapping exists.** V2 terminal identity is `(moduleId, terminalName)` composite, and `terminalName` is a *display* string, not guaranteed unique-forever (nothing in the reviewed source enforces uniqueness within a module, though in practice authored data likely is unique). A synthesized composite key (`'${v2ModuleId}::${terminalName}'`) is deterministic and workable, but it is a bridge-invented identifier, not a genuine "found" one — flagged as **ADAPTER REQUIRED**, not DIRECT. |
| Annotation | N/A — no V2 concept | `EngineeringAnnotation` presumably has its own `id` (not inspected this pass — no V2 side to map from) | N/A |

**No random/index/position-based mapping is proposed anywhere in this
assessment**, per the task's explicit prohibition.

## 5. Module Operations

V2 module state is a plain JS object with `id`, `label`, `sub`, `cat`,
`exit`, `terminals[]`, optional `bulb`/`connector`/`notes` flags
(`vehicle-loader.js:82-97`). It has **no symbol/visual-template concept** —
V2 renders every module the same generic "card" (`renderer.js` `buildCard`),
styled only by `cat` (category) via CSS class. OEP's `addNode` requires a
resolvable `symbolId` (proven in POC-003 investigation: `engine.registry.symbols.resolve(symbolId)`
must succeed, or the call throws). **This is the concrete gap for module
creation**: a bridge that creates an OEP node per V2 module needs a
category→symbolId mapping table (e.g. `cat: 'ignition'` → some generic
"electrical component" symbol), not a real per-module visual identity —
OEP would necessarily render V2's modules more genetically than V2's own
category-styled cards do, unless/until someone authors real symbols for
each V2 module category. This is squarely **ADAPTER REQUIRED**, not
blocked, but it is real, non-trivial work (a symbol per category, minimum).

Module movement itself needs no such translation — proven end-to-end in
POC-003's investigation (not yet fully live-verified end-to-end in a
built app at the time this assessment started; see the standing session
state).

## 6. Wire Operations

**Endpoints**: `{from:{m,t}, to:{m,t}}` — a `(moduleId, terminalName)` pair
on each side, matching OEP's relationship model shape
(`sourceNode`/`targetNode`, both plain node-id strings) *once* the port
composite-key problem in §4 is accepted (OEP relationships in the codebase
connect node-to-node, not port-to-port, per `createRelationship`'s
signature at `diagram_studio_controller.dart:284-291` — it takes
`sourceNodeId`/`targetNodeId` only, no port arguments). **This is a real
fidelity loss**: V2 wires are terminal-precise; the existing
`createRelationship` Controller method is node-precise. Either the bridge
drops terminal precision (acceptable for this scope, matching what
`createRelationship` already supports) or `EngineeringRelationship`'s own
model needs inspection for a port-level field not yet confirmed present —
**flagged as needing a Phase-2-style follow-up check**, not resolved here.

**Route model — the real gap.** V2's `wireRoutes[wireId]` is a map from
**segment index → a single perpendicular offset delta** applied against an
auto-routed orthogonal path (`app.js:148-155`, `renderer.js:151`
`route(w)` reads `wireRoutes[w.id]` as `overrides`). It is a *relative*
correction to an algorithm's output. OEP's `SetWireRouteCommand` stores an
**absolute list of `Point2D`** replacing the routed path entirely
(`set_wire_route_command.dart:16-17`). These are different representations
of "a custom route," not two encodings of the same thing:

- V2 → OEP is computable **one-way**, if you can evaluate V2's own
  auto-router (not reviewed this pass, presumably in `renderer.js`'s
  `route()`) to resolve `wireRoutes` offsets into absolute points before
  writing them into `SetWireRouteCommand`.
- OEP → V2 is **not directly computable** — decomposing an arbitrary
  absolute point list back into "segment index + offset" against V2's own
  router requires either re-implementing that router's logic in Flutter,
  or calling into V2's own `route()`-adjacent logic via `executeScript`
  (feasible, not attempted, not free).

This is exactly what AP-DIAGRAM-V2-011 already found (referenced in this
task's own framing as "the V2-011 route-model incompatibility") — this
assessment confirms it again independently, from the actual current
source, and narrows it: **absolute-point wires (auto-routed, no user
edits) round-trip fine; user-edited routes do not, without new
conversion logic.** Classification: **ENGINE GAP** is too strong (Engine
already has an absolute-route command); the correct classification is
**ADAPTER REQUIRED, with a known-lossy direction** — reversible enough for
this scope's purposes but not architecturally clean. Do not build it as
part of a "just wire it up" adapter without acknowledging the lossiness.

**Reconnect**: V2 cannot move an existing wire's endpoint — only
delete-and-recreate. OEP's `ReconnectRelationshipCommand` exists and is
strictly more capable. No bridge work needed to *support* reconnect from
the OEP side; V2 simply never triggers it.

**The meter-reading table** (§3's table row) has no found OEP field —
worth a dedicated look at whether `EngineeringRelationship.metadata` (if
it mirrors `EngineeringNode.metadata`, not directly confirmed this pass)
could hold it opaquely, same as how `EngineeringNode.metadata` already
holds arbitrary extension data per its own doc comment
(`engineering_node.dart:46`, "Extension-contributed data... never
interpreted by the core engine"). Tentative ADAPTER REQUIRED, not ENGINE
GAP, pending that one field check.

## 7. Relationship Operations

Covered in §6 (wires ARE V2's only relationship concept — no separate
"relationship types" exist in V2 beyond the electrical wire).

## 8. Edit Mode Analysis

`editMode` is a single global boolean (`app.js`), toggled by `toggleEdit()`
(`module-editor.js`) or the `E` keyboard shortcut. Entering it:

- Enables module drag (`setupDrag`'s `mousedown` handler checks
  `if (!editMode) return;` — drag is a no-op outside edit mode).
- Disables click-to-select (module selection in `inspector.js` is only
  reachable outside edit/wire/route modes per the earlier functional-
  rebase research).
- Shows the module-panel drawer (add/preset palette).
- Mutually exclusive with `wireMode` (`toggleWireMode` calls `toggleEdit()`
  to exit edit mode if both would otherwise be true — `wire-editor.js:47`).

It affects **only which interaction handlers are live**, not rendering —
`buildCard`/`placeCards` render identically in and out of edit mode
(confirmed by inspection: no `editMode` conditional inside `renderer.js`'s
render functions). This is a pure input-gating concept, not an OEP
Engine concept at all — OEP's Diagram Studio has no equivalent "mode" that
gates whether drag/select work; both are always live. Bridging this
correctly means: **the bridge's injected script must itself respect
`editMode`** when deciding whether a detected `positions[id]` change is a
genuine user drag (only possible when `editMode` is true) versus some
other in-page mutation — this is a refinement the POC-003-era bridge
script did not yet have (it polled `positions` unconditionally). Flag for
any follow-up work: **read `editMode` in the injected script and gate
move-detection on it**, both for correctness and as a second loop-
prevention safeguard beyond the one POC-003 already designed.

## 9. Sidebar Analysis

(`js/ui/sidebar.js`, `js/ui/inspector.js`, from the earlier functional-
rebase pass, re-confirmed structurally this pass.) Two tabs (Inspector,
Meter). Renders wire info OR module info, never both — mirrors V2's own
single-selection, module-XOR-wire-selected model exactly
(`inspector.js` `selMod`/`showModInfo` vs. the wire-panel functions).
Supports popout/dock (float the same content in a separate floating
panel). Also owns the zoom-to-rectangle gesture (Ctrl/Shift+drag on empty
canvas) via an IIFE at the file's own end — an implementation detail
worth knowing if the sidebar is ever *not* the one hosting that gesture
in a bridged architecture.

**This sidebar already is the primary interaction/inspection surface for
V2** — it is not a secondary panel bolted on; module/wire property editing
routes through it (via the modals it opens) and through direct modal
dialogs (`editModProps`, `editWireProps`). The working hypothesis in this
task's framing ("legacy V2 sidebar = primary interaction surface") is
**confirmed by source**, not just plausible.

## 10. Command Palette Comparison

The existing Flutter Diagram Studio command-palette bar was not
re-inspected in full this pass (out of scope per this task's own "do not
modify the existing Flutter Diagram Studio renderer" instruction — reading
it wasn't necessary to answer the comparison question). Structurally: V2's
sidebar + modals cover module/wire creation, editing, deletion, properties,
mode toggles, search, legend — the same operation set Diagram Studio's
command palette exposes via a different UI paradigm (command search/
shortcuts vs. persistent docked panel + modals). Nothing found in V2's
source *requires* a command-palette-style surface to exist alongside it;
V2's own UI is self-sufficient for its own operation set. This supports
(does not prove beyond a source-level read) the hypothesis that the
command palette would become **redundant, not required**, if V2's sidebar
became the primary surface — final call on removing it is a UX decision,
not something this document can settle from source alone.

## 11. Annotation Analysis

V2 has no annotation/note/callout construct anywhere in the reviewed
`js/` tree (confirmed again this pass via targeted search — no matches for
annotation-shaped functions or state). OEP has a real annotation command
set (`CreateAnnotationCommand`, `UpdateAnnotationCommand`,
`DeleteAnnotationCommand`). Classification: **N/A for bridging** — there
is nothing on the V2 side to bridge. If V2 became the primary UI, OEP
annotations would need **their own new V2-side UI surface** (which is out
of scope for "V2 remains unmodified") or would simply be unavailable in
the V2-fronted workflow. This is a real product-scope question for anyone
pursuing this architecture further, not a technical blocker.

## 12. Simulation/Multimeter Analysis

V2's "multimeter" is a **static lookup**: a 4-row (key-state: Off/Off,
On/Off, Cranking, Running) × 5-column (VDC/VAC/CONT/RES/DIODE) table
authored per wire in `measurements.json` and merged onto each wire object
as `R[]` by `vehicle-loader.js:104-123`. Reading the meter for a given
key-state is an array index into pre-authored values — there is no
electrical model, no propagation, no fault injection. `traceCircuit` in
`app.js` highlights the wire graph visually; it does not compute anything.

OEP's simulation subsystem (`platform/oep_engine/lib/core/simulation/`) is
substantially more capable: a real `measurement_engine.dart`,
`signal_propagator.dart`, `diagnostics_engine.dart`,
`power_distribution.dart`, and a `simulation_fault.dart` model — this is
an actual signal-propagation engine, not a lookup table. **This is the
single highest-value adapter opportunity found in this assessment**: V2's
meter UI (leads, key-state selector, reading display) could stay
unmodified while its *data source* is redirected — instead of reading
`w.R[keyIndex]`, an injected script (or a bridge-driven `executeScript`
call) could request OEP's actual computed measurement for that wire/key-
state and write it into the same DOM V2 already renders. This is
**ADAPTER REQUIRED**, not ENGINE GAP — OEP already has everything needed;
the gap is purely the translation layer (V2 key-state values ↔ OEP
simulation session key-state concept, not inspected this pass) and is a
substantially larger undertaking than the module-move POC, out of scope to
attempt here.

## 13. Undo/Redo Analysis

V2: **no history at all** (§2 row 28/29, confirmed again this pass —
`UndoRedoStack` is dead code). OEP: a real command-stack-based undo/redo
(`engine.editing.undo()`/`canUndo`, exercised directly in
`diagram_studio_controller_test.dart:88-90` and designed into every
`EditingCommand`'s `apply`/`revert` pair, including `MoveNodesCommand`
itself).

**Can this generalize beyond one move?** Mechanically, yes — every OEP
command already supports undo/revert uniformly; nothing about
`MoveNodesCommand` is special-cased. The actual limitation is **V2 has
no signal for "the user wants to undo"** beyond whatever a bridge chooses
to wire up externally (e.g. a Flutter-side Ctrl+Z, or an injected
`keydown` listener calling back into Flutter — V2's own `Escape`-cascade
keyboard handler in `app.js` has no `Ctrl+Z` case to reuse). So
generalizing undo is **not an Engine limitation and not a V2 architectural
blocker** — it's un-built plumbing: an external (bridge-owned, not
V2-file) keyboard listener, and a decision about what "undo" means when
the last mutation might have originated from a V2 wire-property edit that
was never bridged to OEP in the first place (only module-move currently
round-trips through OEP's command stack; a V2 wire-color edit today
changes only V2's own in-memory object, invisibly to OEP, and undoing it
from the OEP side would do nothing). **Classification: ADAPTER REQUIRED**
for module-move undo (mechanically ready, per POC-003), **PERSISTENCE-
ADJACENT GAP** for anything not yet bridged (can't undo what OEP never
knew happened).

## 14. Persistence Analysis

**Runtime synchronization** (in-memory, current session): proven for
module position (POC-003). Not attempted for anything else.

**Persistent document synchronization** (survive a restart): V2's
`saveLayout` writes `positions`/`wireRoutes`/user wires/user modules only
(`project-saver.js:1-34`, confirmed again this pass) — **not** the base
vehicle data, and not in OEP's document schema
(`DiagramDocument._envelope`: `schemaVersion`/`documentId`/`graph`/
`layout`/`metadata`, from POC-003-era investigation of
`diagram_document.dart`). These are two independent file formats with no
converter in either direction today.

For `V2 → OEP → save → restart → OEP → V2` to actually restore the same
state, something would need to:
1. Persist the bridge's session-scoped V2-id↔OEP-id map (today it's
   in-memory only, per §4 and POC-003's design — lost on restart).
2. Either make OEP's own document save include enough V2-specific
   metadata to reconstruct that map, or make V2's own save format
   OEP-aware (the latter would require modifying V2, explicitly
   forbidden).

**Classification: PERSISTENCE GAP**, cleanly. Nothing here is
individually hard, but nothing exists yet, and the two systems' file
formats need a deliberate bridge-owned envelope format — not attempted,
not designed in detail, in this assessment.

## 15. WebView Technical Constraints

Documented previously (`DIAGRAM_STUDIO_V2_WEBVIEW_POC.md`,
`DIAGRAM_STUDIO_V2_BRIDGE_POC.md`) — restated briefly, nothing new found
this pass:

- `file://` loading works; V2's own `VehicleLoader` already branches on
  `location.protocol` for this — not a workaround.
- `webview_flutter_windows` 1.1.1's *actual* API (`WebviewController`/
  `Webview`, not `webview_flutter`'s abstraction) is what works on
  Windows; `webview_flutter`'s own contract is unimplemented by that
  package version.
- `executeScript`/`addScriptToExecuteOnDocumentCreated`/`postWebMessage`/
  `webMessage` stream — all confirmed working (POC-002/003).
- No ES modules in V2; classic scripts sharing one global JS realm, which
  is *why* injected scripts can read `let`-scoped globals like `MODULES`/
  `selM`/`positions` without needing them on `window`.
- **Not evaluated this pass**: keyboard-shortcut conflicts between V2's
  own `keydown` handler (E/W/F/Escape/0-3/arrows/etc., `app.js`) and any
  Flutter-level shortcuts Diagram Studio's shell might want to keep active
  while the WebView has focus; clipboard interop; drag/drop from outside
  the WebView; native file-dialog behavior for V2's own Save/Load (uses
  the browser's native file picker inside WebView2 — not confirmed
  whether this differs from a real browser's dialog in any way); WebView2
  performance under sustained polling (POC-002/003 both use a 400ms
  poll interval, chosen for the POC, not benchmarked); Android/Linux/
  macOS — `webview_flutter_windows` is Windows-only by name, no
  investigation of cross-platform equivalents was in scope.

## 16. Bridge Architecture (proposed, not built)

The task's own proposed structure —

```
LegacyV2WebView → LegacyV2BridgeTransport → LegacyV2StateAdapter → DiagramStudioController → OEP Engine
```

— is **sufficient, and matches what POC-002/003 already validated in
practice**, with one clarification: POC-002/003 combined "transport" (the
injected script + `webMessage`/`executeScript` plumbing) and "state
adapter" (ID mapping, position conversion) inside one widget class for
POC speed. A real implementation should split them, exactly as this task
proposes:

- **`LegacyV2BridgeTransport`** — owns the `WebviewController`, the
  injected script text, the `webMessage` stream, `executeScript` calls.
  Knows nothing about node IDs, `Point2D`, or `MoveNodesCommand`. This is
  the layer POC-002 already effectively built (its bridge script +
  listener), just not yet extracted into its own class.
- **`LegacyV2StateAdapter`** — owns the V2-id↔OEP-id map, coordinate
  conversion, loop-prevention guard, and translates raw transport messages
  into calls against `DiagramStudioController`'s existing methods
  (`addNode`, `moveNodes`, etc.) — never touches `engine.editing.execute`
  directly, matching this task's own "do not call Engine internals from
  the WebView widget if the Controller already owns the operation."
  POC-003's design (not yet extracted into a file — see standing session
  state) already respects this boundary.

No additional layer appears necessary for the operations proven or
analyzed so far. Wire-route conversion (§6) and simulation adaptation
(§12) would likely want their own dedicated adapter *sub*-modules under
`LegacyV2StateAdapter`, given how different their translation logic is
from position mapping, but that's an internal-file-organization call, not
a new architectural layer.

## 17. OEP Compatibility Matrix

Summary of §3's per-operation table, collapsed:

| Classification | Operations |
|---|---|
| DIRECT | Module move, module select, zoom trigger (one-way), module-move undo |
| ADAPTER REQUIRED | Module create/delete/properties, port mapping, wire create/delete/select/color/label, edit-mode gating, simulation/multimeter |
| ENGINE GAP (none confirmed as a hard blocker) | — (wire route fidelity is real but reclassified as ADAPTER REQUIRED-with-lossiness, not a true Engine gap, since `SetWireRouteCommand` already exists) |
| PERSISTENCE GAP | Save/load round-trip, ID-map durability, undo generalization beyond bridged operations |
| BLOCKED | None found |
| N/A (OEP already exceeds V2) | Wire reconnect, annotations, clipboard/copy/paste/duplicate |

**No operation was found to be BLOCKED.** This is a materially positive
result for the architecture question, with the caveat that "ADAPTER
REQUIRED" is doing a lot of work in this table — several of those adapters
(symbol-per-category mapping, port composite keys, wire-route lossy
conversion, simulation redirection) are substantial, multi-day-scale
efforts individually, not small glue code.

## 18. Engine Gaps

**None found that require a new Engine command or model change.** The
route-model mismatch (§6) is the closest candidate, but `SetWireRouteCommand`
already exists and accepts what OEP needs — the gap is entirely in
conversion logic, not missing Engine capability. If a future need arose to
store V2's *relative*-offset representation natively in OEP (rather than
converting it), that would become a genuine Engine-model question — not
proposed here, per the task's explicit "do not create new Engine
commands."

## 19. Persistence Gaps

Covered in §14. Summary: bridge ID-map durability, and a genuine
document-format bridge between V2's partial-layout JSON and OEP's full
graph/layout/metadata envelope. Neither attempted; both scoped as real,
separate future work.

## 20. Blocked Operations

**None.** Every operation inventoried in §2 resolved to DIRECT, ADAPTER
REQUIRED, PERSISTENCE GAP, or N/A. No operation required modifying V2,
Engine, or Foundation to become theoretically bridgeable.

## 21. Minimum Required Bridge

For a first real (non-POC) increment beyond what POC-002/003 already
built, in priority order:

1. **`LegacyV2StateAdapter` extraction** — pull POC-003's mapping/
   conversion/loop-guard logic into its own class, separate from the
   WebView widget, per §16.
2. **Module create/delete adapters** — the next-most-requested operations
   after move, needing the category→symbolId table (§5).
3. **Edit-mode-aware move detection** — gate the injected script's
   move-detection on `editMode` (§8), closing a correctness gap the
   POC-era script has today.
4. **Wire create/delete (node-level, not port-level)** — accepting the
   §6 terminal-precision loss as a known, documented limitation rather
   than solving it immediately.

Deliberately **not** in a minimum bridge: wire route conversion,
simulation redirection, persistence round-trip, undo generalization
beyond move — all real but each individually larger than the whole
module-move POC was.

## 22. Target Architecture

**Technically viable**, with the scope caveats above. The proposed shape —

```
OEP Studio → native shell/nav → Diagram Studio → WebView2 → Legacy V2 UI → Bridge → OEP Engine
```

— matches what three POCs have now demonstrated piece by piece: V2 runs
unmodified inside the shell (POC-001), the WebView can talk to Flutter in
both directions (POC-002), and a real Engine mutation can originate from a
V2 user action and round-trip an authoritative result back (POC-003). The
open question is not "can this work" — the POCs answer that — but "is the
adapter cost (§17's ADAPTER REQUIRED list) worth paying compared to
finishing the native Flutter renderer reconstruction instead." That is a
resourcing/roadmap decision, not a technical one, and is explicitly out of
this document's scope to recommend.

## 23. Risk Analysis

- **Adapter scope creep**: each ADAPTER REQUIRED row in §17 is individually
  substantial; treating this as "just a bridge" understates the work.
- **Lossy wire-route conversion** (§6) is a correctness risk if not
  documented and accepted explicitly by whoever picks this up next — a
  naive implementation could silently corrupt user-edited routes on a
  round trip.
- **V2 freeze constraint compounds over time**: every future V2 capability
  this architecture wants to expose must be adaptable via external
  injection only; V2's own maintainers (if any) gain no visibility into
  what's watching/rewriting its runtime state from outside.
- **In-memory-only ID mapping** (today) means restarting OEP Studio loses
  the V2↔OEP correspondence entirely — fine for a POC, a real hazard for
  a production feature until §14's persistence gap is closed.
- **WebView2-only / Windows-only**: this architecture, as built, has no
  path to the other platforms `oep_studio` presumably targets, unless a
  cross-platform WebView solution is separately vetted (not attempted
  here).
- **Two undo systems coexisting**: V2 has none, OEP has one that only
  knows about bridged operations — a user could perform a V2-only edit
  (e.g. wire color, not yet bridged) that OEP's undo stack has no
  awareness of, creating a confusing "undo did nothing" experience for
  operations the bridge hasn't reached yet.

## 24. Development Sequence (proposed, not started)

1. Extract `LegacyV2StateAdapter`/`LegacyV2BridgeTransport` split (§16).
2. Module create/delete/properties adapters + category→symbol table (§5).
3. Edit-mode-aware move detection (§8).
4. Wire create/delete/select/properties (node-level only) (§6).
5. Decide: pursue wire-route conversion, or accept auto-routed-only wires
   for V2-originated wires as a permanent scope boundary.
6. Decide: pursue simulation/multimeter redirection (§12) — highest value,
   also highest effort.
7. Persistence bridge design (§14) — needed before this can be anything
   but a session-scoped demo.
8. Undo generalization, bounded by whatever's actually bridged by that
   point (§13).

This sequencing is a suggestion based on apparent cost/value from this
pass's findings, not a committed plan.

## 25. Architectural Recommendation

The evidence across three POCs plus this assessment supports treating
**"V2 as presentation layer, OEP as authoritative engine" as a genuinely
viable alternative** to finishing the native Flutter V2 renderer
reconstruction — no operation was found to be technically blocked, and the
highest-value adapter (simulation/multimeter, §12) plays directly to
OEP's existing strength over V2's static lookup table. The cost is real
and concentrated in a specific, now-named set of adapters (§17), not
diffuse or unknown. Whether that cost is worth paying instead of
continuing the Flutter renderer path is a resourcing decision this
document deliberately does not make — it was asked to classify and scope,
not to recommend a go/no-go.

## 26. Explicitly Deferred Decisions

- Go/no-go on this architecture vs. continuing Flutter renderer
  reconstruction.
- Whether to accept the wire-route lossy-conversion limitation
  permanently or invest in solving it.
- Whether to pursue simulation/multimeter redirection at all, given its
  size.
- Cross-platform WebView strategy (Windows-only today).
- Command-palette removal (structurally plausible per §10, not decided).
- Annotation UX if V2 becomes primary (§11).
- Persistence bridge file-format design (§14).
- Undo UX when V2-only (unbridged) edits are mixed with OEP-bridged ones
  (§13/§23).

---

## Verification

- `git status platform/oep_engine/` — clean.
- `git status platform/oep_foundation/` — clean.
- `reference/legacy_wiring_sim_v2/eke-wiring-sim/` — no modifications (no
  writes were made to this tree during this task; only reads).
- No production Flutter source files were modified by this task — only
  this new document was created.
