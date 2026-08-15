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

  /// The owning node of [source]/[target] -- lets [RoutingProvider]
  /// implementations exclude a wire's own endpoints from obstacle
  /// avoidance (an anchor point sits exactly on its own node's edge, so
  /// without this every route would treat its own source/target as
  /// something to route around). `null` is safe -- nothing is excluded.
  final String? sourceNodeId;
  final String? targetNodeId;

  /// Which edge of the owning node [source]/[target] sits on --
  /// `'up'`/`'down'`/`'left'`/`'right'`, or `null` if unknown. When both
  /// are given, [OrthogonalRoutingProvider] exits each port
  /// perpendicular to its node (never diagonally across the node's own
  /// body) and, for two vertical (or two horizontal) exits, routes the
  /// straight leg through a lane clear of every other node's bounding
  /// box -- the "never cross a component" routing the user asked for.
  /// `null` preserves this provider's original column-jog behavior
  /// exactly, so existing callers that never supply direction are
  /// unaffected.
  final String? sourceExitDirection;
  final String? targetExitDirection;

  const RoutingRequest({
    required this.relationshipId,
    required this.source,
    required this.target,
    this.trunkKey,
    this.sourceNodeId,
    this.targetNodeId,
    this.sourceExitDirection,
    this.targetExitDirection,
  });
}
