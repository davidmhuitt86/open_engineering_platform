import '../../graph/models/engineering_graph.dart';
import '../../views/diagram/diagram_layout_state.dart';
import 'tabular_report.dart';

/// AP-DS-004: generates a Harness Report, grouping nodes by their layer
/// assignment (this platform's chosen "harness membership" representation
/// — see `wire_report.dart`'s identical convention) rather than requiring
/// a separate harness data model.
class HarnessReportGenerator {
  static TabularReport generate(EngineeringGraph graph, DiagramLayoutState layout) {
    final rows = <Map<String, Object?>>[];
    for (final node in graph.nodes.values) {
      final layerId = layout.layerAssignments[node.id];
      if (layerId == null) continue;
      final layer = layout.layers[layerId];
      rows.add({
        'harness': layer?.name ?? layerId,
        'member': node.displayName,
        'category': node.category.name,
        'visible': layer?.visible ?? true,
        'locked': layer?.locked ?? false,
      });
    }
    return TabularReport(
      title: 'Harness Report',
      generatedAt: DateTime.now(),
      columns: const ['harness', 'member', 'category', 'visible', 'locked'],
      columnLabels: const {
        'harness': 'Harness/Layer',
        'member': 'Member',
        'category': 'Category',
        'visible': 'Visible',
        'locked': 'Locked',
      },
      rows: rows,
      notes: const ['"Harness" groups by the diagram\'s layer assignment — this platform has no separate harness data model.'],
    );
  }
}
