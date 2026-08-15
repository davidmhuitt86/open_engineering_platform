# Layout Persistence

WORK_PACKAGE_022, ENGINE-TASK-000089: named layout Save/Load/List/Delete
plus Reset, "via `JsonFileLayoutSerializer` following the
`SerializationProvider` pattern." Builds directly on WORK_PACKAGE_021's
`DiagramLayoutState`/`LayoutProvider` (see ARCHITECTURE_DECISIONS.md
ADR-011) — this work package does not change what layout *is*, only adds
durability and multiple named snapshots of it.

---

## Two layout concepts, per graph

Every graph id now has:

- **The current layout** — the live, actively-edited `DiagramLayoutState`,
  the same single mutable-via-commands layout WORK_PACKAGE_021 already had
  (`currentLayout(graphId)` / `updateLayout(graphId, layout)`).
- **Named layouts** — independent, explicitly-saved snapshots
  (`Map<String name, DiagramLayoutState>` per graph), which do **not**
  move when the current layout changes and are not part of undo/redo.

```dart
abstract class LayoutProvider {
  DiagramLayoutState currentLayout(String graphId);
  Future<void> updateLayout(String graphId, DiagramLayoutState layout);

  Future<void> saveNamedLayout(String graphId, String name, DiagramLayoutState layout);
  DiagramLayoutState? loadNamedLayout(String graphId, String name);
  List<String> listNamedLayouts(String graphId);
  Future<void> deleteNamedLayout(String graphId, String name);
  Future<void> resetLayout(String graphId);
}
```

`resetLayout` clears only the **current** layout (back to
`DiagramLayoutState.empty`, which falls back to the deterministic
auto-layout grid — see `docs/ROUTING_ENGINE.md`/`ROUTING_ARCHITECTURE.md`)
— it never touches saved named layouts. Loading a named layout is the
host's responsibility (`onLoad` callback in the Demonstration Host's
Named Layouts dialog copies the loaded snapshot into the current layout);
`LayoutProvider` itself doesn't conflate "load" with "make current" so a
future host could, for example, preview a named layout without committing
to it.

`InMemoryLayoutProvider` implements this with a
`Map<graphId, Map<layoutName, DiagramLayoutState>>` alongside its existing
current-layout map — named layouts are fully independent state, verified
by `test/views/layout_persistence_test.dart`.

## Serialization: a third parallel serializer, not a generic one

`JsonFileLayoutSerializer.write/read` mirrors
`JsonFileSerializationProvider` (graph, WORK_PACKAGE_019) field-for-field
in spirit — same "write to a path, read from a path" shape — but is a
deliberately separate class, not a shared generic interface. `Diagram
LayoutState.toJson()`/`fromJson()` (new this work package) serialize the
position map as `{nodeId: {dx, dy}}`.

**Why not one generic `SerializationProvider<T>`?** `SerializationProvider`
(ADR-004/WORK_PACKAGE_019) is already typed concretely to
`EngineeringGraph`. Genericizing it now would mean changing that
interface's signature — a bigger, riskier change to an existing frozen-
in-practice contract than this work package's scope justifies, for a
benefit (removing ~15 lines of duplicated write/read boilerplate across
three classes) that doesn't outweigh the risk. `JsonFileViewStateSerializer`
(see `docs/VIEW_STATE.md`) follows the identical reasoning — three
parallel, purpose-typed serializers rather than one generic one that would
require touching WORK_PACKAGE_019's interface.

## Verification

`test/views/layout_persistence_test.dart`: save/load/list/delete a named
layout, named layouts staying independent of the live current layout,
`resetLayout` clearing only the current layout, per-graph scoping, and
`JsonFileLayoutSerializer` round-tripping a `DiagramLayoutState` through a
real temp-directory file.
