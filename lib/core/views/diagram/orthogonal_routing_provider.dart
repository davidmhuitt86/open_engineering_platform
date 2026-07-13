import '../../interfaces/routing_provider.dart';
import 'diagram_geometry.dart';
import 'routing_context.dart';
import 'routing_request.dart';

/// Default [RoutingProvider] (ENGINE-TASK-000086): horizontal/vertical
/// segments only, meeting at 90° corners, with lane allocation via
/// [RoutingContext] so parallel wires don't overlap. Concept inspired by
/// (not copied from) the reference implementation's wire router —
/// `EKE_ALGORITHMS.md` #3 — reimplemented from scratch in Dart.
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

    if ((source.dy - target.dy).abs() < 0.5) {
      return [source, target];
    }

    final preferredColumn = (source.dx + target.dx) / 2;
    final column = context.allocateColumn(preferredColumn);

    return [
      source,
      Point2D(column, source.dy),
      Point2D(column, target.dy),
      target,
    ];
  }
}
