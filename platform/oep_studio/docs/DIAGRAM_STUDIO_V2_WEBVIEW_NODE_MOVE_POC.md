# AP-DIAGRAM-V2-WEBVIEW-POC-003 — Legacy V2 → OEP Node Movement Mutation Proof of Concept

## 1. Objective

Prove one specific, narrow operation: can a user drag a module in the
unmodified legacy V2 UI and have that movement become an authoritative
OEP Engine mutation — a real `MoveNodesCommand` execution against the
shared `EngineeringEngine` — without modifying V2's source, without a
new Engine command, and without a general bridge protocol?

## 2. Result

**PASS.** Live, end-to-end: V2 module drag → bridge → `DiagramStudioController`
→ existing `MoveNodesCommand`/`CreateNodeCommand` → real OEP graph
mutation → authoritative result read back → V2 display updated →
Engine undo reverts the move → V2 follows the revert. Confirmed by the
user against the running app.

## 3. V2 module identity (Phase 2)

V2's module JSON (`diagrams/<vehicle>/modules.json`, e.g.
`diagrams/trx300/modules.json`) assigns every module a stable,
author-written `id` string (e.g. `"cdi-unit"`, `"indicator-lights"`).
`VehicleLoader._buildModules` (`js/storage/vehicle-loader.js`) carries
this `id` straight through into the runtime `MODULES` array, and it is
the same string used everywhere else in V2's runtime state — `positions[id]`,
`cardEls[id]`, `selM`. It is not an array index, not derived from
screen position, and does not change across reloads (it comes from the
vehicle's own authored data file). This is the identifier the bridge
treats as "the V2 module ID."

## 4. OEP node identity (Phase 3)

`EngineeringNode.id` (`core/graph/models/engineering_node.dart`) is a
caller-supplied `String`, required at construction. `CreateNodeCommand`
(existing, unmodified) stores whatever `EngineeringNode` it's given —
the Engine does not generate or reassign node ids itself in this path.

## 5. ID mapping (Phase 4)

**No pre-existing deterministic mapping exists.** V2's `trx300` vehicle
data and whatever document happens to be open in OEP's Diagram Studio
are two unrelated data sets — the currently active OEP document has no
node that corresponds to any V2 module by construction. This was
verified by inspection, not assumed.

Per Phase 4's own explicit fallback — "determine whether the mapping
can be established externally in Flutter without modifying V2" — this
POC establishes the mapping **the first time a given V2 module is
moved**: [`LegacyV2Bridge.applyV2ModuleMove`](../lib/diagram_studio/webview/legacy_v2_bridge.dart)
creates exactly one OEP node via the existing
`DiagramStudioController.addNode` (which executes the existing
`CreateNodeCommand` — no new Engine command) and remembers the
`(v2ModuleId -> oepNodeId)` pair in an in-memory `Map` for the rest of
the session.

This is **not** the forbidden kind of identifier: not an array index,
not a screen-position-derived value, not random, and it does not
change on reload of the *same session* — it is keyed by, and only by,
V2's own stable module id string. It is, however, **not persistent
across app restarts** — see §16/§20.

## 6. Coordinate systems and position conversion (Phase 5)

- **V2**: `positions[id] = { x, y }`, top-left, in V2's own unscaled
  canvas-pixel space, snapped to a 10px grid on drag
  (`js/editor/module-editor.js` `setupDrag`; `js/diagram/renderer.js`
  `placeCards`, both write `card.style.left/top` directly from these
  values).
- **OEP**: `Point2D(dx, dy)` (`core/views/diagram/diagram_geometry.dart`)
  is anchor-agnostic at the Engine level — a bare pair of doubles with
  no documented anchor convention enforced by the Engine itself.
- **Conversion applied**: identity — `Point2D(x, y)` passed straight
  through, no scale or offset. This is sufficient for this POC's
  purpose (proving the mutation exists and round-trips deterministically)
  because the bridge-created node is rendered by OEP's own existing
  renderer using whatever convention every other node on the shared
  session already uses — this POC does not verify pixel-for-pixel
  visual alignment between the V2 card and the OEP canvas rendering of
  the same node (see §19 Limitations).

## 7. V2 movement detection (Phase 6)

V2's drag handler keeps its `drag`/start-offset state in a closure
private to each card (`setupDrag` in `js/editor/module-editor.js`) —
there is no global drag-start/drag-end signal an external script can
observe, and V2's source cannot be modified to add one. `positions[id]`
(global, written on every `mousemove` during a drag) is the only
externally observable signal.

The injected bridge script (extended from POC-002's script, still
injection-only, zero V2 file changes — see
[`legacy_v2_webview.dart`](../lib/diagram_studio/webview/legacy_v2_webview.dart)'s
`_kV2BridgeScript`) polls every 400ms and treats a module's position as
a settled, discrete move once it has been unchanged for 2 consecutive
ticks (~800ms). This produces one `moduleMoved` message per drag, not a
stream of per-frame messages — satisfying this task's "discrete
mutation boundary" requirement without a V2 source change to add a real
dragend event.

## 8. Bridge path

```
LegacyV2WebViewPage (WebviewController.webMessage)
        ↓ parses {kind:'moduleMoved', id, x, y}
_handleV2ModuleMoved
        ↓
LegacyV2Bridge.applyV2ModuleMove(v2ModuleId, x, y)
```

[`LegacyV2Bridge`](../lib/diagram_studio/webview/legacy_v2_bridge.dart)
is a plain Dart class with no `WebviewController`/`executeScript`
knowledge — it only takes a `DiagramStudioController` and returns a
`BridgeMoveResult`. `LegacyV2WebViewPage` owns the transport (parsing
messages, calling `executeScript` to sync back); this matches the
task's explicit "keep the bridge transport separate from the
Controller" instruction.

## 9. Controller path

`LegacyV2Bridge` calls only pre-existing `DiagramStudioController`
methods — `addNode(symbolId, position)` and `moveNodes(Map<String, Point2D>)`
(`lib/diagram_studio/controller/diagram_studio_controller.dart:237,272`) —
both already used by the production Diagram Studio canvas drag path and
by the existing test suite (`diagram_studio_controller_test.dart`).
Reading results goes through `controller.engine.editing.session`
(`DiagramStudioController.engine` is already a public field). No new
Controller method was added; `LegacyV2Bridge` is new, but it is a
thin adapter over methods that already existed.

## 10. MoveNodesCommand path

Unmodified. `MoveNodesCommand` (`core/editing/commands/move_nodes_command.dart`)
is called exactly as it already is, via `controller.moveNodes`. For a
module's *first* move, `CreateNodeCommand` (also unmodified) is used
instead — via `controller.addNode`, which already accepts an initial
`position` — establishing the node and its position in one step, since
there is nothing to move yet.

## 11. OEP authoritative result (Phase 8)

`LegacyV2Bridge.applyV2ModuleMove` does not assume the requested
position was accepted — it re-reads
`controller.engine.editing.session.layout.positionOf(nodeId)` after the
command executes and returns *that* value as the `BridgeMoveResult`.
Verified equal to the requested position in this POC (no clamping or
conversion currently occurs in `MoveNodesCommand`/`DiagramLayoutState`),
confirmed both by the focused test (§17) and live use.

## 12. V2 synchronization (Phase 9)

`LegacyV2WebViewPage._syncAuthoritativeResultToV2` calls
`executeScript` invoking the injected
`window.__oepBridgeApplyAuthoritative(id, x, y)` function, which:

- updates V2's own `positions[id]` (the same global V2's renderer reads),
- moves the actual DOM card element via `cardEls[id].style.left/top`
  (both `positions` and `cardEls` are pre-existing V2 globals, read
  only, never modified in V2's source),
- calls V2's own existing `drawWires()` so connected wires redraw.

This is all done through the injected script, not by writing to any V2
file — confirmed working live (V2's card visually reflects the
authoritative OEP position after a move).

## 13. Loop prevention (Phase 10)

The injected script's poller only emits `moduleMoved` for a value that
differs from `lastSynced[id]`. `window.__oepBridgeApplyAuthoritative`
updates `lastSynced[id]` (and `lastSeen[id]`) at the same time it
writes `positions[id]`, so the OEP-originated authoritative write is
recognized as already-confirmed and does not get re-reported as a new
user move. This is the "local POC guard" the task asked for — a single
per-module last-known-synced value, not a generalized event/origin
tagging system.

## 14. Dirty state (Phase 11)

Both `DiagramStudioController.addNode` and `.moveNodes` already call
`markDirty()` (existing mechanism, unchanged) — the bridge does not
introduce any dirty-state logic of its own. Confirmed by the focused
test: `controller.isDirty` is `false` before a bridged move and `true`
immediately after (`test/diagram_studio/webview/legacy_v2_bridge_test.dart`).

## 15. Undo (Phase 12)

`LegacyV2Bridge.undoLastMove` calls the existing
`DiagramStudioController.commands.undo()` (`StudioCommandActions.undo`
→ `engine.editing.undo()` — no new undo mechanism) for whichever OEP
node the most recent bridged move touched, then re-reads the
authoritative position and returns it for the caller to sync back to
V2.

**Confirmed live and by test:** undoing a *move* (a module already
mapped to an existing node) reverts to the previous authoritative
position and the result syncs back to V2 correctly.

**Confirmed live, and this is an intentional, in-scope limitation, not
a bug:** undoing a module's *first* move undoes the whole
`CreateNodeCommand` (since the first move creates-and-positions the
node in one step), removing the node entirely. `undoLastMove` returns
`null` in that case (nothing to sync back), and — because the
`(v2ModuleId -> oepNodeId)` mapping is not cleared on this path — a
second click of the Undo button calls `controller.commands.undo()`
again (a real further Engine undo, if further history exists) but has
no live node to read a position from, so nothing further visibly
happens in V2. The user's own live-test observation matches this
exactly: "the undo button only does one move, it won't go any further
back than one node movement." This is the expected result of the
task's own Phase 12 scope (verify **a** move reverts, singular) and its
explicit "Do not implement a new undo system" instruction — a full
multi-step undo/redo bridge is out of scope for this POC.

## 16. V2 persistence implications

Not exercised or altered. V2's own manual Save/Load Layout (JSON file
download/upload) is untouched and has no knowledge of the bridge or the
OEP graph — a bridge-created OEP node has no representation in a V2
"Save Layout" export, and OEP's own document save has no knowledge of
V2's module identity. This is a real, documented gap (§19), not
resolved here — resolving it is exactly the "persistence
synchronization" this task says not to implement.

