import '../../interfaces/routing_provider.dart';
import 'diagram_geometry.dart';
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

  @override
  List<Point2D> route(RoutingRequest request, RoutingContext context) {
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
}
