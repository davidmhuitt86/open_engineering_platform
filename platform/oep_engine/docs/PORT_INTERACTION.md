# Port Interaction

WORK_PACKAGE_022, ENGINE-TASK-000092/000093: hover/highlight/drag-to-port
interaction, and drag-to-connect/reconnect built on top of it. Both stay
strictly View-layer — `EngineeringRelationship` (SDD-027) is unchanged.

---

## `PortReference` — View-layer identity, not graph data

```dart
class PortReference {
  final String nodeId;
  final String portId;
}
```

A plain value identifying "this port, on this node," used purely for
hover/selection/drag targeting in the Diagram View. It is explicitly
**not** added to `EngineeringRelationship` — SDD-027 stays exactly as
frozen. This is consistent with `docs/ROUTING_ENGINE.md`'s existing
documented scoping decision (from WORK_PACKAGE_021): relationships
reference *nodes*, not named ports, and giving them named-port references
would be an SDD-027 object-model amendment requiring its own architectural
review, not something to smuggle in as a side effect of adding hover
interaction.

## Hover vs. selection — two different systems, on purpose

- **Hover** (`ViewState.hoveredPort`, a `PortReference?`) — ephemeral,
  mouse-position-driven, lives on `ViewState` (see `docs/VIEW_STATE.md`)
  exactly like every other transient view concern. Sits outside the
  command system and outside `GraphSelection`.
- **Selection** (`FocusState.port`, WORK_PACKAGE_021, unchanged) —
  continues to carry which port is the current *focus* target (e.g. for
  the Property/Evidence Inspector), independent of hover and independent
  of the multi-select `GraphSelection`.

Keeping these separate means a user can hover a different port than the
one currently focused (e.g. previewing a connection target while
inspecting an unrelated port) without either state clobbering the other —
the same reasoning that already keeps `GraphSelection` and `FocusState`
apart (`docs/SELECTION_MODEL.md`).

## Drag-to-connect / drag-to-reconnect: no new command types

WORK_PACKAGE_022 explicitly reuses the **existing** WORK_PACKAGE_021
commands — `CreateRelationshipCommand` and `ReconnectRelationshipCommand`
— for connection editing. Dragging from a port to another node's port is
UI/gesture-layer sequencing (accumulate a live pointer path in the
Demonstration Host, resolve the drop target, then commit one of those two
commands); it is not a new kind of engineering edit, so it does not need a
new `EditingCommand` subclass. This keeps the command taxonomy exactly as
narrow as the actual set of distinct graph mutations, per
`docs/UNDO_REDO.md`'s design.

## `ConnectionValidator` — exactly two rules

```dart
class ConnectionValidator {
  static bool canConnect(EngineeringGraph graph, String sourceNodeId, String targetNodeId);
}
```

A pure function, no side effects, used to drive live valid/invalid
preview-line feedback *before* a connect/reconnect drag is committed:

1. **No self-loops** — `sourceNodeId == targetNodeId` is rejected.
2. **No duplicate relationships** — rejected if any existing relationship
   already connects the same two nodes, checked in **either** direction
   (`a→b` blocks a new `b→a` request too), since a duplicate wire between
   the same two components is a duplicate regardless of which end is
   "source" in the data model.

Deliberately exactly these two rules and no more — WORK_PACKAGE_022 does
not ask `ConnectionValidator` to enforce category-specific electrical
rules (that belongs to `ValidationService`/SDD-030's rule architecture,
a separate, richer system that runs after the fact, not a live drag-gate).

## Verification

`test/graph/connection_validator_test.dart`: rejects self-loops, rejects
duplicates in either direction, allows a genuinely new connection between
two previously-unconnected nodes.
