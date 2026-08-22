# AP-DIAGRAM-V2-BRIDGE-004 — Wire Creation/Selection/Deletion Bridge

> §§15-24 below (AP-DIAGRAM-V2-BRIDGE-005) add wire **property editing**
> (post-creation label/color) on top of everything documented here.
> §§1-14 are this task's own findings, re-verified where the new task's
> own Phase 1 required it, and otherwise left as originally written —
> nothing below rewrites a historical conclusion.

> Builds on
> [`DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md`](DIAGRAM_STUDIO_V2_WIRE_CREATION_BRIDGE.md)
> (wire creation was already implemented and live-verified in
> AP-DIAGRAM-V2-WEBVIEW-003 — this task re-confirmed that implementation
> against current source per its own Phase 1 instruction, and added
> selection + deletion),
> [`DIAGRAM_STUDIO_V2_BRIDGE_PRODUCTION_ARCHITECTURE.md`](DIAGRAM_STUDIO_V2_BRIDGE_PRODUCTION_ARCHITECTURE.md),
> [`DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md`](DIAGRAM_STUDIO_V2_BRIDGE_MIGRATION_PLAN.md),
> [`DIAGRAM_STUDIO_V2_BRIDGE_PERSISTENCE_ARCHITECTURE.md`](DIAGRAM_STUDIO_V2_BRIDGE_PERSISTENCE_ARCHITECTURE.md).
> Not rewritten here.

## 1. V2 Wire Creation Lifecycle

Unchanged from the prior task's own account — re-verified against
current `js/editor/wire-editor.js` this task, no drift found:
`toggleWireMode()` → two terminal clicks (`handleWireTerm`) → V2's own
duplicate-check (`dup`, either direction) and self-click cancel, both
happening *before* any `WIRES` mutation → `WIRES.push({id: 'wire-' +
Date.now(), c, lbl, from:{m,t}, to:{m,t}, desc, R:[...]})` → `selW` set
→ 300ms later `editWireProps()` auto-opens. No initial route is ever
stored (V2's auto-router handles rendering; `wireRoutes` stays untouched
at creation).

## 2. OEP Relationship Lifecycle

`DiagramStudioController.createRelationship(sourceNodeId, targetNodeId)`
→ `CreateRelationshipCommand` (existing, unmodified) →
`updateRelationshipMetadata` → `UpdateRelationshipPropertiesCommand`
(existing, unmodified). New this task:
`DiagramStudioController.deleteRelationship(relationshipId)` →
`DeleteRelationshipCommand` (existing, unmodified — this task only added
the thin Controller wrapper, same style as `deleteNode`). Selection:
`engine.registry.selection.selectRelationship`/`deselectAll` (existing,
confirmed by reading `selection_service.dart` directly — symmetric with
`selectNode`, as the prior task only presumed).

## 3. Terminal Identity Mapping — **ENGINE EXTENSION REQUIRED (confirmed again, not re-solved)**

Re-verified directly against current source this task, per Phase 1's
"inspect current code, not previous reports alone": `EngineeringNode.ports`
is still empty (`const []`) on every bridge-created node (`addNodeWithMetadata`
never populates it from the symbol definition); `EngineeringRelationship`
still has no port field at all (`sourceNode`/`targetNode` are plain node-id
strings — inspected `engineering_relationship.dart` directly, unchanged
since the prior task). **This is still an Engine model characteristic,
not something a bridge adapter can work around.**

Per this task's own Critical Decision framework: node-to-node wire
creation is classified **B (ADAPTER REQUIRED)** — the existing
relationship model represents "a wire exists between module A and
module B" with a documented, acceptable, non-fabricated mapping (drop
terminal precision, keep node-level direction/existence). Full
terminal-level fidelity is **C (ENGINE EXTENSION REQUIRED)** and remains
unattempted — this task did not reach the ENGINE EXTENSION STOP CONDITION
for creation because B was already sufficient to proceed (as it was in
the predecessor task), not because C was resolved.

