import 'diagram_geometry.dart';

/// Input to [RoutingProvider.route] — one relationship's endpoints,
/// already resolved to port-or-node anchor points by [DiagramView].
///
/// [trunkKey] (WORK_PACKAGE_022, ENGINE-TASK-000094: "Shared Trunks") is
/// an optional grouping key — relationships sharing the same key (e.g.
/// their source node id) are routed through the same trunk column
/// instead of each getting an independently-offset lane, producing a
/// tidier harness-style look and fewer crossings.
class RoutingRequest {
  final String relationshipId;
  final Point2D source;
  final Point2D target;
  final String? trunkKey;

  const RoutingRequest({
    required this.relationshipId,
    required this.source,
    required this.target,
    this.trunkKey,
  });
}
