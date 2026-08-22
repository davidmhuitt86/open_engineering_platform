# AP-DIAGRAM-V2-WEBVIEW-002 — Legacy V2 Module Lifecycle Bridge

> Builds on
> [`DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md`](DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md)
> (the three-layer architecture this task extends, unchanged in shape) and
> [`DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md`](DIAGRAM_STUDIO_V2_FUNCTIONAL_BRIDGE_ASSESSMENT.md)
> (§5's module-creation gap, confirmed and resolved here). Does not
> rewrite either document.

## 1. Module Lifecycle Architecture

Same three layers, same direction, extended with three new message
kinds:

```
LegacyV2WebViewPage
        |
        v
LegacyV2BridgeTransport   — + moduleCreated/moduleDeleted/modulePropertiesChanged
        |                     (V2-vocabulary only, still zero OEP knowledge)
        v
LegacyV2StateAdapter       — + category->symbol table, delete/rename dispatch
        |
        v
DiagramStudioController    — + addNodeWithMetadata/deleteNode/renameNode
        |
        v
OEP Engine                  — existing CreateNodeCommand/DeleteNodeCommand/
                               RenameNodeCommand (no new Engine commands)
```

## 2. V2 Module Creation

`commitAddModule()` (`js/editor/module-editor.js:186-216`) builds
`{id, label, sub, cat, exit, terminals, _user:true}`, pushes it to
`MODULES`, and sets `positions[id]`. `id` is generated as
`'mod-' + slug(label) + '-' + Date.now()` — unique and stable once
created, though not human-authored the way base-vehicle module ids are.
There is no create-*event*; the bridge detects it the same way it
detects everything else V2 doesn't expose an event for — by polling and
diffing (§7).

## 3. V2 Module Deletion

`delModule(modId)` (`module-editor.js:218-226`) requires a native
`confirm()`, then removes the module from `MODULES`, removes any wire
referencing it from `WIRES` (cascading — the same shape as OEP's
`DeleteNodeCommand`, which also cascades relationship removal), removes
its card, and deletes its `positions` entry. By the time the bridge's
poller detects the id is gone, V2 has already fully removed it — there is
nothing further to do to V2's *display*; the bridge's job is only to make
OEP's graph match.

## 4. V2 Property Editing

`saveModProps()` (`module-editor.js:274-306`) can change `label`, `sub`,
`cat`, `exit`, `notes`, and `terminals` in place on the existing module
object, then calls `rebuildCard`. Of these, this task bridges **only
`label`** — see §7 for why.

## 5. V2 → OEP Mapping (Identity)

Unchanged principle from AP-DIAGRAM-V2-WEBVIEW-001: V2's `m.id` has no
pre-existing OEP counterpart; the mapping is **established** at creation
time (not discovered) and kept in `LegacyV2StateAdapter`'s own
session-scoped `Map<String, String>`. No index, screen position, or
random id is used.

## 6. Symbol/Type Mapping

V2's 11 module categories (`index.html`'s `<select>` options for
`am-cat`/`mpm-cat`) were checked against OEP's actually-registered
symbols (`platform/oep_engine/assets/symbols/*.json` — 13 files:
`battery`, `capacitor`, `connector`, `diode`, `fuse`, `generic_module`,
`ground`, `ignition_coil`, `lamp`, `motor`, `relay`, `resistor`,
`spdt_switch`, `spst_switch`).

| V2 category | OEP symbol match | Deterministic? |
|---|---|---|
| `ground` | `ground` | **Yes** — identical string |
| `connector` | `connector` | **Yes** — identical string |
| `ignition` | *(none)* | No — `ignition_coil` exists, but "ignition" doesn't specifically mean "coil"; could be a CDI unit, spark plug, etc. Guessing is exactly the fabrication this task prohibits |
| `switch` | *(none)* | No — `spst_switch`/`spdt_switch` both exist; V2's `switch` category doesn't distinguish which, and picking one would be a guess |
| `lighting` | *(none)* | No — `lamp` exists, but a "lighting" module could be a socket/relay/multi-bulb assembly, not necessarily a single lamp |
| `power`, `charging`, `starter`, `control`, `indicator`, `accessory` | *(none)* | No symbol name is implied by these category strings at all |

