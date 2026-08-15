import '../../interfaces/graph_provider.dart';
import '../../interfaces/serialization_provider.dart';
import '../../shared/ids.dart';
import '../models/engineering_graph.dart';

/// Phase 1's [GraphProvider]: graphs live in memory for the life of the
/// engine; [saveGraph]/[loadGraph] delegate to a [SerializationProvider]
/// (local JSON) rather than a Repository, per SDD-025's allowance for
/// Repository-independent operation.
class InMemoryGraphProvider implements GraphProvider {
  final SerializationProvider serialization;
  final Map<String, EngineeringGraph> _open = {};

  InMemoryGraphProvider({required this.serialization});

  @override
  Future<EngineeringGraph> createGraph({String? id}) async {
    final graph = EngineeringGraph.empty(id ?? EngineIds.generate('graph'));
    _open[graph.id] = graph;
    return graph;
  }

  @override
  Future<EngineeringGraph?> openGraph(String id) async => _open[id];

  @override
  Future<void> closeGraph(String id) async {
    _open.remove(id);
  }

  @override
  Future<void> saveGraph(EngineeringGraph graph) async {
    _open[graph.id] = graph;
    await serialization.write(graph, _pathFor(graph.id));
  }

  @override
  Future<EngineeringGraph?> loadGraph(String id) async {
    final graph = await serialization.read(_pathFor(id));
    _open[graph.id] = graph;
    return graph;
  }

  @override
  EngineeringGraph? currentGraph(String id) => _open[id];

  @override
  Future<EngineeringGraph> updateGraph(EngineeringGraph graph) async {
    _open[graph.id] = graph;
    return graph;
  }

  @override
  List<String> get openGraphIds => _open.keys.toList(growable: false);

  String _pathFor(String id) => 'graphs/$id.json';
}
