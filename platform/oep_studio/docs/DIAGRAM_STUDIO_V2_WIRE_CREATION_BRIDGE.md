# AP-DIAGRAM-V2-WEBVIEW-003 — Legacy V2 Wire Creation Bridge

> Builds on
> [`DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md`](DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md)
> (unchanged three-layer shape),
> [`DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md`](DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md)
> (§6's wire-route/port findings, confirmed here from fresh source),
> [`DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md`](DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md)
> (module identity/category mapping this task depends on), and
> [`DIAGRAM_STUDIO_V2_WEBVIEW_POC.md`](DIAGRAM_STUDIO_V2_WEBVIEW_POC.md).
> Does not rewrite any of them.

## 1. V2 Wire Creation Workflow

Traced directly from `js/editor/wire-editor.js` and
`js/diagram/renderer.js` (`setupTermClicks`):

1. `toggleWireMode()` enters wire-create mode (`W` key or the "⚡ Wire"
   button) — mutually exclusive with edit mode (entering wire mode exits
   edit mode, and vice versa, `wire-editor.js:45-57`).
2. Clicking a terminal dot (`.t-dot`, wired up per-card by
   `setupTermClicks`, `wire-editor.js:15-41`) while `wireMode` is true
   calls `handleWireTerm(mid, tn, dot)`.
3. **First click** (`wireSrc` unset): arms the source terminal
   (`wireSrc = {m, t}`), highlights it, updates the status text to
   `"FROM: <module> · <terminal> → click destination"`.
4. **Second click** (`wireSrc` set): two outcomes —
   - **Same terminal clicked again**: cancels (`wireSrc = null`), no wire
     created.
   - **A different terminal**: checks for an existing wire between the
     same two `(module, terminal)` pairs in either direction (`dup`
     check, `wire-editor.js:87-90`); if found, rejects with a toast
     ("Wire already exists") and resets `wireSrc`, creating nothing.
     Otherwise builds a new wire object and pushes it to `WIRES`.
5. The new wire: `{id: 'wire-' + Date.now(), c: 'W', lbl: 'New Wire',
   from: {m, t}, to: {m, t}, desc: 'User-created wire', R: [...]}` —
   `R` is the 4-row meter-reading table, initialized blank.
6. `selW` is set to the new wire; 300ms later `editWireProps()`
   auto-opens the wire-properties modal so the user can set color/label
   immediately (`wire-editor.js:101-104`).
7. There is **no explicit "cancel wire creation"** function distinct
   from re-clicking the source terminal or (per `app.js`'s Escape
   cascade, confirmed in earlier research) pressing Escape while
   `wireSrc` is armed.

**V2 never creates a wire with a route** — `wireRoutes[wireId]` (the
relative segment-offset override map) is a *separate*, user-later-edited
structure (`js/editor/routing-editor.js`), untouched at creation time. A
freshly created wire always renders via V2's own auto-router with no
overrides. This matters for §10 (route handling).

## 2. OEP Relationship Creation Workflow

`DiagramStudioController.createRelationship(sourceNodeId, targetNodeId)`
(already existed, unmodified by this task):

```dart
void createRelationship(String sourceNodeId, String targetNodeId) {
  engine.editing.execute(CreateRelationshipCommand(EngineeringRelationship(
    id: engine.graph.generateId('rel'),
    relationshipType: RelationshipType.connectedTo,
    sourceNode: sourceNodeId,
    targetNode: targetNodeId,
  )));
  markDirty();
}
```

and `updateRelationshipMetadata(relationshipId, patch)` (also pre-existing,
via `UpdateRelationshipPropertiesCommand`) for label/color. **No new
Controller method was needed for this task** — both already existed in
exactly the shape required.

## 3. V2 Identity

A V2 wire's `id` is either an authored string (base-vehicle wires, from
`wires.json`) or, for user-created wires, `'wire-' + Date.now()`
(`wire-editor.js:93`) — the same "established, not discovered, session-
stable-once-created" characteristic as user-created modules
(`DIAGRAM_STUDIO_V2_MODULE_BRIDGE.md` §2). Not an array index, not a
screen position.

## 4. OEP Identity

`EngineeringRelationship.id` — a caller-supplied string, generated here
via `engine.graph.generateId('rel')` inside the existing
`createRelationship`, exactly as module ids are generated inside
`addNodeWithMetadata`.

## 5. Terminal Identity

V2 terminal identity is `(moduleId, terminal display name)` — the
terminal itself has no separate id field; `m.terminals` is an array of
`{n: name, c: wireColor}` with no persistent identifier beyond the
`name` string, which is only unique *within* a module (not checked for
uniqueness by V2 at all).