**No fabricated substitute was used.** Terminal names
(`fromTerminal`/`toTerminal`) are received by the message model but never
written anywhere — not into metadata as a stand-in identity, not
anywhere else. Metadata is used only for what it's already established
for (`v2WireId`/`label`/`wireColor`, §4/§8) — never invented as a
pretend port mechanism.

## 4. Wire Identity Mapping

Unchanged principle, re-confirmed: V2 wire ids (`wire-<timestamp>` for
user-created, authored strings for base-vehicle wires) are established
(not discovered) at creation time and persisted as
`EngineeringRelationship.metadata['v2WireId']` — the same durable,
metadata-backed mechanism `AP-DIAGRAM-V2-BRIDGE-003` established for
document identity/module mapping. `LegacyV2StateAdapter._v2ToOepRelationshipId`
remains a rebuildable in-memory index over that metadata, not a second
source of truth — unchanged, confirmed still true by re-reading
`initializeFromDocument`.

## 5. Creation Authority

Sequence unchanged from the predecessor task, re-verified: V2 creates →
poll detects → adapter resolves both V2 module ids to OEP node ids (both
required) → `createRelationship` → `updateRelationshipMetadata` → adapter
re-reads the actual stored relationship (never assumes the request was
accepted verbatim) → `confirmWireCreated` sends the *authoritative*
label/color back to V2.

## 6. Selection Authority — **NEW, IMPLEMENTED**

V2's `selW` (the selected wire *object*, `app.js` scope, confirmed by
direct read of `js/ui/inspector.js`) is polled (V2 has no selection-
changed event, same rationale as every other poll-based detection in
this bridge) and diffed by id. A change fires `wireSelectionChanged`;
the adapter mirrors it into OEP's own `GraphSelection` via
`selectRelationship`/`deselectAll` — **no second selection system was
created**. If the selected V2 wire has no OEP mapping (touches an
unbridged module), OEP's selection is left exactly as it was — "V2
selected something OEP doesn't represent" is not the same as "V2
selected nothing," so it is not translated into a spurious deselect.

## 7. Deletion Authority — **NEW, IMPLEMENTED**

V2's `deleteSelectedWire` (native `confirm()`, then `WIRES` filtered,
`wireRoutes` entry removed — confirmed unchanged by re-reading
`wire-editor.js`) is detected the same way module deletion already is
(poll-diff against the previous `WIRES` id snapshot). The adapter calls
the existing `DeleteRelationshipCommand` via the new
`DiagramStudioController.deleteRelationship` wrapper. The id mapping is
**deliberately kept**, not removed, exactly like module deletion — so
undo can still resolve it. OEP's command-stack undo is what's
authoritative for reverting a delete; no second undo system exists.

## 8. Metadata Handling

Unchanged — `label`/`wireColor` are supplied by V2 at creation time and
bridged via the already-established `metadata['label']`/`['wireColor']`
keys. This task added exactly one new metadata key,
`metadata['v2WireId']` (§4), following the same pattern
AP-DIAGRAM-V2-BRIDGE-003 already established for modules
(`v2ModuleId`/`v2Category`) — no new metadata system, no fabricated
values.

## 9. Route Handling

**Not touched, per this task's own explicit prohibition.** Creation
still produces whatever route V2's own auto-router renders (i.e. none
stored in OEP — `SetWireRouteCommand` is never called by any code this
task added). Deletion needs no route handling. No shadow routing model,
no `OrthogonalRoutingProvider`/`DiagramLayoutState` change.

## 10. Persistence

