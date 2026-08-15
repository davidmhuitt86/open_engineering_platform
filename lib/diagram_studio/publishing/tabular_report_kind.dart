import 'package:engineering_engine/engineering_engine.dart';

/// AP-DS-004: the 6 tabular Engineering Deliverables this phase names
/// (Bill of Materials, Wire List/Report, Connector Report, Harness
/// Report, Relationship Report, Engineering Object Report), and the one
/// place that dispatches to each `oep_engine` generator — so the report
/// UI (`tabular_report_dialog.dart`) has one switch statement to build,
/// not six near-duplicate call sites.
enum TabularReportKind {
  billOfMaterials('Bill of Materials'),
  wireList('Wire List'),
  connectorReport('Connector Report'),
  harnessReport('Harness Report'),
  relationshipReport('Relationship Report'),
  engineeringObjectReport('Engineering Object Report');

  const TabularReportKind(this.label);

  final String label;

  /// [layout] is required for Wire List and Harness Report (their
  /// `oep_engine` generators need routed-wire geometry); other kinds
  /// ignore it. Passing `null` for those two throws — callers always
  /// have a `DiagramLayoutState` available (the open diagram's own),
  /// so this is a programmer-error guard, not a real runtime case.
  TabularReport generate(EngineeringGraph graph, DiagramLayoutState? layout) {
    switch (this) {
      case TabularReportKind.billOfMaterials:
        return BillOfMaterialsGenerator.generate(graph);
      case TabularReportKind.wireList:
        return WireReportGenerator.generate(graph, layout ?? DiagramLayoutState.empty);
      case TabularReportKind.connectorReport:
        return ConnectorReportGenerator.generate(graph);
      case TabularReportKind.harnessReport:
        return HarnessReportGenerator.generate(graph, layout ?? DiagramLayoutState.empty);
      case TabularReportKind.relationshipReport:
        return RelationshipReportGenerator.generate(graph);
      case TabularReportKind.engineeringObjectReport:
        return EngineeringObjectReportGenerator.generate(graph);
    }
  }
}
