import '../graph/models/engineering_graph.dart';

/// Base contract for a View: a stateless, read-only visualization of the
/// Engineering Graph (SDD-024/025).
///
/// The Graph is the single canonical center of the architecture. A View
/// never mutates it and never becomes a second source of truth — it
/// derives a [TScene] description from the graph on demand. Diagram View
/// is the first of several planned Views (Harness, Diagnostic, Physical
/// Layout, Simulation, Print) — all siblings under `lib/core/views/`.
abstract class EngineeringView<TScene> {
  String get id;
  String get displayName;

  TScene render(EngineeringGraph graph);
}