Wire metadata (`v2WireId`/`label`/`wireColor`) round-trips through
`EngineeringRelationship.toJson`/`fromJson` exactly as node metadata
already does (confirmed unchanged this task) — the same
`DiagramDocument.save`/`open` mechanism `AP-DIAGRAM-V2-BRIDGE-003`
verified for modules now equally covers wires, without new code: 
`initializeFromDocument`'s existing relationship-scanning loop (already
present before this task) already seeds `_v2ToOepRelationshipId` from
metadata on load/reload/document-switch — this task's new deletion/
selection handlers don't change that seeding path at all. Not
separately live-tested this task via an actual save/reload cycle
specifically exercising a *deleted-then-undone* wire — flagged as a test
gap, not a design gap (the underlying mechanism is the same one already
verified for wire creation and for modules).

## 11. Undo Behavior

Deletion undo verified by test: `commands.undo()` reverts
`DeleteRelationshipCommand`, restoring the relationship; the adapter's
`resyncLastBridgedToV2` (extended this task, not replaced) then calls
`restoreWire` (idempotent — no-ops if V2 already has the wire) to bring
it back into V2's own `WIRES`. Creation-undo behavior (including the
"two real commands, two real undos" semantics already documented in the
predecessor task) is unchanged. V2 itself still has no undo system of
its own — unchanged, not built.

## 12. Failure Handling

- A wire whose endpoint module has no OEP mapping: recorded in
  `unbridgedV2WireIds`, no relationship created, no crash, no fabricated
  entity — unchanged from the predecessor task.
- Deletion for a v2WireId with no mapping (e.g. already unbridged, or
  never bridged): silently ignored (nothing to delete against) —
  matches the same "no mapping, no-op" pattern every other handler in
  this adapter already uses.
- Selection for an unmapped wire: OEP selection left unchanged (§6).

## 13. Remaining Gaps

- Terminal/port-level fidelity remains **ENGINE EXTENSION REQUIRED**
  (§3) — unaddressed, correctly deferred.
- Wire route/segment editing, reconnect — explicitly out of this task's
  scope, unaddressed.
- Wire property *editing after creation* (as opposed to creation-time
  setting) — not bridged; V2's own `saveWireProps` modal is not
  detected by any poller this bridge runs.
- A live save→reload→verify-relationship-survives cycle specifically for
  a wire (as opposed to a module) was not separately performed this
  task — see §10.

## 14. Exact Classification Summary

| Operation | Classification |
|---|---|
| Wire creation (node-to-node) | **ADAPTER REQUIRED** (implemented, re-confirmed) |
| Wire creation (terminal/port-precise) | **ENGINE EXTENSION REQUIRED** (not implemented, not attempted) |
| Wire selection (node-to-node relationship selection) | **ADAPTER REQUIRED** (implemented this task) |
| Wire deletion | **ADAPTER REQUIRED** (implemented this task, uses existing `DeleteRelationshipCommand`) |
| Wire metadata (label/color) | **DIRECT** (existing established metadata keys, unchanged) |
| Wire route/route editing | **OPEN** (explicitly deferred, not attempted) |
| Wire property editing (post-creation), label | **ADAPTER REQUIRED** (implemented AP-DIAGRAM-V2-BRIDGE-005) |
| Wire property editing (post-creation), color | **ADAPTER REQUIRED** for V2→OEP; **OPEN** for the reverse hex/code representation gap (§21, AP-DIAGRAM-V2-BRIDGE-005) |

---

# AP-DIAGRAM-V2-BRIDGE-005 — Wire Property Editing Bridge

## 15. V2 Wire Property-Edit Lifecycle

Read directly from current source this task (`js/editor/wire-editor.js`):
`editWireProps()` opens the `wpm` modal for `selW` (the currently
selected wire *object*, not an id — same global BRIDGE-004 already
established for selection), pre-filling `wpm-color`/`wpm-label`/
`wpm-desc` from `w.c`/`w.lbl`/`w.desc`. Mutation is **deferred until
Save**: `saveWireProps()` sets `w.c`/`w.lbl`/`w.desc` directly on the
same wire object already in `WIRES` (no id change, no array
replacement), then calls `drawWires()`/`updatePanel(w)`. **Blank input
never clears a value** — `w.c = $('wpm-color').value.trim() || w.c` and
the equivalent for `w.lbl` both fall back to the previous value when the
field is left empty, so V2 structurally cannot produce an empty label or
color from this modal. `desc` and the per-state `R` electrical-reading
table are also editable here but are out of this task's scope (not
label/color — the only two properties this bridge's existing metadata
keys represent) and are not touched.

