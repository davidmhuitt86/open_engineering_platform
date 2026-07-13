import '../../graph/models/engineering_graph.dart';

/// Outcome of an import operation (SDD-026: "Import produces Engineering
/// Knowledge").
class ImportResult {
  final bool success;
  final EngineeringGraph? graph;
  final List<String> warnings;
  final String? errorMessage;

  const ImportResult({
    required this.success,
    this.graph,
    this.warnings = const [],
    this.errorMessage,
  });

  factory ImportResult.ok(EngineeringGraph graph, {List<String> warnings = const []}) =>
      ImportResult(success: true, graph: graph, warnings: warnings);

  factory ImportResult.failure(String message) =>
      ImportResult(success: false, errorMessage: message);
}
