import '../../interfaces/routing_provider.dart';
import 'diagram_geometry.dart';
import 'rect2d.dart';
import 'routing_context.dart';
import 'routing_request.dart';

/// Default [RoutingProvider] (ENGINE-TASK-000086, extended in
/// WORK_PACKAGE_022 ENGINE-TASK-000094): horizontal/vertical segments
/// only, meeting at 90° corners, with lane allocation via [RoutingContext]
/// so parallel wires don't overlap. Concept inspired by (not copied from)
/// the reference implementation's wire router — `EKE_ALGORITHMS.md` #3 —
/// reimplemented from scratch in Dart.
///
/// **Corner cleanup**: a direct 2-point line is used whenever source and
/// target already share a row *or* a column — WP021 only shortcut the
/// horizontal case. **Shared trunks**: when [RoutingRequest.trunkKey] is
/// given, every request sharing that key routes through the same trunk
/// column via [RoutingContext.allocateTrunkColumn], instead of each
/// getting an independently-offset lane — fewer crossings when several
/// relationships share a source.
///
/// **Obstacle-avoiding exits** (user-requested: "never have a wire cross
/// over a component"): when [RoutingRequest.sourceExitDirection] and
/// [RoutingRequest.targetExitDirection] are both given, this provider
/// exits each port perpendicular to its own node (down from a top-row
/// component, up from a bottom-row one, etc. — never diagonally across
/// the node's own body), then runs the straight leg between those two
/// exit stubs through a lane that clears every *other* node's bounding
/// box in [RoutingContext.obstacles], sweeping the lane further out
/// (still in the same, port-mandated direction) past any component that
/// would otherwise sit in its path. Requests that omit direction info
/// keep this provider's original column-jog behavior exactly, so
/// existing callers are unaffected.
///
/// **Known scope boundary**: the sweep only ever extends the middle
/// leg further out (down/up/left/right, whichever the ports mandate) —
/// it does not detour sideways around an obstacle that sits directly in
/// a port's own exit column (same x as a vertical exit, or same y as a
/// horizontal one), since no amount of extending that straight stub can
/// avoid something squarely inside it. That specific arrangement is rare
/// in this app's two-row wiring-harness diagrams (it requires a third
/// component stacked directly between two connected ones in the same
/// column); the common case — a wire jogging between rows past whatever
/// components sit between its two endpoints — is fully handled.
///
/// **Determinism** (WORK_PACKAGE_022, ENGINE-TASK-000094): this function
/// is a pure computation over its inputs — no wall-clock, no randomness,
/// no static mutable state outside the caller-supplied [RoutingContext].
/// Given the same request sequence and context, output is always
/// identical; `DiagramView` guarantees the request sequence itself is
/// deterministic by sorting relationships by id before routing.
///
/// Connection preservation and automatic reroute fall out for free:
/// relationships reference node ids (immune to moves), and
/// `DiagramView.render` recomputes routes from current state on every
/// call.
class OrthogonalRoutingProvider implements RoutingProvider {
  @override
  final String id = 'orthogonal';

  @override
  final String displayName = 'Orthogonal';

  /// How far a wire travels straight out from a port, perpendicular to
  /// its node's edge, before it's allowed to jog sideways — kept well
  /// clear of the 12x12 port marker/card border so the stub reads as a
  /// deliberate lead-out rather than clipping the card corner.
  static const double _exitStub = 14;

  /// Extra breathing room kept between a routed wire and any component
  /// bounding box it sweeps past.
  static const double _clearance = 8;

  @override
  List<Point2D> route(RoutingRequest request, RoutingContext context) {
    final sourceDir = request.sourceExitDirection;
    final targetDir = request.targetExitDirection;
    if (sourceDir != null && targetDir != null) {
      return _routeWithExitDirections(request, context, sourceDir, targetDir);
    }

    final source = request.source;
    final target = request.target;

    final sameRow = (source.dy - target.dy).abs() < 0.5;
    final sameColumn = (source.dx - target.dx).abs() < 0.5;
    if (sameRow || sameColumn) {
      return [source, target];
    }

    final preferredColumn = (source.dx + target.dx) / 2;
    final column = request.trunkKey == null
        ? context.allocateColumn(preferredColumn)
        : context.allocateTrunkColumn(request.trunkKey!, preferredColumn);

    return [
      source,
      Point2D(column, source.dy),
      Point2D(column, target.dy),
      target,
    ];
  }

