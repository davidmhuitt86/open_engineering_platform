# Grid System

WORK_PACKAGE_022, ENGINE-TASK-000090: "Professional Grid System." The
engine computes grid geometry and snap positions; the Demonstration Host
only paints whatever `GridComputer` tells it to.

---

## `GridSettings` (part of `ViewState`)

```dart
class GridSettings {
  final double spacing;     // default 20
  final int majorEvery;     // default 5 — every Nth line is a major line
  final bool visible;
  final bool snapEnabled;
}
```

Lives on `ViewState.grid` (see `docs/VIEW_STATE.md`) — grid configuration
is a view concern, not engineering knowledge or layout, so it's runtime
state, never a command, never persisted with the graph.

## `GridComputer` — pure, renderer-independent

```dart
class GridComputer {
  static List<GridLine> computeLines(GridSettings settings, Rect2D visibleBounds);
  static Point2D snap(Point2D point, GridSettings settings);
}
```

`computeLines` returns every horizontal/vertical `GridLine{axis, position,
isMajor}` that falls within `visibleBounds`, with every `majorEvery`-th
line (counted from the origin, not from the bounds' edge — so major lines
land on consistent absolute positions regardless of scroll/pan) flagged
`isMajor: true`. Non-positive `spacing` returns an empty list (no
division-by-zero, no infinite loop) rather than throwing — the
Demonstration Host's Grid Settings dialog clamps the spacing slider to
`[5, 100]` precisely so this edge case is a defensive floor, not a normal
path.

`snap` rounds a point to the nearest grid intersection when
`settings.snapEnabled`, otherwise returns the point unchanged — this is
the single implementation both the Demonstration Host's node-drag
snapping *and* any future host use, replacing WORK_PACKAGE_021's ad hoc,
fixed-size `snapToGrid(Point2D, double gridSize)` helper that lived in
the Demonstration Host's `geometry_utils.dart` (removed this work
package — superseded, not left as dead code).

## Why the engine computes geometry instead of the host

Two reasons this isn't Demonstration-Host-only logic: (1) grid math needs
to be identical wherever a diagram is ever painted — a future Studio
renderer must snap to and draw the *same* grid the Engineering Engine
host does, without reimplementing the majorEvery/spacing math itself; (2)
grid-snap and guide-snap are combined in the same drag cycle (see below),
so both have to be renderer-independent Dart, not `CustomPainter`-bound.

## Alignment & Guides (ENGINE-TASK-000091)

A closely related but architecturally distinct pair of features, covered
here rather than in a separate doc — see ARCHITECTURE_DECISIONS.md
ADR-017 for the full reasoning.

**Smart guides — ephemeral, never a command.**

```dart
class AlignmentGuideComputer {
  static List<AlignmentGuide> computeGuides({
    required Rect2D draggedBounds,
    required List<Rect2D> siblingBounds,
    double threshold = 4,
  });
  static Point2D snapToGuides({
    required Point2D candidatePosition,
    required double width,
    required double height,
    required List<Rect2D> siblingBounds,
    double threshold = 4,
  });
}
```

`computeGuides` compares the dragged node's left/center/right and top/
center/bottom edges against every sibling's, returning an
`AlignmentGuide{axis, position}` for each near-match within `threshold`
pixels — purely a *visual hint* recomputed every drag frame, never stored,
never a command, never part of undo/redo, exactly like `GridComputer`'s
grid lines. The Demonstration Host applies guide-snap first, then
grid-snap (`GridComputer.snap`), so a drag that's near both a sibling edge
and a grid line prefers the more specific guide.

**Align/Distribute — real, undoable layout mutations.**

```dart
enum AlignmentMode { left, right, top, bottom, center, middle }
enum DistributionAxis { horizontal, vertical }

class AlignNodesCommand extends EditingCommand {
  AlignNodesCommand(Set<String> nodeIds, AlignmentMode mode);
}

class DistributeNodesCommand extends EditingCommand {
  DistributeNodesCommand(Set<String> nodeIds, DistributionAxis axis);
}
```

Unlike guides, these are deliberate user actions (a toolbar/menu command,
not a drag side-effect) that permanently change `DiagramLayoutState` —
`left`/`right`/`top`/`bottom` align to the selection's bounding-box edge,
`center`/`middle` align to its horizontal/vertical center;
`DistributeNodesCommand` sorts the selection along the chosen axis, keeps
the first and last node fixed, and spaces the rest evenly between them
(a no-op below 3 nodes, same as `AlignNodesCommand` is a no-op below 2).
Both follow `MoveNodesCommand`'s existing capture-previous-positions/
apply/revert shape (`docs/UNDO_REDO.md`), so they're fully undoable — real
edits, not view state.

## Verification

`test/views/grid_computer_test.dart`: `computeLines` covers the visible
bounds at the configured spacing, marks every Nth line major, returns no
lines for non-positive spacing; `snap` rounds correctly when enabled and
is a no-op when disabled.

`test/views/alignment_guide_computer_test.dart`: finds a vertical guide
when left edges nearly align, finds no guides beyond the threshold, and
`snapToGuides` nudges a candidate position into exact alignment.

`test/editing/align_distribute_commands_test.dart`: `AlignNodesCommand`
(left/top/middle alignment, revert, no-op below 2 nodes) and
`DistributeNodesCommand` (even horizontal spacing keeping the ends fixed,
revert, no-op below 3 nodes).
