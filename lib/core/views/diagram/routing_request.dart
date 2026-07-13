import 'diagram_geometry.dart';

/// Input to [RoutingProvider.route] — one relationship's endpoints,
/// already resolved to port-or-node anchor points by [DiagramView].
class RoutingRequest {
  final String relationshipId;
  final Point2D source;
  final Point2D target;

  const RoutingRequest({
    required this.relationshipId,
    required this.source,
    required this.target,
  });
}
