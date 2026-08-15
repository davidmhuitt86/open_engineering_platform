import '../../graph/models/engineering_graph.dart';
import '../../interfaces/routing_provider.dart';
import '../../interfaces/symbol_provider.dart';
import '../../views/diagram/diagram_layout_state.dart';
import '../../views/diagram/diagram_scene.dart';
import '../../views/diagram/diagram_view.dart';

/// AP-DS-004: computes the [DiagramScene] a diagram exporter (PDF/SVG/PNG)
/// should draw, honoring [DiagramLayer.printVisible] on top of whatever
/// [DiagramView] already computes for on-screen rendering.
///
/// [DiagramView.render] already excludes nodes on a layer whose `visible`
/// flag is false (screen visibility). Export additionally needs
/// `printVisible`: a layer can be visible on-screen but excluded from
/// printed/exported output ("a layer marked not-print-visible must not
/// appear in exported output even if it's visible on-screen" — AP-DS-004).
/// This is a second, export-only filter pass over the already-rendered
/// scene, not a change to [DiagramView] itself, since screen rendering
/// must keep using `visible` alone.
DiagramScene computePrintScene(
  EngineeringGraph graph, {
  DiagramLayoutState? layout,
  SymbolProvider? symbols,
  RoutingProvider? routing,
}) {
  final scene = DiagramView().render(graph, layout: layout, symbols: symbols, routing: routing);
  if (layout == null) return scene;

  bool layerExcludesPrint(String? layerId) {
    if (layerId == null) return false;
    final layer = layout.layerById(layerId);
    return layer != null && !layer.printVisible;
  }

  final excludedNodeIds = <String>{
    for (final node in graph.nodes.values)
      if (layerExcludesPrint(layout.layerOf(node.id))) node.id,
  };

  final filteredNodes = scene.nodes.where((n) => !excludedNodeIds.contains(n.nodeId)).toList();

  final filteredWires = scene.wires.where((w) {
    if (layerExcludesPrint(layout.layerOf(w.relationshipId))) return false;
    final relationship = graph.relationships[w.relationshipId];
    if (relationship == null) return true;
    return !excludedNodeIds.contains(relationship.sourceNode) &&
        !excludedNodeIds.contains(relationship.targetNode);
  }).toList();

  return DiagramScene(
    nodes: filteredNodes,
    wires: filteredWires,
    contentWidth: scene.contentWidth,
    contentHeight: scene.contentHeight,
  );
}
