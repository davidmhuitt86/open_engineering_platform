import '../simulation/measurement/measurement_types.dart';

/// PRODUCT-READINESS-005, §5 — what a trace was asked to start from.
///
/// Reuses [ProbePoint] for the terminal case (§28: no duplicate id type).
/// A component-level or relationship-level target is normalized by
/// `TraceEngine` into a set of starting [ProbePoint]s before tracing
/// begins — "a component-level trace is effectively `trace(componentId)`
/// which expands to its terminals" (§5) — so the engine's actual traversal
/// logic only ever deals with terminals, never a separate code path per
/// target kind.
enum TraceTargetKind { component, terminal, relationship }

class TraceTarget {
  const TraceTarget._(this.kind, {this.componentId, this.terminal, this.relationshipId});

  final TraceTargetKind kind;
  final String? componentId;
  final ProbePoint? terminal;
  final String? relationshipId;

  factory TraceTarget.component(String componentId) =>
      TraceTarget._(TraceTargetKind.component, componentId: componentId);

  factory TraceTarget.terminal(ProbePoint terminal) =>
      TraceTarget._(TraceTargetKind.terminal, terminal: terminal);

  /// §5: "A future wire-level UI request should resolve the wire endpoints
  /// into the same trace model rather than create a separate tracing
  /// architecture" — `TraceEngine` resolves this into the relationship's
  /// own two endpoint terminals, the same normalization every other kind
  /// goes through.
  factory TraceTarget.relationship(String relationshipId) =>
      TraceTarget._(TraceTargetKind.relationship, relationshipId: relationshipId);

  @override
  String toString() {
    switch (kind) {
      case TraceTargetKind.component:
        return 'TraceTarget.component($componentId)';
      case TraceTargetKind.terminal:
        return 'TraceTarget.terminal($terminal)';
      case TraceTargetKind.relationship:
        return 'TraceTarget.relationship($relationshipId)';
    }
  }
}
