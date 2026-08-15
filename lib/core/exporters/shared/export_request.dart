import '../../graph/models/engineering_graph.dart';
import '../../views/diagram/diagram_layout_state.dart';

/// Input to an [ExportProvider] (SDD-025/026). Export never modifies
/// Engineering Knowledge — [graph] is read-only for the duration of export.
///
/// AP-DS-004: [layout] was added as its own field, not folded into
/// [options], deliberately. [options] is documented/used elsewhere as
/// "format-specific extras" (e.g. PNG dpi, PDF page format); layout is
/// core rendering input needed by every diagram-drawing exporter
/// (PDF/SVG/PNG) the same way [graph] is — modeling it as just another
/// entry in a loosely-typed `Map<String, Object?>` would hide a required
/// concept behind a stringly-typed lookup. This is purely additive
/// (nullable, defaults to null) so every existing caller (e.g.
/// [JsonExportProvider], which never used layout) is unaffected.
class ExportRequest {
  final String formatId;
  final EngineeringGraph graph;
  final DiagramLayoutState? layout;
  final String? destinationPath;
  final Map<String, Object?> options;

  const ExportRequest({
    required this.formatId,
    required this.graph,
    this.layout,
    this.destinationPath,
    this.options = const {},
  });
}