## 6. Terminal → Port Mapping

**Checked directly against real data before writing any code.**
`EngineeringNode.ports` (`platform/oep_engine/lib/core/graph/models/`)
uses OEP's `Port` model (`id`/`name`/`direction`/`type`/`metadata`).
Symbol-defined ports were inspected for the two categories the module
bridge task can already create nodes for:

- `ground.json`: **one** port, `id: "ground"`, `displayName: "Ground"`.
- `connector.json`: **four** fixed ports, `pin_1`..`pin_4`.

V2's own authored terminal data for a `ground`-category module (e.g.
`chassis-ground`, `diagrams/trx300/modules.json`) has terminals named
`"A"`, `"B"` — **no relationship whatsoever** to the symbol's own port
name `"ground"`. More generally, V2 modules can have any number of
terminals with any author-chosen names; OEP's ground/connector symbols
have a small **fixed**, generic port template (1 and 4 ports
respectively) that doesn't scale to arbitrary V2 terminal counts at all.

Beyond that: **`addNodeWithMetadata` (used by the module bridge to
create every bridged node) never populates `EngineeringNode.ports` from
the symbol definition in the first place** — every bridge-created node
today has `ports: const []`. There is currently no OEP port instantiated
on any bridged node to map a V2 terminal onto, even before asking
whether the mapping would be deterministic.

**And more fundamentally**: `EngineeringRelationship` itself
(`sourceNode`/`targetNode`, both plain node-id strings — inspected
directly, §2) has **no port field at all**. Port-level endpoint
precision is not something the current Engine relationship model can
represent, regardless of what mapping might exist on the V2 side. This
is not a bridge-adapter limitation to be creative around — it is a
characteristic of the frozen Engine model.

**Classification: TERMINAL MAPPING GAP, and separately, ENGINE GAP for
port-level relationship endpoints.** No fabricated mapping (name
matching, index-based, or otherwise) was implemented. Per this task's
own Phase 3 instruction, wire creation proceeds **node-to-node only**
(§7) rather than being blocked entirely — this is the "provable portion"
the task's PARTIAL success criteria anticipated.

## 7. Endpoint Mapping

