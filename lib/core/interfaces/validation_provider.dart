import '../graph/models/engineering_graph.dart';
import '../validation/validation_report.dart';

/// Deterministic graph validation (SDD-025/026). Never mutates [graph].
abstract class ValidationProvider {
  ValidationReport validate(EngineeringGraph graph);
}
