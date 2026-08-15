# Selection Model

WORK_PACKAGE_021, ENGINE-TASK-000080. Replaces Phase 1's single-item
selection with a full multi-select model. Extended in WORK_PACKAGE_023,
ENGINE-TASK-000098 with annotation selection and query-driven selection
modes (Lasso/Crossing/Window/Connected-Component/Similar/Category/
Layer/Invert). See also `docs/EKE_INTERACTION_MODEL.md` for what the
reference implementation did (and didn't do) here.

---

## Two separate concepts

**`GraphSelection`** — the multi-select set of nodes/relationships/
groups/annotations that Delete/Move/Clipboard/Group operate on:

```dart
class GraphSelection {
  final Set<String> nodeIds;
  final Set<String> relationshipIds;
  final Set<String> groupIds;
  final Set<String> annotationIds; // WORK_PACKAGE_023
}
```

**`FocusState`** — a single inspection target (port/symbol/evidence) the
Property Inspector can show, but that Delete/Move/Clipboard never touch.
Kept deliberately separate: ports/symbols/evidence never needed
multi-select semantics, and conflating them with `GraphSelection` would
have made every editing operation have to reason about selection kinds it
can't actually act on.

Both are runtime-only (SDD-027: selection is Runtime Metadata, never
persisted) and both stay outside the undo/redo command system (see
`docs/UNDO_REDO.md`).

## `SelectionProvider` operations

| Capability | Method |
|---|---|
| Single Selection | `selectNode`/`selectRelationship`/`selectGroup` (replaces) |
| Multi Selection | any `select*` method with `additive: true`, or `selectMany` |
| Box Selection | `selectMany(nodeIds: ..., additive: ...)` fed by `DiagramHitTesting.nodesInRect` |
| Toggle Selection | `toggleNode`/`toggleRelationship`/`toggleGroup` |
| Select All | `selectAll(graph)` |
| Deselect All | `deselectAll()` |
| Selection Events | `changes` (`Stream<GraphSelection>`), `focusChanges` (`Stream<FocusState>`) |
| Selection Persistence | selection survives graph mutations by id — moving/renaming a selected node never clears its selection, since selection is keyed by id and ids are stable |

"Selection Priority" (resolving overlapping hits during box-select) is
left to the caller: `DiagramHitTesting.nodesInRect` reports geometric
membership only — which of several overlapping candidates to act on is a
Demonstration Host (or future Diagram Studio) UI decision, not a
`SelectionService` concern, since `SelectionService` never needs to know
about screen coordinates at all.

## Advanced selection modes (WORK_PACKAGE_023, ENGINE-TASK-000098)

Every mode below is the same shape as the existing `selectAll(graph)`:
a pure query (over `EngineeringGraph`, `DiagramLayoutState`, or a
`DiagramScene`) feeding `selectMany`. None of them touch the graph.

| Mode | Method | Query |
|---|---|---|
| Crossing Selection | `selectByRect(scene, rect, crossing: true)` | `DiagramHitTesting.nodesInRect` — any touch counts |
| Window Selection | `selectByRect(scene, rect, crossing: false)` | `DiagramHitTesting.nodesFullyInRect` — full containment required |
| Lasso Selection | `selectByLasso(scene, polygon)` | `DiagramHitTesting.nodesInPolygon` — ray-casting point-in-polygon on node center |
| Connected Component Selection | `selectConnectedComponent(graph, seedNodeId)` | `GraphQuery.reachableFrom` — already direction-agnostic, no new traversal needed |
| Select Similar | `selectSimilar(graph, node)` | `GraphQuery.similarTo` — same category, and same `symbolId` if the node has one; includes the origin node |
| Select by Category | `selectByCategory(graph, category)` | `GraphQuery.nodesByCategory` (pre-existing) |
| Select by Layer | `selectByLayer(layout, layerId)` | `layout.entitiesOnLayer(layerId)`, split into nodes vs. annotations |
| Invert Selection | `invertSelection(graph, layout)` | set difference against every node/relationship/group/annotation |

## Box selection hit-testing

Lives in the View layer (`lib/core/views/diagram/diagram_hit_testing.dart`),
not `SelectionService` — box selection needs `DiagramScene` node
positions, which `SelectionService` deliberately never sees. `Rect2D` is a
plain axis-aligned rectangle (not `dart:ui`'s `Rect`), keeping this module
usable without a Flutter binding, consistent with `Point2D`/
`DiagramScene` (SDD-025/026: no Flutter in engine core).

`DiagramHitTesting` also gained `relationshipAt(scene, point, {threshold})`
(WORK_PACKAGE_023) — a point-to-segment distance test that lets a host
select a relationship by clicking near its wire, which manual wire
editing (`docs/WIRE_EDITING.md`) requires to be reachable at all.

## Comparison to the reference implementation

The reference (`EKE_INTERACTION_MODEL.md`) never had multi-selection at
all — `selW`/`selM` were independent single-item globals, one wire and
one module selected at most, ever. This work package's `GraphSelection`
is new design, not a migration — there was no reference behavior to
preserve here beyond the single-select case, which `GraphSelection`
still supports as the `additive: false` (default) path.