V2's `(fromModuleId, fromTerminal)`/`(toModuleId, toTerminal)` collapse
to `(fromModuleId, toModuleId)` at the OEP level — the terminal names are
received by the bridge (`V2WireCreatedMessage.fromTerminal`/`toTerminal`)
but **not used**, since there is nowhere in `EngineeringRelationship` to
put them (§6). Both module ids must already be mapped to an OEP node
(via the module bridge's `ground`/`connector` category mapping) for the
wire to be bridged at all — a wire with either endpoint unmapped is
recorded in `unbridgedV2WireIds` and no relationship is created.

## 8. Relationship Semantics

| V2 property | OEP property | Classification |
|---|---|---|
| source module + terminal | `sourceNode` (module only) | **ADAPTER REQUIRED** (terminal dropped, §6/§7) |
| target module + terminal | `targetNode` (module only) | **ADAPTER REQUIRED** (terminal dropped) |
| direction (from→to) | preserved as `sourceNode`/`targetNode` order | **DIRECT** |
| connection type | *(V2 has none beyond "it's a wire")* | **NOT APPLICABLE** |
| `relationshipType` | fixed `RelationshipType.connectedTo` (same value every other Controller-created relationship already uses, e.g. `createRelationship`'s pre-existing behavior) | **NOT APPLICABLE** — no V2 concept to map from |
| `lbl` (label) | `metadata['label']` | **DIRECT** — established key, already used by `EngineeringRelationshipProperties`/`v2_wire_painter.dart`/`diagram_scene_adapter.dart` |
| `c` (color code) | `metadata['wireColor']` | **DIRECT** — same, established key |
| `desc` (description) | *(no established metadata key found for this)* | **ENGINE GAP (tentative)** — not attempted |
| `R` (4×5 meter-reading table) | *(no OEP field)* | **ENGINE GAP** — same finding as the functional assessment §6, confirmed again |
| initial route (always auto-routed at creation, §1) | `SetWireRouteCommand`'s absolute point list — but never invoked, since V2 sends no override at creation | **NOT APPLICABLE for creation** (§10) |

## 9. Metadata Mapping

Exactly `label` and `wireColor`, using the **already-established** keys
(`metadata['label']`, `metadata['wireColor']`) — confirmed in use
elsewhere in the codebase (`engineering_relationship_properties.dart`,
`v2_wire_painter.dart`, `diagram_scene_adapter.dart`,
`wire_report.dart`) before writing any bridge code, per this task's own
"do not invent additional keys" instruction. No new metadata keys were
added.

## 10. Route Handling

Per §1, V2 never sends an initial custom route at creation time — a
freshly created wire always uses V2's own auto-router with zero
`wireRoutes` overrides. There is therefore **nothing to convert** for
this task: `SetWireRouteCommand` is never called by the wire-creation
bridge. Route *editing* (the actual `wireRoutes` relative-offset-vs-
absolute-points mismatch already documented by AP-DIAGRAM-V2-011 and the
functional assessment §6) remains completely untouched and deferred, as
this task's own Phase 13 requires.

## 11. Authoritative Result Flow

```
V2 handleWireTerm creates WIRES entry (both endpoints already mapped)
    -> poll diff detects new WIRES id
    -> adapter: createRelationship(sourceNodeId, targetNodeId)
    -> adapter: updateRelationshipMetadata(id, {label, wireColor})
    -> read back controller.engine.editing.session.graph.relationships[id]
       (not assumed — what's actually stored)
    -> confirmWireCreated(v2WireId, authoritative label, authoritative color) -> V2

V2 handleWireTerm creates WIRES entry (an endpoint unmapped)
    -> poll diff detects new WIRES id
    -> adapter: no OEP node for one endpoint -> unbridgedV2WireIds.add(id)
    -> nothing sent to V2 (V2's own wire object is already exactly what
       V2 wants; there is no OEP authoritative state for it)
```

No step assumes the request was accepted verbatim, per this task's
Phase 7 — the label/color sent back to V2 are always read from the
relationship's own `metadata` after `updateRelationshipMetadata` runs,
not the raw input.

## 12. Dirty-State Result

Unchanged mechanism: `createRelationship` and `updateRelationshipMetadata`
both call the Controller's existing `markDirty()` internally (pre-existing
code, untouched). No bridge-specific dirty-state logic was added.

## 13. Undo

**Observed, not changed**: `_handleWireCreated` issues **two** real
commands in sequence — `CreateRelationshipCommand` (via
`createRelationship`), then `UpdateRelationshipPropertiesCommand` (via
`updateRelationshipMetadata`, for label/color). OEP's existing undo stack
reverts them **one at a time**: the first `commands.undo()` after a wire
creation only reverts the metadata patch (relationship still exists,
label/color reset to empty); a **second** `commands.undo()` is what
actually removes the relationship. This is real, verified behavior (live,
by the developer, and by the adapter test), not something this bridge
merges into one step or otherwise changes — per this task's own explicit
instruction ("if OEP's existing command semantics combine multiple
actions... document the actual behavior rather than changing it").

Once the relationship is actually gone,
`LegacyV2StateAdapter.resyncLastBridgedToV2()` (the same dispatcher the
module bridge task introduced, now also handling wires via a
`_BridgedKind` tag distinguishing "the last bridged thing was a module"
from "...was a wire") calls `channel.removeWireFromV2`, which removes the
wire from V2's own `WIRES`/`wireRoutes` and redraws — mirroring the
module bridge's create-undo behavior exactly.

**Wire creation has no restore-on-undo-of-delete case** — this task
doesn't bridge wire deletion at all, so there is no "delete wire, then
undo" scenario to handle here.

## 13a. Bug Found and Fixed During Live Verification: Cross-Event Message Ordering

Live testing surfaced a real bug, not a documentation-only finding.
Reproduction: create a new module, then **immediately** (within roughly
the same 400ms poll window) wire it to another module. A single
`commands.undo()` afterward removed the **module's own `CreateNode`
command**, not the wire's metadata patch as §13 describes — meaning the
module's creation command had ended up on the undo stack *above* (more
recent than) the wire's two commands, even though the module was created
first.

**Root cause**: the injected script originally called
`window.chrome.webview.postMessage` once per detected event, immediately,
inline. When a module-created event and a wire-created event were both
detected in the same 400ms poll tick, this meant two separate
`postMessage` calls in quick succession. WebView2 does not guarantee
that independently-issued `postMessage` calls are delivered to the
Dart-side `webMessage` stream in the order they were sent — the wire's
message was, at least once, observed to be processed before the
module's, so `_handleWireCreated`'s `createRelationship` executed before
`_handleModuleCreated`'s `addNodeWithMetadata`, inverting the expected
command order.

**Fix**: the injected script now accumulates every event detected in one
poll tick into a `pending` array and sends it as **one** `type: 'batch'`
message at the end of the tick, instead of one message per event.
`LegacyV2BridgeTransport._onRawMessage` dispatches a batch's entries in
array order, synchronously, one Dart stream event instead of several —
there is now only one native round trip per tick, so there is no
opportunity for the transport to reorder events that were detected
together. This is a transport-layer fix only; no adapter logic changed,
and the existing adapter test suite (which drives the adapter directly,
bypassing the transport) continued passing unmodified, confirming the
bug was specifically in cross-event delivery ordering, not in the
adapter's own command sequencing.

## 14. Loop Prevention

Extends the existing pattern with the smallest addition possible: a
`lastWires` id-set snapshot (parallel to `lastModules`), diffed each
poll — an id is reported as `wireCreated` exactly once, the poll tick it
first appears. There is no ongoing wire-property polling/echo path to
loop against (this task doesn't bridge wire editing at all), so unlike
modules there's no `syncedWireProps`-style guard needed — creation is
inherently a one-shot, not-re-triggerable event once the id is in
`lastWires`.

## 15. Invalid Connection Handling

V2 itself already rejects, before ever touching `WIRES`:

- **Re-clicking the same terminal**: cancels arm state, no wire object
  created at all — nothing for the bridge to see.
- **Duplicate wire** (same two `(module, terminal)` endpoints, either
  direction): rejected with a toast, no wire object created.

Since both rejections happen entirely inside V2, **before** any `WIRES`
mutation the bridge's poller could observe, the bridge never sees an
invalid-connection attempt at all — there is nothing to additionally
guard against on the OEP side for these two cases. **Same-module wiring**
(two different terminals on the same module) is technically permitted by
V2's own validation (only exact-same-terminal and exact-duplicate-pair
are checked); if bridged, this would produce a self-referencing
relationship (`sourceNode == targetNode`) — not specifically tested or
prevented by this bridge, since V2 itself does not prevent it. **The one
case this bridge itself guards**: an endpoint module with no OEP mapping
— handled by refusing to create anything (§7), never by mutating OEP with
a partial/fabricated node.

## 16. Selection Behavior

V2 automatically selects the newly created wire (`selW = nw`,
`wire-editor.js:101`) — this is V2's own existing behavior, unmodified,
and the bridge does not additionally touch OEP's own relationship
selection mechanism (no `engine.registry.selection.selectRelationship`
call exists in `_handleWireCreated`) — consistent with the module bridge
task's `deleteNode`/`renameNode` precedent of not touching selection for
operations that aren't literally "create a new thing the user is about
to look at." (Module creation, by contrast, already called
`selectNode` before this task, via the pre-existing `addNode`/
`addNodeWithMetadata` — that precedent stands, unchanged; this task
simply doesn't add an equivalent for relationships.)

## 17. Persistence Boundary

Unchanged from AP-DIAGRAM-V2-WEBVIEW-001/002 — nothing here crosses it.
`_v2ToOepRelationshipId` is in-memory only, lost on restart. No
persistence work was implemented or attempted.

## 18. Exact Limitations

- **Node-to-node only** — terminal-level endpoint precision is
  permanently unavailable without an Engine model change (§6), out of
  this task's scope.
- **Only 2 of 11 V2 module categories are bridgeable** (inherited from
  the module bridge task) — a wire touching any other-category module
  cannot be bridged at all, regardless of wire logic.
- **`desc` and the 4×5 meter-reading table (`R`) are not bridged** — no
  established OEP field found; not attempted.
- **Two-command undo semantics** (§13) — a single undo after wire
  creation only reverts label/color, not the relationship's existence;
  documented, not merged into one step.
- **Self-loop wires are not specifically guarded** — V2 itself doesn't
  prevent wiring two terminals on the same module; if bridged, OEP would
  get a `sourceNode == targetNode` relationship. Not exercised in
  testing.
- **Session-scoped mapping only** (unchanged pattern).

## 19. Deferred Operations

Per this task's stop conditions — not started: wire deletion, wire
editing, route editing/reconnect, simulation/multimeter, persistence,
command-palette removal, Flutter renderer deletion, production/cross-
platform WebView work.

## 20. Architectural Conclusion

The three-layer bridge extends to relationship creation with **zero
Controller changes** — both `createRelationship` and
`updateRelationshipMetadata` already existed in exactly the shape this
task needed, which is itself informative: OEP's relationship model was
already node-level, not port-level, well before this bridge existed.
The dominant limitation is the same shape as the module bridge task's
(§6 of that doc) — a data/model-completeness gap, not an architectural
one. Terminal-level wire fidelity would require an Engine-level decision
about whether/how to add port references to `EngineeringRelationship`,
which is explicitly out of scope for a bridge task to decide unilaterally.
