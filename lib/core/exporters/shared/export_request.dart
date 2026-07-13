import '../../graph/models/engineering_graph.dart';

/// Input to an [ExportProvider] (SDD-025/026). Export never modifies
/// Engineering Knowledge — [graph] is read-only for the duration of export.
class ExportRequest {
  final String formatId;
  final EngineeringGraph graph;
  final String? destinationPath;
  final Map<String, Object?> options;

  const ExportRequest({
    required this.formatId,
    required this.graph,
    this.destinationPath,
    this.options = const {},
  });
}
