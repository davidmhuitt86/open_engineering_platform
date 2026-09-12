import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/diagram_studio/webview/v2_terminal_port_bridge.dart';

/// AP-DIAGRAM-V2-BRIDGE-PORT-SUFFIX-001 — regression coverage for a real
/// bug found via the actual `diagram7.json` fixture running live: a
/// connector-type V2 module renders TWO dots per logical pin
/// (`"<pin>_IN"`/`"<pin>_OUT"`), and V2's own `restoreWire` needs that
/// exact suffixed reference to find the correct one. But
/// [normalizeV2RelationshipPortReferences] strips that suffix from
/// `sourcePort`/`targetPort` so the solver can match it against a plain
/// `Port.id` — silently destroying the very distinction V2's rendering
/// needed, with no error anywhere: `WIRES.length` still matched (the wire
/// object still existed), the module's terminal list was still fully
/// correct, but `route()` could never find the connector's `_IN` dot
/// under a `_OUT`-less bare pin number, so most wires touching any
/// connector never rendered — modules visible, wires missing, no
/// exception, no test failure, until traced live against the real app.
void main() {
  const connectorNode = EngineeringNode(
    id: 'conn',
    category: NodeCategory.component,
    displayName: 'Connector',
    ports: [Port(id: '1', name: '1'), Port(id: '2', name: '2'), Port(id: '3', name: '3')],
    metadata: {'v2Connector': true},
  );
  const otherNode = EngineeringNode(
    id: 'reg',
    category: NodeCategory.component,
    displayName: 'Regulator',
    ports: [Port(id: 'GND', name: 'GND')],
    metadata: {
      'v2Terminals': [
        {'n': 'GND', 'c': 'Bl'},
      ],
    },
  );

  test('a connector-pin reference with an _IN/_OUT suffix is stripped for sourcePort/targetPort '
      'but the original suffixed reference survives under v2RawSourcePort/v2RawTargetPort', () {
    const wire = EngineeringRelationship(
      id: 'w1',
      relationshipType: RelationshipType.connectedTo,
      sourceNode: 'reg',
      targetNode: 'conn',
      metadata: {'sourcePort': 'GND', 'targetPort': '1_IN'},
    );
    final graph = EngineeringGraph(
      id: 'g',
      nodes: const {'reg': otherNode, 'conn': connectorNode},
      relationships: const {'w1': wire},
    );

    final normalized = normalizeV2RelationshipPortReferences(graph);
    final result = normalized.relationships['w1']!;

    // Solver-facing: still the bare Port.id, unchanged behavior.
    expect(result.metadata['targetPort'], '1');
    // V2-rendering-facing: the original, un-normalized reference is
    // preserved so `LegacyV2StateAdapter` can still find the real dot.
    expect(result.metadata['v2RawTargetPort'], '1_IN');
    // `sourcePort` ("GND") already matched a real Port.id verbatim, so
    // nothing changed for it -- no raw key should be added.
    expect(result.metadata['v2RawSourcePort'], isNull);
  });

  test('an already-bare reference that needs no normalization gets no v2RawSourcePort/v2RawTargetPort key', () {
    const wire = EngineeringRelationship(
      id: 'w2',
      relationshipType: RelationshipType.connectedTo,
      sourceNode: 'conn',
      targetNode: 'reg',
      metadata: {'sourcePort': '2', 'targetPort': 'GND'},
    );
    final graph = EngineeringGraph(
      id: 'g',
      nodes: const {'reg': otherNode, 'conn': connectorNode},
      relationships: const {'w2': wire},
    );

    final normalized = normalizeV2RelationshipPortReferences(graph);
    final result = normalized.relationships['w2']!;

    expect(result.metadata['sourcePort'], '2');
    expect(result.metadata['targetPort'], 'GND');
    expect(result.metadata.containsKey('v2RawSourcePort'), isFalse);
    expect(result.metadata.containsKey('v2RawTargetPort'), isFalse);
  });
}
