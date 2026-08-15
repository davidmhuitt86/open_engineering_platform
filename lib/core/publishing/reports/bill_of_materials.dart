import '../../graph/models/engineering_graph.dart';
import '../../graph/models/engineering_node.dart';
import 'tabular_report.dart';

/// AP-DS-004: generates a Bill of Materials directly from Engineering
/// Objects (the spec's own words) — never from a separate BOM data
/// source, since Engineering Objects are this platform's single source of
/// truth (CLAUDE.md's "Engineering Objects" principle).
///
/// Reads well-known keys from each [EngineeringNode.properties] —
/// `manufacturer`, `manufacturerPartNumber`, `supplier`, `quantity`,
/// `package` — which nothing currently populates through any Studio UI
/// (no property-inspector field exists for them yet, a real, disclosed
/// gap; see `docs/architecture/diagram_studio/` publishing documentation).
/// Missing values render as an empty string, never a fabricated
/// placeholder — a BOM with blank Manufacturer columns is an honest BOM;
/// one with invented values would not be.
class BillOfMaterialsGenerator {
  /// [componentCategoriesOnly] (default true) restricts the BOM to nodes
  /// whose category represents a physical, orderable part — Component,
  /// Connector, Relay, Fuse, Switch, Sensor, Actuator — excluding
  /// organizational/logical categories (Circuit, Harness, Module,
  /// Ground, MeasurementPoint, Procedure, Specification, Wire, Unknown)
  /// that a manufacturing BOM would not list as a line item. Pass false
  /// to include every node.
  static TabularReport generate(EngineeringGraph graph, {bool componentCategoriesOnly = true}) {
    const orderableCategories = {
      NodeCategory.component,
      NodeCategory.connector,
      NodeCategory.relay,
      NodeCategory.fuse,
      NodeCategory.switchNode,
      NodeCategory.sensor,
      NodeCategory.actuator,
    };

    final rows = <Map<String, Object?>>[];
    for (final node in graph.nodes.values) {
      if (componentCategoriesOnly && !orderableCategories.contains(node.category)) continue;
      rows.add({
        'referenceDesignator': node.properties['referenceDesignator'] ?? node.id,
        'description': node.displayName,
        'category': node.category.name,
        'manufacturer': node.properties['manufacturer'] ?? '',
        'manufacturerPartNumber': node.properties['manufacturerPartNumber'] ?? '',
        'supplier': node.properties['supplier'] ?? '',
        'quantity': node.properties['quantity'] ?? 1,
        'package': node.properties['package'] ?? '',
      });
    }

    return TabularReport(
      title: 'Bill of Materials',
      generatedAt: DateTime.now(),
      columns: const [
        'referenceDesignator',
        'description',
        'category',
        'manufacturer',
        'manufacturerPartNumber',
        'supplier',
        'quantity',
        'package',
      ],
      columnLabels: const {
        'referenceDesignator': 'Ref. Designator',
        'description': 'Description',
        'category': 'Category',
        'manufacturer': 'Manufacturer',
        'manufacturerPartNumber': 'Mfr. Part No.',
        'supplier': 'Supplier',
        'quantity': 'Qty',
        'package': 'Package',
      },
      rows: rows,
      notes: componentCategoriesOnly
          ? const ['Restricted to orderable-part categories (Component/Connector/Relay/Fuse/Switch/Sensor/Actuator).']
          : const [],
    );
  }
}