  List<Point2D> _routeWithExitDirections(
    RoutingRequest request,
    RoutingContext context,
    String sourceDir,
    String targetDir,
  ) {
    final source = request.source;
    final target = request.target;
    final obstacles = context.obstaclesExcluding({request.sourceNodeId, request.targetNodeId});

    final sourceVertical = sourceDir == 'up' || sourceDir == 'down';
    final targetVertical = targetDir == 'up' || targetDir == 'down';

    if (sourceVertical && targetVertical) {
      final relevant = _obstaclesInXRange(obstacles, _span(source.dx, target.dx));
      final laneY = _resolveLane(
        sourceAxis: source.dy,
        targetAxis: target.dy,
        sourceSign: _sign(sourceDir),
        targetSign: _sign(targetDir),
        relevant: relevant.map((r) => (start: r.top, end: r.bottom)).toList(),
      );
      return _dedupe([
        source,
        Point2D(source.dx, laneY),
        Point2D(target.dx, laneY),
        target,
      ]);
    }

    if (!sourceVertical && !targetVertical) {
      final relevant = _obstaclesInYRange(obstacles, _span(source.dy, target.dy));
      final laneX = _resolveLane(
        sourceAxis: source.dx,
        targetAxis: target.dx,
        sourceSign: _sign(sourceDir),
        targetSign: _sign(targetDir),
        relevant: relevant.map((r) => (start: r.left, end: r.right)).toList(),
      );
      return _dedupe([
        source,
        Point2D(laneX, source.dy),
        Point2D(laneX, target.dy),
        target,
      ]);
    }

    // Mixed exits (one vertical, one horizontal) -- a straight L between
    // each port's own exit stub. Less common in this app's two-row
    // wiring-harness diagrams than the matched-axis cases above, so this
    // stays a plain corner rather than a full obstacle sweep.
    final sourceStub = _offset(source, sourceDir, _exitStub);
    final targetStub = _offset(target, targetDir, _exitStub);
    final corner = sourceVertical
        ? Point2D(sourceStub.dx, targetStub.dy)
        : Point2D(targetStub.dx, sourceStub.dy);
    return _dedupe([source, sourceStub, corner, targetStub, target]);
  }

  double _sign(String direction) => switch (direction) {
        'down' || 'right' => 1.0,
        'up' || 'left' => -1.0,
        _ => 0.0,
      };

  Point2D _offset(Point2D point, String direction, double distance) => switch (direction) {
        'up' => Point2D(point.dx, point.dy - distance),
        'down' => Point2D(point.dx, point.dy + distance),
        'left' => Point2D(point.dx - distance, point.dy),
        'right' => Point2D(point.dx + distance, point.dy),
        _ => point,
      };

  (double, double) _span(double a, double b) => a <= b ? (a, b) : (b, a);

  List<Rect2D> _obstaclesInXRange(List<Rect2D> obstacles, (double, double) span) {
    final (start, end) = span;
    return obstacles
        .where((o) => o.right >= start - _clearance && o.left <= end + _clearance)
        .toList();
  }

  List<Rect2D> _obstaclesInYRange(List<Rect2D> obstacles, (double, double) span) {
    final (start, end) = span;
    return obstacles
        .where((o) => o.bottom >= start - _clearance && o.top <= end + _clearance)
        .toList();
  }

  /// Picks the coordinate (Y for a vertical pair of exits, X for a
  /// horizontal pair) the wire's straight middle leg travels along,
  /// starting just past each port's own exit stub and sweeping further
  /// out — always in the direction the ports themselves mandate — past
  /// any obstacle whose span would otherwise sit across that leg. When
  /// both ports exit "outward" toward each other (the common case: a
  /// top-row port exits down, a bottom-row port exits up), the lane is
  /// pinned between the two exit stubs, so it never needs to double
  /// back through either node.
  double _resolveLane({
    required double sourceAxis,
    required double targetAxis,
    required double sourceSign,
    required double targetSign,
    required List<({double start, double end})> relevant,
  }) {
    var lowerBound = double.negativeInfinity;
    var upperBound = double.infinity;

    void applyBound(double axis, double sign) {
      final constraint = axis + sign * _exitStub;
      if (sign > 0 && constraint > lowerBound) lowerBound = constraint;
      if (sign < 0 && constraint < upperBound) upperBound = constraint;
    }

    applyBound(sourceAxis, sourceSign);
    applyBound(targetAxis, targetSign);

    double candidate;
    final hasLower = lowerBound.isFinite;
    final hasUpper = upperBound.isFinite;
    if (hasLower && hasUpper) {
      candidate = lowerBound <= upperBound ? (lowerBound + upperBound) / 2 : lowerBound;
    } else if (hasLower) {
      candidate = lowerBound;
    } else if (hasUpper) {
      candidate = upperBound;
    } else {
      candidate = (sourceAxis + targetAxis) / 2;
    }

    // Sweep away from any obstacle whose span straddles the candidate,
    // preferring the direction the ports allow (outward), bounded so a
    // pathological number of stacked obstacles can't loop forever.
    final sweepDown = lowerBound.isFinite || (!hasLower && !hasUpper && targetAxis >= sourceAxis);
    var guard = 0;
    while (guard <= relevant.length) {
      guard++;
      final blocking = relevant.where((r) => candidate >= r.start - _clearance && candidate <= r.end + _clearance);
      if (blocking.isEmpty) break;
      final r = blocking.first;
      // The `+ 1` clears the boundary strictly (not just `<=`), so the
      // very next iteration's blocking check doesn't immediately
      // re-trigger on the same obstacle at the exact edge of clearance.
      if (sweepDown) {
        final next = r.end + _clearance + 1;
        if (hasUpper && next > upperBound) {
          candidate = upperBound;
          break;
        }
        candidate = next;
      } else {
        final next = r.start - _clearance - 1;
        if (hasLower && next < lowerBound) {
          candidate = lowerBound;
          break;
        }
        candidate = next;
      }
    }
    return candidate;
  }

  List<Point2D> _dedupe(List<Point2D> points) {
    final result = <Point2D>[];
    for (final point in points) {
      if (result.isEmpty || result.last != point) result.add(point);
    }
    return result;
  }
}