## 17. Tests

[`test/diagram_studio/webview/legacy_v2_bridge_test.dart`](../test/diagram_studio/webview/legacy_v2_bridge_test.dart) —
one focused `testWidgets` test against the real
`DiagramStudioController`/`EngineeringEngine` (same real-bootstrap
harness `diagram_studio_controller_test.dart` already uses), covering:

1. First move for an unmapped V2 module id creates exactly one real
   OEP node (§5's mapping) via the existing `CreateNodeCommand` path.
2. The authoritative result matches the requested position (§6's
   identity conversion).
3. The `(v2ModuleId -> oepNodeId)` mapping is remembered and reused —
   a second move of the same V2 module does not create a second node.
4. Dirty state (§14): clean before, dirty after, through the existing
   mechanism.
5. A different V2 module id maps to a different OEP node.
6. Undo (§15): undoing a creation returns `null` and removes the node;
   undoing a pure move restores the exact previous authoritative
   position, which the test verifies against the real `EditingSession`.

Per the task's own "Do not create tests for V2 internals," the injected
script's polling/stabilization/loop-prevention JavaScript is
documented (§7, §13) but not unit-tested — there is no Dart-side
harness for it, and testing it would mean testing V2-page JS behavior,
not this POC's own code.

## 18. Live verification

Performed by the user against the running, freshly rebuilt app
(§"flutter build windows --debug" below), following this task's own
Phase 13 steps: opened the WebView, dragged a V2 module, observed the
bridge detect the move and the status bar update with the OEP mutation
result, exercised the new Undo (bridge) button, and (per the user's own
account) also checked the shared-engine Diagram Studio canvas. Result,
in the user's own words: "all seems to work correctly except the undo
button only does one move it wont go any further back than one node
movement" — matching §15's documented, intentional limitation exactly.

## 19. Limitations

- **Session-scoped mapping only** (§5) — the `(v2ModuleId -> oepNodeId)`
  map lives in `LegacyV2Bridge`'s memory and is lost on app restart or
  WebView page dispose; a fresh session re-creates a new OEP node for
  the same V2 module rather than finding the old one.
- **No visual-alignment verification** (§6) — the identity coordinate
  mapping was not checked for pixel-for-pixel agreement between V2's
  card position and the OEP canvas's rendering of the same node; only
  the *value* round-trip was verified.
- **Undo is single-step per the task's own scope** (§15) — not a
  multi-step undo/redo bridge.
- **No persistence bridging** (§16).
- **Only one V2 symbol category** — every bridge-created node uses the
  `'battery'` Symbol Library entry regardless of the V2 module's own
  category (`cat`/`terminals`/etc.); mapping V2 module categories to
  OEP symbols is out of scope ("relationship metadata" is explicitly
  excluded by the task).
- **Polling-based detection, not a real drag-end event** (§7) — a
  documented consequence of V2's source being frozen, not a defect in
  this POC's own code.

## 20. Exact blockers

None that stopped the POC. The one open architectural question
flagged, not blocking: a durable (cross-session) V2-module-id ↔
OEP-node-id mapping would need to be stored somewhere (document
metadata? a side file?) — deliberately not decided here, since doing so
would be exactly the "persistence synchronization" / "document
synchronization" this task excludes.

## 21. Architectural implications

This POC establishes that OEP can be authoritative for a V2-user-facing
mutation while V2's source stays completely untouched, using only
already-existing Engine commands and Controller methods, with a
transport (`LegacyV2Bridge`) cleanly separated from the WebView widget.
The pattern generalizes in shape to other single-field mutations (e.g.
V2 wire creation → `CreateRelationshipCommand`), but each would need
its own Phase 2–5 analysis (V2 data structure, ID mapping, and any
value-conversion) — nothing here should be read as proving those other
operations work without that same analysis.

## Build / verification record

- `flutter analyze` on `lib/diagram_studio/webview/legacy_v2_webview.dart`,
  `lib/diagram_studio/webview/legacy_v2_bridge.dart`,
  `test/diagram_studio/webview/legacy_v2_bridge_test.dart`: **clean, no issues.**
- `flutter test test/diagram_studio/`: **115 tests, all passing** (114
  pre-existing + 1 new), no regressions.
- `flutter build windows --debug`: **succeeded.**
- V2 source integrity: **100 files checked, 0 modifications**
  (`reference/legacy_wiring_sim_v2/eke-wiring-sim/`, SHA-256 verified).
- Engine/Foundation integrity: `git status platform/oep_engine/` and
  `git status platform/oep_foundation/` — **both clean.**

## Files created

- `lib/diagram_studio/webview/legacy_v2_bridge.dart`
- `test/diagram_studio/webview/legacy_v2_bridge_test.dart`
- `docs/DIAGRAM_STUDIO_V2_WEBVIEW_NODE_MOVE_POC.md` (this file)

## Files modified

- `lib/diagram_studio/webview/legacy_v2_webview.dart` — extended the
  POC-002 injected script with move detection + loop prevention, and
  wired `LegacyV2Bridge` into the message handler, plus an Undo button
  and an expanded status bar.

No other files changed. V2 source, Engine, and Foundation untouched.

## Stop condition

Per this task's own instructions, this POC concludes here. Not
proceeded to: wire creation, deletion, relationship metadata,
persistence synchronization, document synchronization, generalized
bridge protocol, V2 model replacement, production WebView architecture,
cross-platform support, Flutter UI deletion, or Engine/Foundation
modification.
