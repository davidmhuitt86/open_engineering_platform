# Layer System

WORK_PACKAGE_023, ENGINE-TASK-000101: "Implement Layout Layers... Layers
belong to Diagram Layout. Engineering Graph remains layer-independent."

---

## `DiagramLayer`

```dart
class DiagramLayer {
  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final bool printVisible;
  final int order;
}
```

A layer is pure drafting/organization metadata — SDD-024 lists Layer
explicitly as example Visual Layout data, alongside Position and
Rotation. Removing every layer in a graph never loses engineering
knowledge, only visual organization: the Engineering Graph has no concept
of layers at all.

## Where layers live

`DiagramLayoutState` (the same sibling-of-the-graph container that
already holds node positions, WP021's `positions` map) gained two more
maps this work package:

- `Map<String, DiagramLayer> layers` — the layer definitions themselves.
- `Map<String, String> layerAssignments` — entity id (a node id **or** an
  annotation id, see `docs/ANNOTATION_SYSTEM.md`) → layer id.

Accessors: `layerById`, `withLayer`, `withoutLayer` (removes the layer
**and** unassigns every member — they fall back to "no layer," never left
pointing at a dangling id), `layerOf(entityId)`, `entitiesOnLayer(layerId)`,
`withLayerAssignment(entityId, layerId?)` (`null` unassigns).

## Commands

All four follow the established capture-previous/apply/revert shape:

- `CreateLayerCommand(layer)`
- `DeleteLayerCommand(layerId)` — captures both the layer definition
  *and* every entity assignment it carried (`withoutLayer` unassigns as a
  side effect), so revert restores the layer and exactly which
  nodes/annotations were on it, not just the layer's own fields.
- `UpdateLayerCommand(layerId, {name?, visible?, locked?, printVisible?,
  order?})` — patch-style, the same shape `UpdateNodePropertiesCommand`
  already uses.
- `AssignLayerCommand(entityId, layerId?)` — assign or (`null`) unassign.

## Rendering: visibility is a View concern, not a new subsystem

`DiagramView.render` excludes a node from the produced `DiagramScene`
when its assigned layer's `visible` is `false`:

```dart
bool isNodeVisible(String nodeId) {
  final layerId = layout?.layerOf(nodeId);
  if (layerId == null) return true;
  return layout?.layerById(layerId)?.visible ?? true;
}
```

This is the View doing exactly what it has always done — deciding what
to draw from layout data it already reads — not a new filtering
mechanism bolted on afterward.

## Layer lock is advisory, not enforced by commands

`DiagramLayer.locked` is **not** checked inside `MoveNodesCommand` or any
other command. Locking a layer is a host-level UX gate: the
Demonstration Host is expected to consult `layout.layerOf(nodeId)` /
`layer.locked` *before* issuing a move (e.g. disabling the drag, or
declining to start it), exactly the same "advisory constraint" pattern
`docs/EDITING_CONSTRAINTS.md` uses for Connection Protection. This keeps
every `EditingCommand.apply` a pure, unconditional function of its
`EditingSession` input — no command needs to know `ViewState`/layer lock
exists at all.

## Selection integration

"Select by Layer" (`docs/ADVANCED_SELECTION` section of
`docs/ARCHITECTURE_DECISIONS.md` ADR-014-adjacent work — see
`SelectionProvider.selectByLayer`) reads `layout.entitiesOnLayer(layerId)`
and splits the result into node/annotation selections.

## Verification

`test/editing/layer_commands_test.dart`: create/delete (with member
unassignment + restore)/update (all fields + revert)/assign (including
unassign + revert), plus a `DiagramView` test confirming a node on a
hidden layer is excluded from the rendered scene.
