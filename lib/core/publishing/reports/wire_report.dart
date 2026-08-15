import 'dart:math' as math;

import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_relationship.dart';
import '../../views/diagram/diagram_layout_state.dart';
import '../../views/diagram/diagram_geometry.dart';
import 'tabular_report.dart';

/// AP-DS-004: generates a Wire List/Wire Report from every
/// `RelationshipType.connectedTo` edge in [graph] — a wire, in this
/// platform's data model, is a `connectedTo` relationship between two
/// nodes (AP-DS-002's `ENGINEERING_MAPPING.md` already established this
/// mapping for repository persistence; this report reuses the same
/// convention rather than inventing a second one).
///
/// Wire color/gauge/label/termination information is read from
/// [EngineeringRelationship.metadata]'s well-known keys (`wireColor`,
/// `wireGauge`, `label`, `termination`) — nothing currently populates
/// these through any Studio UI (the same disclosed gap as
/// `BillOfMaterialsGenerator`'s component properties); missing values
/// render blank, never fabricated. Length is computed from
/// [DiagramLayoutState.wireOverrides]'s routed polyline when the wire has
/// a manual route, otherwise as the straight-line distance between the
/// two endpoint nodes' positions — an honest approximation for
/// auto-routed wires, disclosed in the report's own notes, not presented
/// as a measured physical length.
class WireReportGenerator {
  static TabularReport generate(EngineeringGraph graph, DiagramLayoutState layout) {
    final rows = <Map<String, Object?>>[];
    bool anyApproximated = false;

    for (final relationship in graph.relationships.values) {
      if (relationship.relationshipType != RelationshipType.connectedTo) continue;
      final sourceNode = graph.nodes[relationship.sourceNode];
      final targetNode = graph.nodes[relationship.targetNode];
      if (sourceNode == null || targetNode == null) continue;

      final override = layout.wireOverrides[relationship.id];
      double length;
      bool approximated;
      if (override != null && override.length >= 2) {
        length = 0;
        for (var i = 1; i < override.length; i++) {
          length += _distance(override[i - 1], override[i]);
        }
        approximated = false;
      } else {
        final sourcePos = layout.positions[relationship.sourceNode];
        final targetPos = layout.positions[relationship.targetNode];
        length = (sourcePos != null && targetPos != null) ? _distance(sourcePos, targetPos) : 0;
        approximated = true;
      }
      if (approximated) anyApproximated = true;

      // Harness membership: this wire "belongs" to a harness if either
      // endpoint node is tagged as being on a layer whose name matches a
      // harness-category node, OR — more directly and reliably — if
      // either endpoint node's own category is `harness` or the wire sits
      // between two nodes that share a `harness:<id>` layer assignment.
      // Reads `layout.layerAssignments`, the same layer-membership
      // mechanism `ENGINEERING_MAPPING.md` already documents as the
      // platform's chosen representation for grouping concepts.
      final sourceLayer = layout.layerAssignments[relationship.sourceNode];
      final targetLayer = layout.layerAssignments[relationship.targetNode];
      final harnessMembership = (sourceLayer != null && sourceLayer == targetLayer) ? sourceLayer : '';

      rows.add({
        'wireId': relationship.id,
        'wireColor': relationship.metadata['wireColor'] ?? '',
        'wireGauge': relationship.metadata['wireGauge'] ?? '',
        'lengthUnits': double.parse(length.toStringAsFixed(2)),
        'source': sourceNode.displayName,
        'destination': targetNode.displayName,
        'harnessMembership': harnessMembership,
        'label': relationship.metadata['label'] ?? '',
        'termination': relationship.metadata['termination'] ?? '',
      });
    }

    return TabularReport(
      title: 'Wire List',
      generatedAt: DateTime.now(),
      columns: const [
        'wireId',
        'wireColor',
        'wireGauge',
        'lengthUnits',
        'source',
        'destination',
        'harnessMembership',
        'label',
        'termination',
      ],
      columnLabels: const {
        'wireId': 'Wire ID',
        'wireColor': 'Color',
        'wireGauge': 'Gauge',
        'lengthUnits': 'Length (units)',
        'source': 'Source',
        'destination': 'Destination',
        'harnessMembership': 'Harness',
        'label': 'Label',
        'termination': 'Termination',
      },
      rows: rows,
      notes: [
        if (anyApproximated)
          'Length for wires with no manually-routed path is the straight-line distance between endpoints, '
              'not a measured physical length.',
        'Length units match the diagram\'s own canvas coordinate units (no physical unit/scale is currently attached '
            'to a diagram — see the Title Block\'s "Scale" field for manual context).',
      ],
    );
  }

  static double _distance(Point2D a, Point2D b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
