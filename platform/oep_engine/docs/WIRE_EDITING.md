# Wire Editing

WORK_PACKAGE_023, ENGINE-TASK-000099: "Extend the RoutingProvider...
Insert Vertex, Remove Vertex, Drag Segment, Drag Corner, Preserve
Orthogonality, Automatic Corner Cleanup, Manual Route Override, Restore
Automatic Routing... Routing remains deterministic. Manual routing edits
shall remain undoable."

---

## One storage mechanism, one command

`DiagramLayoutState.wireOverrides: Map<String, List<Point2D>>` is a
sibling of `positions` — a manual point-list override for a
relationship's wire, keyed by relationship id. `DiagramView.render`
checks it first:

```dart
final points = layout?.wireOverrideOf(relationship.id) ??
    (routing == null ? [sourceAnchor, targetAnchor] : routing.route(...));
```

When no override exists, the deterministic `RoutingProvider` path is
completely untouched — this is a pure bypass, never a modification of
what the router itself computes (ADR-016's determinism guarantee for
auto-routed relationships is unaffected).

Every wire edit — Insert Vertex, Remove Vertex, Drag Segment, Drag
Corner, Manual Route Override — reduces to the same operation: compute a
new point list, then commit it with **one** command,
`SetWireRouteCommand(relationshipId, points)`. `points == null` means
"Restore Automatic Routing" (clears the override). There is deliberately
no separate `EditingCommand` subclass per gesture — the underlying
mutation is identical in every case.

## `WireEditing` — the pure geometry

`lib/core/views/diagram/wire_editing.dart` provides `insertVertex`,
`removeVertex`, `dragSegment`, `dragCorner`, and `cleanupCorners` — all
pure functions over `List<Point2D>`, with no engine state and no
Flutter. The Demonstration Host calls these to compute a candidate point
list, then commits it via `SetWireRouteCommand`.

### The one rule that makes "Preserve Orthogonality" well-defined

`points.first`/`points.last` are the wire's port anchors and are **never
moved** by `dragSegment` or `dragCorner`. Dragging a segment or corner
that touches an anchor inserts a new intermediate vertex instead, so the
anchor stays exactly where the port is:

- **`dragSegment`**: shifts a segment's two endpoints by the perpendicular
  component of the drag delta (a horizontal segment only moves in y, a
  vertical one only in x — this alone keeps neighboring segments
  orthogonal, since a proper orthogonal path always alternates
  horizontal/vertical, and an unmoved neighbor's *shared* coordinate with
  the dragged endpoint never changes). If either endpoint is an anchor,
  that endpoint is left untouched and a new connector vertex is inserted
  next to it — which also correctly handles a 2-point wire (both ends
  anchors): both anchors stay put, two new vertices bracket the newly
  offset middle segment.
- **`dragCorner`**: moves an interior vertex, propagating the shared
  coordinate to each immediate neighbor exactly one hop (always
  sufficient given the alternating-orthogonal invariant — a neighbor's
  *other* segment depends on its *other* coordinate, which this never
  touches). A neighbor that is itself a fixed anchor clamps the shared
  coordinate instead of moving — the corner can only slide along that
  anchor's segment axis. Anchors themselves are never draggable this way.
- **`insertVertex`/`removeVertex`** are simpler structural primitives —
  insert doesn't itself enforce orthogonality of the two new segments
  (the caller is expected to pass an axis-aligned point, e.g. a segment
  midpoint); remove never touches an anchor and never drops below 2
  points.
- **`cleanupCorners`** ("Automatic Corner Cleanup") removes interior
  vertices that don't actually change direction — three consecutive
  points collinear on the same axis — which repeated edits can produce.

`dragSegment`/`dragCorner` both take a `minimumWireLength` parameter
(sourced from `EditingConstraints`, see `docs/EDITING_CONSTRAINTS.md`)
and reject a drag outright (returning the input unchanged) if it would
collapse any segment shorter than that.

## Selecting a wire in the first place

Manual wire editing requires a relationship to be selected, which
requires a way to select one by clicking it — `DiagramHitTesting`
gained `relationshipAt(scene, point, {threshold})`, a point-to-segment
distance test across every wire, so the Demonstration Host's background
tap handler can select a relationship instead of always deselecting.
Without this, "Edit Route" mode would have had no reachable entry point.

## Verification

`test/views/wire_editing_test.dart` covers all five functions: insert
(including out-of-range no-op), remove (including anchor/minimum-length
guards), drag-segment (interior segment, anchor-adjacent with connector
insertion, 2-point-wire bracketing, minimum-length rejection),
drag-corner (interior propagation, anchor-adjacent clamping, anchor
refusal), cleanup (removes redundant / keeps genuine corners), and a
determinism check (same input always produces the same output, and
inputs are never mutated in place). `test/views/routing_test.dart`
covers `relationshipAt`.