**Implemented mapping table** (`LegacyV2StateAdapter._symbolIdForCategory`):
exactly the two deterministic entries — `ground` → `ground`,
`connector` → `connector`. Nothing else. The `'battery'` placeholder used
for *every* category by the previous task
(`AP-DIAGRAM-V2-WEBVIEW-001`'s `addNode`-on-first-move fallback) has been
**retired** — it does not silently continue as the architecture, per this
task's own explicit instruction.

**Result for the other 9 categories**: a V2 module created in one of
them is added to `unbridgedV2ModuleIds` and never given an OEP node. It
remains fully functional and visible in V2 (V2 is unmodified and doesn't
know or care), but it is **not represented in OEP's graph at all** — no
node, no position tracking, no undo, no dirty-state contribution from
that module. This is the PARTIAL result the task's own success criteria
anticipated for exactly this situation.

## 7. Property Mapping

| V2 property | Classification | Reasoning |
|---|---|---|
| `label` | **DIRECT** (bridged) | Both `label` and OEP's `EngineeringNode.displayName` are freeform display strings with no taxonomy behind them — a genuine 1:1 concept, no translation needed beyond the field rename. Bridged via the existing `RenameNodeCommand`. |
| `cat` (category) | **BLOCKED for this task** | OEP's `NodeCategory` enum is a *different*, Engine-defined taxonomy from V2's 11 free-text categories (§6's mismatch problem, again). `ChangeNodeCategoryCommand` exists and could theoretically be called, but mapping V2's `cat` string onto a `NodeCategory` value would face the identical fabrication risk as symbol mapping. Not bridged. |
| `sub` (sublabel) | **ENGINE GAP (tentative)** | No existing `EngineeringNode` field obviously corresponds; could plausibly live in `properties`/`metadata`, not attempted this task. |
| `exit` (wire-exit direction) | **BLOCKED / not applicable** | A V2-specific rendering hint (which side wires exit the card from) with no OEP diagram-rendering equivalent found. |
| `notes` | **ENGINE GAP (tentative)** | Same reasoning as `sub` — plausibly a `properties`/`metadata` entry, not attempted. |
| `terminals` | **ENGINE GAP** | V2 terminals are `{n, c}` (name + wire color); OEP's `Port` model (`id`/`name`/`direction`/`type`/`metadata`) is a different, richer shape with no deterministic 1:1 conversion attempted here (same finding as the functional assessment §3's port row). Not bridged — see §15's limitation on undo-of-delete losing terminals. |

## 8. Identity Mapping

Same as §5 — restated here only because the task's documentation list
asks for it as its own numbered section; no new content beyond §5.

## 9. Authoritative Result Flow

```
Create (mapped category):
  V2 commitAddModule -> poll diff detects new MODULES entry
    -> adapter: symbol lookup succeeds -> addNodeWithMetadata
    -> read back authoritative position -> sendAuthoritativeModulePosition -> V2

Create (unmapped category):
  V2 commitAddModule -> poll diff detects new MODULES entry
    -> adapter: symbol lookup fails -> recorded in unbridgedV2ModuleIds
    -> nothing sent to V2 (V2's own object is already exactly what V2 wants;
       there is no OEP authoritative state to send back)

Delete:
  V2 delModule -> poll diff detects id missing from MODULES
    -> adapter: DeleteNodeCommand via controller.deleteNode
    -> nothing sent to V2 (V2 already reflects the deletion by the time
       the bridge notices)

Property edit (label only):
  V2 saveModProps -> poll diff detects label/cat difference
    -> adapter: if label changed, RenameNodeCommand via controller.renameNode
    -> read back authoritative displayName -> sendAuthoritativeModuleLabel -> V2
```

No step assumes the requested value was accepted verbatim — every path
re-reads `controller.engine.editing.session` after the mutation before
telling V2 anything, same discipline as the move operation
(`DIAGRAM_STUDIO_V2_BRIDGE_ARCHITECTURE.md` §14).

## 10. Dirty State

Unchanged mechanism: `addNodeWithMetadata`, `deleteNode`, and
`renameNode` each call the Controller's existing `markDirty()` internally
(same file, same pattern as `addNode`/`moveNodes`). No bridge-specific
dirty-state code exists anywhere in this task's changes.

## 11. Undo

Verified independently for all three operations (live, by the developer,
and by the new adapter test):

- **Create → undo**: the Engine's `CreateNodeCommand.revert` removes the
  node. `resyncLastBridgedModuleToV2` sees the node no longer exists and
  calls `channel.removeModuleFromV2`, which removes the module from V2's
  own `MODULES`/`positions`/card state (injected `__oepBridgeRemoveModule`).
- **Delete → undo**: `DeleteNodeCommand.revert` restores the node (and
  its cascaded relationships/group memberships, per that command's own
  doc comment). `resyncLastBridgedModuleToV2` calls `channel.restoreModule`
  with the label/category stashed in `EngineeringNode.metadata` at
  creation time, reconstructing a V2 module object via the injected
  `__oepBridgeRestoreModule` (idempotent — a no-op if V2 already has the
  module, which matters for the move/rename-undo cases below).
- **Property edit → undo**: `RenameNodeCommand.revert` restores the
  previous `displayName`; `resyncLastBridgedModuleToV2` re-sends the
  label via `sendAuthoritativeModuleLabel`.

**Command-stack combination behavior, observed rather than changed**: a
single `commands.undo()` call always reverts exactly the *one* most
recent command, matching every other Diagram Studio undo — this task
introduces no multi-step or batched undo semantics.

`resyncLastBridgedModuleToV2` handles all three cases with the same three
calls every time (`restoreModule` -> `sendAuthoritativeModulePosition` ->
`sendAuthoritativeModuleLabel`), relying on `restoreModule`'s own
idempotence rather than branching in Dart — see the method's own doc
comment in `legacy_v2_state_adapter.dart`.

## 12. Loop Prevention

Extends the existing pattern (position sync's `synced`/`lastSeen` maps)
rather than introducing a new mechanism:

- **Create/delete**: naturally loop-free — the poller's own
  previous-vs-current `MODULES` snapshot diff (`lastModules`) means an id
  is reported as created/deleted exactly once, on the poll tick where it
  actually changes; there is no "echo" direction for create/delete to
  loop against (the bridge never re-adds/re-removes a module in V2 on its
  own initiative outside of an explicit undo-resync, which is guarded
  separately below).
- **Property edit**: a new `syncedModuleProps` map, updated by
  `__oepBridgeApplyModuleLabel` at the same time it writes V2's `label`,
  mirrors the existing position-sync guard exactly — the poller only
  reports a `modulePropertiesChanged` event if the current label differs
  from what this bridge itself most recently applied.
- **Undo-resync restore/remove**: `__oepBridgeRestoreModule` guards
  itself (`if module already present, return`) and
  `__oepBridgeRemoveModule` simply removes whatever's there — neither can
  loop because neither is triggered by the poller; they're only ever
  called from `resyncLastBridgedModuleToV2`, itself only ever called from
  the widget's Undo button.

## 13. Selection Behavior

Unchanged from AP-DIAGRAM-V2-WEBVIEW-001: `addNodeWithMetadata` calls
`engine.registry.selection.selectNode(id)` (same as `addNode` already
did) — a bridge-created module becomes OEP's current selection, exactly
as any other new node would. `deleteNode` and `renameNode` do **not**
touch OEP selection at all, deliberately — deleting or renaming a
specific node by id has no reason to perturb whatever else might be
selected. No new selection state was introduced; V2's own `selM` remains
entirely V2's own concern, never read or written by OEP's selection
system.

## 14. Current Limitations

- **Session-scoped mapping only** (unchanged from AP-DIAGRAM-V2-WEBVIEW-001).
- **Single-entry undo tracking** (unchanged) — `lastBridgedV2ModuleId`
  only remembers the most recently touched module across move/create/
  delete/property-edit; a multi-module undo sequence only resyncs
  correctly for the one most recently touched.
- **Only 2 of 11 V2 categories are bridgeable for creation** (§6) — this
  is the dominant limitation of this task.
- **Only `label` is bridged for property edits** (§7) — `cat`/`sub`/
  `exit`/`notes`/`terminals` are not.
- **Undo-of-delete restore loses terminals** — `__oepBridgeRestoreModule`
  reconstructs a V2 module with `terminals: []` (empty) since terminals
  are never mirrored into OEP's `EngineeringNode.metadata` at creation
  time; a restored module will render with no terminal dots until the
  page is reloaded (which re-reads V2's own base data, if the module was
  a base-vehicle one — user-created modules with no base data would stay
  terminal-less until manually edited back in via V2's own property
  editor).
- **No V2-category → `NodeCategory` mapping** — a bridged node's
  `NodeCategory` is always `NodeCategory.component`, same fixed value
  `addNode`/`addNodeWithMetadata` already used before this task; no
  attempt was made to vary it by V2 category (§7).

## 15. Unsupported Properties

`sub`, `exit`, `notes`, `terminals`, `cat` — see §7's table for the
per-property reasoning. None are silently dropped without documentation;
V2 keeps them exactly as authored (V2 is unmodified), they simply have no
OEP-side counterpart yet.

## 16. Persistence Boundary

Unchanged from AP-DIAGRAM-V2-WEBVIEW-001 — nothing here crosses it. The
`v2ModuleId` → OEP node id map, and the fact that a module was ever
created/mapped, exist only in `LegacyV2StateAdapter`'s in-memory field.
No cross-session persistence was implemented or attempted; V2's own
project JSON and OEP's document format remain unreconciled, per this
task's own explicit instruction that this is a separate architecture
task.

## 17. Deferred Functionality

Per this task's stop conditions — not started: wire creation/deletion/
selection/routing/editing/reconnect/metadata; simulation/multimeter
bridging; persistence; command-palette removal; Flutter renderer
deletion; production/cross-platform WebView work.

## 18. Future Bridge Considerations

- **Symbol authoring is the actual unlock for the other 9 categories** —
  this is not a bridge-code problem; it's a "someone needs to author
  real OEP symbols (or decide `generic_module` is an acceptable
  deliberate choice, not a silent fallback) for `power`/`ignition`/
  `charging`/`lighting`/`starter`/`switch`/`control`/`indicator`/
  `accessory`" decision, explicitly out of scope for a bridge task to
  make unilaterally.
- **Terminal mirroring** would need a deliberate metadata schema decision
  (how much of V2's `{n, c}` shape to store, and whether it should
  eventually become real OEP `Port`s instead of opaque metadata) before
  the undo-of-delete terminal-loss limitation (§14) can be closed.
- **Category taxonomy reconciliation** (`cat` bridging) needs a real
  mapping decision from whoever owns OEP's `NodeCategory` taxonomy — not
  something a bridge adapter should invent unilaterally, per this task's
  own repeated instruction against fabricated mappings.
