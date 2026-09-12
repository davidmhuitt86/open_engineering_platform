import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// PRODUCT-READINESS-010 §15 — [buildCircuitBranchTree] unit tests.
void main() {
  test('a single path becomes a single-child chain, root to leaf', () {
    final tree = buildCircuitBranchTree([
      const TracePath(
        pathId: 'p1',
        steps: [
          TracePathStep(terminal: ProbePoint(nodeId: 'battery')),
          TracePathStep(terminal: ProbePoint(nodeId: 'fuse'), viaRelationshipId: 'w1'),
          TracePathStep(terminal: ProbePoint(nodeId: 'ground'), viaRelationshipId: 'w2'),
        ],
        conductingState: ElectricalConductingState.conducting,
      ),
    ]);

    expect(tree, hasLength(1));
    expect(tree.single.terminal.nodeId, 'battery');
    expect(tree.single.children, hasLength(1));
    expect(tree.single.children.single.terminal.nodeId, 'fuse');
    expect(tree.single.children.single.children.single.terminal.nodeId, 'ground');
  });

  test('§15/§24 two paths sharing a common prefix merge into one shared trunk that then branches -- never collapsed into a single series path', () {
    // source -> splice -> {LH, RH}
    final lh = const TracePath(
      pathId: 'p-lh',
      steps: [
        TracePathStep(terminal: ProbePoint(nodeId: 'source')),
        TracePathStep(terminal: ProbePoint(nodeId: 'splice'), viaRelationshipId: 'wSplice'),
        TracePathStep(terminal: ProbePoint(nodeId: 'lh'), viaRelationshipId: 'wLh'),
      ],
      conductingState: ElectricalConductingState.conducting,
    );
    final rh = const TracePath(
      pathId: 'p-rh',
      steps: [
        TracePathStep(terminal: ProbePoint(nodeId: 'source')),
        TracePathStep(terminal: ProbePoint(nodeId: 'splice'), viaRelationshipId: 'wSplice'),
        TracePathStep(terminal: ProbePoint(nodeId: 'rh'), viaRelationshipId: 'wRh'),
      ],
      conductingState: ElectricalConductingState.conducting,
    );

    final tree = buildCircuitBranchTree([lh, rh]);

    expect(tree, hasLength(1), reason: 'a single shared root (source), not two independent trees');
    final source = tree.single;
    expect(source.children, hasLength(1), reason: 'the shared splice hop is merged, not duplicated');
    final splice = source.children.single;
    expect(splice.terminal.nodeId, 'splice');
    expect(splice.children, hasLength(2), reason: 'the splice genuinely branches into two children -- LH and RH, never one linear path');
    expect(splice.children.map((c) => c.terminal.nodeId).toSet(), {'lh', 'rh'});
  });

  test('§16/§34 the step a path was blocked at is marked isBlockingStep', () {
    const blockingStep = TracePathStep(terminal: ProbePoint(nodeId: 'switch'), viaRelationshipId: 'w1');
    final tree = buildCircuitBranchTree([
      const TracePath(
        pathId: 'p1',
        steps: [TracePathStep(terminal: ProbePoint(nodeId: 'battery')), blockingStep],
        conductingState: ElectricalConductingState.open,
        blockingStep: blockingStep,
        blockingReason: 'Switch open',
      ),
    ]);

    expect(tree.single.children.single.isBlockingStep, isTrue);
    expect(tree.single.isBlockingStep, isFalse);
  });

  test('two entirely disjoint paths (no shared prefix at all) produce two separate roots', () {
    final tree = buildCircuitBranchTree([
      const TracePath(pathId: 'p1', steps: [TracePathStep(terminal: ProbePoint(nodeId: 'a'))], conductingState: ElectricalConductingState.conducting),
      const TracePath(pathId: 'p2', steps: [TracePathStep(terminal: ProbePoint(nodeId: 'b'))], conductingState: ElectricalConductingState.conducting),
    ]);
    expect(tree, hasLength(2));
  });

  test('empty paths list produces an empty forest, never throws', () {
    expect(buildCircuitBranchTree(const []), isEmpty);
  });

  test('deterministic: repeated calls over the same paths produce structurally identical trees', () {
    final paths = [
      const TracePath(
        pathId: 'p-lh',
        steps: [TracePathStep(terminal: ProbePoint(nodeId: 'source')), TracePathStep(terminal: ProbePoint(nodeId: 'lh'), viaRelationshipId: 'w1')],
        conductingState: ElectricalConductingState.conducting,
      ),
      const TracePath(
        pathId: 'p-rh',
        steps: [TracePathStep(terminal: ProbePoint(nodeId: 'source')), TracePathStep(terminal: ProbePoint(nodeId: 'rh'), viaRelationshipId: 'w2')],
        conductingState: ElectricalConductingState.conducting,
      ),
    ];
    String describe(List<CircuitBranchNode> nodes) =>
        nodes.map((n) => '${n.terminal.nodeId}[${describe(n.children)}]').join(',');

    expect(describe(buildCircuitBranchTree(paths)), describe(buildCircuitBranchTree(paths)));
  });
}
