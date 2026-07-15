# Editing Constraints

WORK_PACKAGE_023, ENGINE-TASK-000103: "Implement configurable
constraints. Support: Orthogonal Movement, Axis Lock, Angle Constraint,
Snap Priority, Connection Protection, Minimum Wire Length, Minimum Bend
Radius (future-ready)... Constraints operate through existing Commands."

---

## Constraints are a `ViewState` value, not a new subsystem

`EditingConstraints` plays exactly the role `GridSettings` already
established in WORK_PACKAGE_022: a toggle-able editing-behavior
preference, living on `ViewState`, never Engineering Graph or Diagram
Layout data.

```dart
class EditingConstraints {
  final bool orthogonalMovement;
  final ConstraintAxis? axisLock;       // {x, y} — named ConstraintAxis to
                                         // avoid colliding with Flutter's Axis
  final double? angleConstraintDegrees;
  final double minimumWireLength;       // default 8
  final double? minimumBendRadius;      // future-ready, unused today
}
```

`ViewState.constraints` + `ViewStateProvider.setConstraints` /
`ViewStateService.setConstraints` follow the identical pattern
`setGridSettings` already uses.

### "Minimum Bend Radius (future-ready)"

Orthogonal routing has no curved bends, so no current `RoutingProvider`
reads this field — it exists purely so a future curved-routing provider
has a config slot to consume without another `ViewState`/
`EditingConstraints` change. This is what "future-ready" means here: a
reserved field, not a partially-implemented feature.

## `ConstraintMath` — the pure functions, and why commands don't know about them

```dart
class ConstraintMath {
  static Point2D applyOrthogonalLock(Point2D start, Point2D candidate);
  static Point2D lockToAxis(Point2D start, Point2D candidate, ConstraintAxis axis);
  static double snapAngle(double degrees, double incrementDegrees);
  static bool hasProtectedConnections(EngineeringGraph graph, String nodeId);
  static Point2D resolveDragPosition({
    required Point2D start,
    required Point2D candidate,
    required EditingConstraints constraints,
    required double width,
    required double height,
    List<Rect2D> siblingBounds = const [],
    GridSettings? grid,
  });
}
```

**Constraints are advisory** — the Demonstration Host calls these
functions *before* issuing a `MoveNodesCommand`/`RotateNodesCommand`/wire
edit, to compute the position it will actually submit. No
`EditingCommand` reads `ViewState`, checks a constraint, or rejects
anything internally. This keeps every command exactly what it has always
been: a pure, unconditional function of its `EditingSession` input. The
alternative — commands consulting `ViewState` to decide whether to
apply — would blur the "Command History owns Graph/Layout mutations,
ViewState is a separate runtime concern" boundary this whole work
package is built to preserve.

The same reasoning covers **Connection Protection**:
`hasProtectedConnections(graph, nodeId)` is a pure predicate (true if the
node has at least one relationship) the host consults before a
destructive action (e.g. to show a confirmation dialog) — it is never a
hard rejection inside `DeleteNodeCommand` itself.

**Layer lock** (`docs/LAYER_SYSTEM.md`) follows the identical advisory
pattern: the host checks `layout.layerOf(nodeId)`/`layer.locked` before
starting a drag, rather than `MoveNodesCommand` knowing layers exist.

## "Snap Priority" as real code

`resolveDragPosition` is the one function that turns "Snap Priority"
into an enforced order instead of a convention someone has to remember:

1. Axis Lock (if set) or Orthogonal Movement (if enabled) — applied
   first, so a locked axis always wins.
2. Alignment guides (`AlignmentGuideComputer.snapToGuides`,
   WORK_PACKAGE_022) — second.
3. Grid snap (`GridComputer.snap`, WORK_PACKAGE_022) — last, only if a
   `GridSettings` is supplied.

Each stage operates on the previous stage's output, so a locked axis
survives guide/grid snapping on the other axis untouched.

## Verification

`test/editing/constraint_math_test.dart`: `applyOrthogonalLock`/
`lockToAxis` pick the correct axis, `snapAngle` rounds correctly
(including the non-positive-increment no-op), `hasProtectedConnections`
distinguishes connected vs. isolated nodes, and `resolveDragPosition`
proves the priority order (axis lock beats grid snap on the locked axis,
grid snap still applies on the unlocked one; falls through to plain grid
snap with no constraints active).
