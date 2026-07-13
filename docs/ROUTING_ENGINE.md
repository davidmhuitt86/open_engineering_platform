# Routing Engine

WORK_PACKAGE_021, ENGINE-TASK-000086: "Implement the first routing
engine... The routing engine shall remain replaceable. Future routing
engines may register through EngineRegistry." This is the concrete
Marketplace-replaceable provider ADR-008 (WORK_PACKAGE_020) predicted the
architecture would support without changes — it does.

---

## `RoutingProvider`

```dart
abstract class RoutingProvider {
  String get id;
  String get displayName;
  List<Point2D> route(RoutingRequest request, RoutingContext context);
}
```

Registered in `EngineRegistry` exactly like every other capability
(ADR-001) — `registry.register<RoutingProvider>(OrthogonalRoutingProvider())`.
A future Marketplace package supplies an alternative (curved routing,
Manhattan routing with obstacle avoidance, a straight-line-only "schematic"
style) by registering its own `RoutingProvider` implementation — nothing
in `DiagramView`, `EngineRegistry`, or `EngineeringEngine` changes.

## `OrthogonalRoutingProvider` (the default)

Horizontal/vertical segments only, meeting at 90° corners. Given two
anchor points at different rows, it produces a 4-point
horizontal-vertical-horizontal path through a shared "corner column."
`RoutingContext` tracks which columns have already been used in the
current render pass and offsets repeated requests by a fixed lane spacing
(alternating left/right), so multiple parallel wires routed through
roughly the same region don't visually overlap. This is a fresh Dart
reimplementation — no code was migrated — of the *concept* documented in
`EKE_ALGORITHMS.md` #3 (the reference's `renderer.js` lane-allocation
router).

`RoutingContext` is created fresh per `DiagramView.render` call, so lane
allocation never leaks state between renders — every render recomputes
routing from the current graph/layout, which is also what makes
"automatic reroute" and "connection preservation" (ENGINE-TASK-000086)
free: relationships reference node ids, never coordinates, so a moved
node's wires simply route differently on the next render; nothing has to
explicitly "update" a stored path.

## Port snapping — a documented scoping decision

WORK_PACKAGE_021 asks for "port snapping." `EngineeringRelationship`
(SDD-027) references **nodes**, not specific ports — there is no
`sourcePort`/`targetPort` field, and adding one would be an object-model
change outside this work package's scope (and not covered by SDD-027A).

Given that constraint, `DiagramView` resolves each wire endpoint to the
**nearest port** on the node (by straight-line distance to the other
endpoint), using the node's `SymbolDefinition.ports` (via `SymbolProvider`)
if it has any, falling back to the node's center otherwise. This is
"port-aware" routing — wires visually connect to a port anchor rather
than a bare node center — but it is not true per-relationship named-port
binding. If a future work package wants that, it needs an SDD-027
amendment adding port references to `EngineeringRelationship`, reviewed
like any other object-model change.

## Verification

`test/views/routing_test.dart` covers: direct (no-corner) routing when
already horizontal, 4-point orthogonal routing with the correct corner
shape, and lane allocation producing distinct columns for repeated
requests at the same preferred position.
