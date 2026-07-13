import '../graph/models/engineering_graph.dart';

/// Backing store/mutator for the Engineering Graph (SDD-026 `GraphService`:
/// create/open/close/save/load/query/update/validate).
///
/// `EngineeringEngine` never talks to a concrete graph store directly — it
/// resolves a `GraphProvider` through the [EngineRegistry]. Phase 1 ships
/// `InMemoryGraphProvider`; a future Foundation-backed provider implements
/// the same contract without callers changing.
abstract class GraphProvider {
  Future<EngineeringGraph> createGraph({String? id});

  Future<EngineeringGraph?> openGraph(String id);

  Future<void> closeGraph(String id);

  /// Persists [graph] via whatever `SerializationProvider` this provider is
  /// configured with. Repository-independent — SDD-025 allows Temporary
  /// Engineering Graphs to exist before Repository Commit.
  Future<void> saveGraph(EngineeringGraph graph);

  Future<EngineeringGraph?> loadGraph(String id);

  /// Synchronous read of a currently-open graph, if any.
  EngineeringGraph? currentGraph(String id);

  /// Replaces the in-memory copy of an open graph (used after an edit).
  Future<EngineeringGraph> updateGraph(EngineeringGraph graph);

  List<String> get openGraphIds;
}
