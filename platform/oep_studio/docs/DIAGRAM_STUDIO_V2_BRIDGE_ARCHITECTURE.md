# AP-DIAGRAM-V2-WEBVIEW-001 — Legacy V2 Bridge Architecture

> Builds on, does not replace, the POC documents:
> [`DIAGRAM_STUDIO_V2_WEBVIEW_POC.md`](DIAGRAM_STUDIO_V2_WEBVIEW_POC.md) (POC-001, embedding),
> [`DIAGRAM_STUDIO_V2_BRIDGE_POC.md`](DIAGRAM_STUDIO_V2_BRIDGE_POC.md) (POC-002, bidirectional messaging),
> [`DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md`](DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md)
> (the functional/architectural assessment this task's component
> boundaries are drawn from). The node-movement mutation itself was
> proven working end-to-end before this task (POC-003's investigation);
> this task is the first production-shaped implementation of that same
> operation, not a new proof.

## 1. Purpose

Establish the clean three-layer separation the functional assessment
called for, and migrate the already-proven V2-module-move ->
OEP-Engine-mutation operation onto it — nothing more. This is
infrastructure, not a feature expansion: no new bridged operations (no
wires, no module create/delete, no simulation) were added in this task.

## 2. Architectural Decision

**Legacy V2 = Diagram Studio's presentation/interaction layer. OEP Engine
= the authoritative engineering model. Flutter/OEP Studio = native host +
bridge/adaptation layer.** This is now the authorized direction (per this
task's own framing), superseding further native-Flutter reconstruction of
V2's visuals/interactions as the active development path — without
deleting or disabling the existing Flutter renderer, which remains the
fallback.

## 3. Component Boundaries

```
LegacyV2WebViewPage           (Flutter widget — WebView host only)
        |
        v
LegacyV2BridgeTransport        (WebView<->Dart messages; zero OEP knowledge)
        |
        v
LegacyV2StateAdapter            (V2 id <-> OEP node id; coordinates; loop guard)
        |
        v
DiagramStudioController        (unchanged — addNode/moveNodes/commands)
        |
        v
OEP Engine                      (unchanged — CreateNodeCommand/MoveNodesCommand)
```

Files:

- [`lib/diagram_studio/webview/legacy_v2_webview.dart`](../lib/diagram_studio/webview/legacy_v2_webview.dart) — `LegacyV2WebViewPage`
- [`lib/diagram_studio/webview/legacy_v2_bridge_transport.dart`](../lib/diagram_studio/webview/legacy_v2_bridge_transport.dart) — `LegacyV2BridgeTransport`, `LegacyV2Channel`, message types
- [`lib/diagram_studio/webview/legacy_v2_state_adapter.dart`](../lib/diagram_studio/webview/legacy_v2_state_adapter.dart) — `LegacyV2StateAdapter`
- `lib/diagram_studio/controller/diagram_studio_controller.dart` — unchanged, only consumed

The earlier POC-002/003 implementation combined transport and adapter
concerns into one `LegacyV2Bridge` class plus an injected-script constant
living inside the widget file itself. Both are now removed
(`legacy_v2_bridge.dart` deleted); their logic is redistributed across the
three files above.

## 4. LegacyV2WebView (`LegacyV2WebViewPage`)

Owns the `WebviewController`/`Webview` widget, resolves and loads V2's
`file://` entry point (unchanged path-resolution logic from POC-001/003),
constructs the transport and adapter, and renders the status bar +
toolbar actions (Undo/Fit/Reload) used for live verification. It does
**not** contain OEP ID mapping, coordinate conversion, Engine command
logic, persistence logic, or business rules — every one of those now
lives in `LegacyV2StateAdapter`. The one thing the widget calls directly
on the transport, `executeRawScript`, is reserved for non-mutating,
non-business-logic calls (today: `zReset()` for "Fit view") — no bridged
operation should be added by reaching for this method.

## 5. LegacyV2BridgeTransport

Pure communication layer: owns the `WebviewController`, the one injected
script (`addScriptToExecuteOnDocumentCreated`, still never written to any
file under `reference/legacy_wiring_sim_v2/eke-wiring-sim/`), the
`webMessage` listener, and `executeScript` calls. It knows the shape of
two message types (`V2ModuleMovedMessage`, `V2StatusMessage`) — both
expressed purely in V2's own vocabulary, an id and an x/y pair — and
nothing about `EngineeringNode`, `EngineeringRelationship`,
`DiagramStudioController`, or `MoveNodesCommand`. It implements
`LegacyV2Channel`, the narrow interface `LegacyV2StateAdapter` actually
depends on, which is what makes the adapter's logic testable without a
real `WebviewController` (§17).

## 6. LegacyV2StateAdapter

The only layer that knows both vocabularies. Owns:

- **Identity mapping** (§9) — `Map<String, String> _v2ToOepNodeId`,
  session-scoped only.
- **Coordinate conversion** (§10) — currently the identity function.
- **Loop prevention** (§11) — split between this class and the injected
  script (two halves of one guard, not two separate mechanisms).
- **Dispatch** — calls only `DiagramStudioController.addNode`/`moveNodes`/
  `commands.undo`, never `engine.editing.execute` directly.
- **Authoritative-result read-back** — reads
  `controller.engine.editing.session` (the Engine's own live session)
  immediately after a mutation, not `controller.session` (see §14's note
  on why that distinction matters).

## 7. DiagramStudioController

Unchanged. `addNode`, `moveNodes`, `commands.undo`/`canUndo`, and the
existing `markDirty()`/dirty-state behavior are consumed exactly as they
already existed before this task — no new methods were added to this
class, per this task's own "Do not move bridge-specific logic into the
Controller" instruction.

## 8. Message Flow

```
V2 drags a module
    -> V2's own `positions[id]` updates every mousemove tick (V2-internal, unobserved)
    -> injected script polls `positions` every 400ms
    -> position stable for 2 consecutive polls (~800ms) AND differs from
       last-synced value
    -> window.chrome.webview.postMessage({type:'moduleMoved', payload:{id,x,y}})
    -> LegacyV2BridgeTransport.webMessage listener -> V2ModuleMovedMessage
    -> LegacyV2StateAdapter._handleV2ModuleMoved
    -> DiagramStudioController.addNode (first sight) or .moveNodes (reuse)
    -> existing CreateNodeCommand / MoveNodesCommand -> OEP Engine
    -> adapter reads back controller.engine.editing.session's authoritative position
    -> LegacyV2Channel.sendAuthoritativeModulePosition(id, x, y)
    -> transport.executeScript -> window.__oepBridgeApplyAuthoritative(id, x, y)
    -> V2's own `positions[id]`, card style, and `drawWires()` updated
```

## 9. Identity Mapping

Unchanged from POC-003's finding, carried forward: V2's `m.id` is a
stable, authored string (`diagrams/<vehicle>/modules.json`) with no
pre-existing correspondence to any node in whatever OEP document happens
to be open. The adapter **establishes** the mapping the first time each
V2 module is moved — creating exactly one OEP node via the existing
`addNode` path and remembering the pair — rather than discovering one
that doesn't exist. **Session-scoped only**: the map lives in
`LegacyV2StateAdapter`'s own field, is never written to disk, and is lost
on restart. No array index, screen position, list order, or random id is
used anywhere in this mapping, per this task's explicit prohibition.

## 10. Coordinate Mapping

Identity: V2's module position (`positions[id]`, top-left, unscaled
canvas-pixel units — `js/editor/module-editor.js`'s drag handler,
`js/diagram/renderer.js`'s `placeCards`) is passed straight through as
`Point2D(x, y)`. No fresh source inspection this task found reason to
change POC-003's conclusion; `Point2D` itself carries no anchor semantic
(`diagram_geometry.dart`), so whatever convention the existing Diagram
Studio renderer already applies to a node's position is exactly what's
exercised, unchanged.

## 11. Loop Prevention

Two halves of one guard, matching the earlier POC's proven design,
unchanged in mechanism:

1. **Injected script** (`legacy_v2_bridge_transport.dart`'s
   `_kBridgeScript`) tracks, per module id, the last value
   `window.__oepBridgeApplyAuthoritative` wrote (`synced[id]`). A
   stabilized `positions[id]` value is only reported as a new
   `moduleMoved` event if it differs from `synced[id]`.
2. **`sendAuthoritativeModulePosition`** (the transport method the
   adapter calls after every mutation) is the only thing that ever calls
   `__oepBridgeApplyAuthoritative`, which is also what updates
   `synced[id]` — so the authoritative echo the adapter just caused is
   guaranteed to be recognized as already-synced on V2's own next poll,
   never reinterpreted as a fresh user move.

No generalized event/synchronization framework was built — this is the
smallest guard sufficient for the one bridged operation.

## 12. Undo Flow

`LegacyV2WebViewPage`'s "Undo" toolbar action calls
`DiagramStudioController.commands.undo()` (the existing, real Engine undo
stack — unchanged) and then `LegacyV2StateAdapter.resyncLastMovedModuleToV2()`,
which reads whatever position `controller.engine.editing.session.layout`
currently holds for the OEP node behind `lastMovedV2ModuleId` and re-sends
it through the same `sendAuthoritativeModulePosition` path used for a
normal move. No V2-side undo system exists or was created; V2 only ever
receives an authoritative "here is the current position," identically
whether it originated from a fresh move or an undo.

This single-entry guard (`lastMovedV2ModuleId` tracks only the most
recently bridged module) is sufficient for the one proven operation and
does not generalize to a multi-step undo history spanning several
different V2 modules — documented as a limitation (§14), not solved here.

## 13. Dirty-State Flow

Unchanged, and not touched by this task: `DiagramStudioController.addNode`
and `.moveNodes` already call `markDirty()` internally (existing code,
`diagram_studio_controller.dart`), so a V2-originated move marks the OEP
document dirty through exactly the same centralized mechanism every other
Diagram Studio edit already uses. No bridge-specific dirty-state code was
added anywhere.

## 14. Current Limitations

- **Session-scoped identity map only** — restarting OEP Studio loses the
  V2<->OEP correspondence entirely (§9, by this task's own explicit
  instruction not to design persistence here).
- **`controller.session` vs. `controller.engine.editing.session`**: the
  former is refreshed by an async stream subscription
  (`EngineeringProjectNotifier`'s `sessionChanges` listener) and can be
  stale for one or more microtasks after a mutation; the adapter
  therefore reads `controller.engine.editing.session` directly wherever
  it needs the authoritative post-mutation state immediately. This isn't
  new to this task (POC-003's code already did this correctly) but is
  documented here since it is easy to get wrong when extending the
  adapter.
- **Single-entry undo tracking** (§12) — only the most recently bridged
  V2 module can be re-synced after an undo; a user who moves module A,
  then module B, then triggers OEP undo twice, would see B re-sync
  correctly on the first undo but nothing re-synced to A on the second.
- **No edit-mode gating** — the injected script polls `positions`
  unconditionally, not only while V2's own `editMode` is true. The
  functional assessment flagged this as a correctness refinement; it was
  not implemented in this task (kept to the smallest guard necessary, per
  this task's own scope).
- **Placeholder symbol for every bridge-created node** — every OEP node
  created from a V2 module move uses the same `'battery'` symbol
  (`LegacyV2StateAdapter._placeholderSymbolId`); no V2-category ->
  OEP-symbol mapping exists (that gap was already named in the functional
  assessment §5, not solved here).

## 15. Explicitly Deferred Operations

Per this task's own stop conditions — not started:

- Module creation/deletion/properties bridging.
- Wire creation/deletion/selection/editing/route conversion/reconnect/
  metadata.
- Simulation/multimeter bridging.
- Persistence (ID-map durability, document-format bridge).
- Command-palette removal.
- Flutter renderer deletion.
- Production WebView packaging, cross-platform WebView support.

## 16. Persistence Boundary

Nothing crosses it. The identity map, and the fact that a bridge session
ever happened, exist only in `LegacyV2StateAdapter`'s in-memory field for
the lifetime of the `LegacyV2WebViewPage` widget. Restarting the app, or
even just popping and re-pushing the WebView route, creates a fresh
adapter with an empty map — a module moved in a previous session will,
the next time it's moved, be treated as never-before-seen and get a new
OEP node. This is a known, accepted limitation of this task's scope, not
an oversight; the functional assessment names the real persistence bridge
as separate future work.

## 17. Future Bridge Extension Rules

For whoever picks up the next deferred operation (§15):

1. **New message types belong in `legacy_v2_bridge_transport.dart`**,
   expressed in V2's own vocabulary only (ids, primitive values) — never
   an OEP type.
2. **New translation/business logic belongs in `LegacyV2StateAdapter`**,
   and must reach OEP only through `DiagramStudioController`'s existing
   (or newly added, if genuinely needed) methods — never
   `engine.editing.execute` directly from the adapter, and never from the
   widget.
3. **The widget stays thin.** If a change requires the widget to know an
   OEP concept, that logic is in the wrong layer.
4. **Test the adapter against `LegacyV2Channel` fakes**, not a real
   `WebviewController` — see
   `test/diagram_studio/webview/legacy_v2_state_adapter_test.dart` for
   the established pattern (a real, bootstrapped `DiagramStudioController`
   via the existing `DiagramStudioPage` test harness, paired with a fake
   channel).
5. **Read `controller.engine.editing.session` for anything that must be
   correct immediately after a mutation** (§14) — `controller.session` is
   for display/watch contexts, not read-after-write correctness.