V2 does not autosave this to disk (unchanged finding, §10) — only its
own in-memory `WIRES` array is mutated; persistence is still the
existing OEP `DiagramDocument.save()` path, §19.

## 16. OEP Property Model — Confirmed Unchanged

`UpdateRelationshipPropertiesCommand` (read directly this task) has no
validation of its own — `apply()` merges the given patch into
`relationship.metadata`, removing a key when its value is `null`. No
Engine change was needed or made. `DiagramStudioController
.updateRelationshipMetadata()` (existing) is the only entry point used.

## 17. Wire Identity — Unchanged

Uses the existing `v2WireId` ↔ `EngineeringRelationship.id` mapping
(§4) — no new identity mechanism.

## 18. Transport Extension

`LegacyV2BridgeTransport` gained exactly one new inbound message,
`wirePropertiesChanged { id, label, color }`, using V2's own field
names verbatim (`w.lbl`→`label`, `w.c`→`color`) — not the placeholder
shape sketched in the task prompt, which the actual `saveWireProps()`
source didn't match on inspection (no `v2WireId` key name, no
transformation of either field). Detection is poll-based, like every
other V2 event this bridge observes (V2 raises no "properties saved"
event): a per-wire `{lbl, c}` snapshot (`lastWireProps`) is diffed each
400ms tick, since — unlike creation/deletion — a property edit doesn't
change which ids are present in `WIRES`, only the fields on an existing
entry. `syncedWireProps` (same loop-prevention pattern as
`syncedModuleProps`) suppresses re-emitting an event for a value this
bridge itself just wrote. **No new outbound message was added** — the
authoritative sync-back reuses the existing `confirmWireCreated(v2WireId,
label, color)` call verbatim (identical shape), rather than building a
second wire-property push mechanism.

## 19. Adapter — `_handleWirePropertiesChanged`

