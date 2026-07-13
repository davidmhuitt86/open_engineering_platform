import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/routing_context.dart';
import '../views/diagram/routing_request.dart';

/// Computes a wire's path between two anchor points (WORK_PACKAGE_021,
/// ENGINE-TASK-000086). Resolved through `EngineRegistry` like every
/// other capability (ADR-001/ADR-008) — this is the first provider WP021
/// explicitly requires to be Marketplace-replaceable: "the routing engine
/// shall remain replaceable. Future routing engines may register through
/// EngineRegistry."
///
/// **Determinism contract** (WORK_PACKAGE_022, ENGINE-TASK-000094): given
/// an identical Engineering Graph, Diagram Layout, and routing
/// configuration, a `RoutingProvider` implementation shall always produce
/// identical routing output. This applies to every implementation
/// registered through `EngineRegistry`, not just the default — no
/// wall-clock reads, no randomness, no hidden mutable state outside the
/// [RoutingContext] the caller supplies.
abstract class RoutingProvider {
  String get id;
  String get displayName;

  List<Point2D> route(RoutingRequest request, RoutingContext context);
}
