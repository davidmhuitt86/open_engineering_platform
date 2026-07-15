import '../graph/models/engineering_graph.dart';
import '../viewstate/grid_settings.dart';
import '../views/diagram/alignment_guide_computer.dart';
import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/grid_computer.dart';
import '../views/diagram/rect2d.dart';
import 'editing_constraints.dart';

/// Pure functions applying [EditingConstraints] (WORK_PACKAGE_023,
/// ENGINE-TASK-000103). Constraints are advisory: the Demonstration Host
/// calls these before issuing a `MoveNodesCommand`/`RotateNodesCommand`/
/// wire-editing call — no `EditingCommand` itself reads `ViewState` or
/// rejects anything, keeping every command a pure, unconditional
/// function of its `EditingSession` input, exactly as today.
class ConstraintMath {
  ConstraintMath._();

  /// "Orthogonal Movement": locks a drag to whichever axis (from [start])
  /// has the larger delta.
  static Point2D applyOrthogonalLock(Point2D start, Point2D candidate) {
    final dx = (candidate.dx - start.dx).abs();
    final dy = (candidate.dy - start.dy).abs();
    return dx >= dy ? Point2D(candidate.dx, start.dy) : Point2D(start.dx, candidate.dy);
  }

  /// "Axis Lock": locks a drag to exactly [axis].
  static Point2D lockToAxis(Point2D start, Point2D candidate, ConstraintAxis axis) {
    return axis == ConstraintAxis.x
        ? Point2D(candidate.dx, start.dy)
        : Point2D(start.dx, candidate.dy);
  }

  /// "Angle Constraint": rounds [degrees] to the nearest multiple of
  /// [incrementDegrees]. A non-positive increment leaves the angle
  /// unchanged.
  static double snapAngle(double degrees, double incrementDegrees) {
    if (incrementDegrees <= 0) return degrees;
    return (degrees / incrementDegrees).round() * incrementDegrees;
  }

  /// "Connection Protection": a pure, advisory predicate — `true` if
  /// [nodeId] has at least one relationship. The host consults this
  /// before a destructive action (e.g. to show a confirmation dialog);
  /// it is never enforced inside a command.
  static bool hasProtectedConnections(EngineeringGraph graph, String nodeId) {
    return graph.relationshipsForNode(nodeId).isNotEmpty;
  }

  /// "Snap Priority": resolves a drag candidate position by applying, in
  /// order, (1) axis lock or orthogonal movement, (2) alignment guides,
  /// (3) grid snap — encoding the priority as real, testable code instead
  /// of an unenforced convention.
  static Point2D resolveDragPosition({
    required Point2D start,
    required Point2D candidate,
    required EditingConstraints constraints,
    required double width,
    required double height,
    List<Rect2D> siblingBounds = const [],
    GridSettings? grid,
  }) {
    var resolved = candidate;

    final axisLock = constraints.axisLock;
    if (axisLock != null) {
      resolved = lockToAxis(start, resolved, axisLock);
    } else if (constraints.orthogonalMovement) {
      resolved = applyOrthogonalLock(start, resolved);
    }

    resolved = AlignmentGuideComputer.snapToGuides(
      candidatePosition: resolved,
      width: width,
      height: height,
      siblingBounds: siblingBounds,
    );

    if (grid != null) {
      resolved = GridComputer.snap(resolved, grid);
    }

    return resolved;
  }
}