Resolves `v2WireId` → relationship id (no-op, no crash, if unmapped) →
skips if the incoming values already match current metadata (avoids a
no-op undo-stack entry) → `controller.updateRelationshipMetadata(id,
{'label': ..., 'wireColor': ...})` → re-reads the relationship
Engine actually stored (never assumes the request was accepted verbatim,
per this task's Phase 7) → confirms the authoritative values back to V2
via `confirmWireCreated`. Persistence is the pre-existing
`DiagramDocument.save`/`open` path over `metadata['label']`/
`['wireColor']` — no second save path, `project-saver.js` untouched.

**Blank-value handling**: since V2's `saveWireProps()` cannot produce a
blank `lbl`/`c` (§15), this handler never constructs a `null` patch
value — the native Flutter editor's empty-means-remove-the-key
convention (`engineering_relationship_properties.dart`) simply doesn't
apply to bridge-originated edits; it remains exactly as it was for the
native editor's own use.

## 20. Undo

Reuses the existing OEP command stack (`updateRelationshipMetadata` is
itself an undoable command). `_resyncLastBridgedWire()` (the existing
single-entry resync dispatcher, §11) was extended: previously, its
"relationship still exists" branch only called `restoreWire`, which
**no-ops in V2 when the wire is already present** (its own injected
guard) — correct for delete-undo (where V2 doesn't have the wire yet)
but silently did nothing for a property-edit undo (where V2 already has
the wire, just with the stale label/color). It now also calls
`confirmWireCreated` with the restored authoritative values, which is
what actually applies to an existing wire. Verified by test: editing a
wire's label and color, then a further no-op resend, then
`commands.undo()`, confirms the color reverts to its pre-edit value and
`resyncLastBridgedToV2()` pushes that reverted value back to V2's own
`w.c`/`w.lbl`.

## 21. Wire Color — Representation Gap (documented, not fabricated around)

**Finding**: V2's own wire color is a short automotive wire-color CODE
string (`js/utils/colors.js`'s `WIRE_HEX` table keys, e.g. `"R"`,
`"G"`, `"Bl/Y"`, `"W"`) — never hex, never a CSS name. V2's own renderer
(`Colors.wireHex(code)`) resolves a code through that table with a
generic-gray fallback for anything unrecognized; it has **no
understanding of a raw hex string** as input.

The **existing, separate** native Flutter wire-property editor
(`engineering_relationship_properties.dart`, unmodified by this or any
prior wire-bridge task) enforces strict `#RRGGBB`/`#AARRGGBB` hex for
the same `metadata['wireColor']` key (`v2_wire_painter.dart`'s
`isValidWireHexColor`). That validation lives in the Flutter *widget*
layer, not in `UpdateRelationshipPropertiesCommand` itself (§16), so it
does not block this bridge from writing a V2 code string into the same
key — and this bridge does exactly that, for the same reason wire
**creation** already writes V2's raw `color` field into
`metadata['wireColor']` unconverted (§8, unchanged by this task): it is
continuing an existing, already-shipped representation, not introducing
a new one.

A code→hex conversion (mirroring V2's own `WIRE_HEX` table) was
considered and **rejected** for the sync-back direction: writing the
converted hex into V2's own `w.c` would not render correctly in V2 (its
renderer only understands its own code vocabulary), so "fixing" the
representation for OEP's benefit would break V2's own display — the
sync-back direction. Sync-back therefore continues writing V2's own
code string unchanged, which is correct for V2 but does not close the
loop with the native editor's hex-only expectation.

**Net result — classified explicitly, not silently resolved**:
`metadata['wireColor']` today has two legitimate but differently-shaped
producers: the V2 bridge (a wire-color code string) and the native
Flutter editor (strict hex). Editing the same wire's color from both
surfaces is not interchangeable — a value written by one is not
guaranteed to display correctly if read by the other's own validation/
rendering assumptions. This is an **OPEN, cross-producer representation
gap**, not a bug introduced by this task and not something this task
fabricates a resolution for (no invented code-name vocabulary, no
hex-to-code guessing table). Closing it for real would require either
constraining V2's own color input to hex (a V2 source change, out of
scope) or making the native editor V2-code-aware (a native-renderer
change, also out of this task's scope, § Phase 12/13's explicit
boundaries).

## 22. Failure Handling

- Unmapped `v2WireId` (never bridged, or unbridged endpoint): no-op, no
  crash — same pattern every other handler in this adapter uses.
- Values matching current metadata: no-op, no spurious undo-stack entry.
- Engine/Controller layer performs no rejection of either field (§16) —
  there is no "V2 asked for X, OEP normalized to Y" case to reflect back
  for label or color; whatever is stored is what's echoed to V2.

## 23. Persistence — Verified, No New Mechanism

`metadata['label']`/`['wireColor']` already round-trip through
`EngineeringRelationship.toJson`/`fromJson` and `DiagramDocument.save`/
`open` (§10) — a property edit is just another write to the same keys
wire creation already uses, so no new persistence path was needed or
added. Covered by the existing full-suite test run (`flutter test
test/diagram_studio/`), not separately re-verified via a live save→
reload cycle this task, consistent with §10's own test-gap note.

## 24. Remaining Gaps (this task)

- §21's wire-color representation gap — explicitly open, not resolved.
- Wire route/segment editing, reconnect, terminal-level fidelity: still
  untouched, per Phase 12/13's explicit boundaries.
- `desc` and the per-state `R` electrical-reading table (also editable
  in the same `wpm` modal) are not bridged — out of this task's declared
  scope (label/color only).
