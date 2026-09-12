import '../simulation/measurement/measurement_types.dart';
import 'trace_path.dart';

/// PRODUCT-READINESS-010 §15/§45 — one node in a [CircuitBranchNode] tree:
/// merges every [TracePath.steps] sequence in a [TraceResult] into a
/// single shared tree wherever paths share a common prefix, so parallel
/// branches (e.g. a splice feeding two headlights) render as a real
/// branching structure rather than two independent, visually-unrelated
/// lists. This reorganizes ALREADY-COMPUTED [TracePathStep] sequences --
/// it discovers no new connectivity and performs no traversal of its own;
/// [TraceEngine] remains the sole authority for what is or is not
/// connected/conducting.
class CircuitBranchNode {
  const CircuitBranchNode({
    required this.terminal,
    required this.viaRelationshipId,
    required this.isInternalBridge,
    required this.children,
    this.isBlockingStep = false,
  });

  final ProbePoint terminal;
  final String? viaRelationshipId;
  final bool isInternalBridge;
  final List<CircuitBranchNode> children;

  /// True when this exact step is the [TracePath.blockingStep] of at
  /// least one path that passes through it (§16/§34 — surfaced so the UI
  /// can mark exactly where a branch stops, never merely "no path").
  final bool isBlockingStep;
}

/// PRODUCT-READINESS-010 §15 — builds a [CircuitBranchNode] forest (one
/// root per distinct starting terminal) from [paths], merging shared
/// prefixes. Deterministic: children are always in first-seen order
/// (which, since [TraceResult.paths] is itself deterministically ordered
/// by `pathId`, makes the tree itself deterministic — §25/§27 of
/// PRODUCT-READINESS-009's own trace ordering discipline carries over
/// unchanged here).
List<CircuitBranchNode> buildCircuitBranchTree(List<TracePath> paths) {
  final roots = <_MutableBranchNode>[];

  for (final path in paths) {
    var siblings = roots;
    _MutableBranchNode? current;
    for (final step in path.steps) {
      current = siblings.firstWhere(
        (n) => n.terminal == step.terminal && n.viaRelationshipId == step.viaRelationshipId,
        orElse: () {
          final created = _MutableBranchNode(
            terminal: step.terminal,
            viaRelationshipId: step.viaRelationshipId,
            isInternalBridge: step.isInternalBridge,
          );
          siblings.add(created);
          return created;
        },
      );
      siblings = current.children;
    }
    final blockingStep = path.blockingStep;
    if (blockingStep != null && current != null && current.terminal == blockingStep.terminal) {
      current.isBlockingStep = true;
    }
  }

  return roots.map((n) => n.freeze()).toList();
}

class _MutableBranchNode {
  _MutableBranchNode({required this.terminal, required this.viaRelationshipId, required this.isInternalBridge});

  final ProbePoint terminal;
  final String? viaRelationshipId;
  final bool isInternalBridge;
  final List<_MutableBranchNode> children = [];
  bool isBlockingStep = false;

  CircuitBranchNode freeze() => CircuitBranchNode(
        terminal: terminal,
        viaRelationshipId: viaRelationshipId,
        isInternalBridge: isInternalBridge,
        isBlockingStep: isBlockingStep,
        children: children.map((c) => c.freeze()).toList(),
      );
}
