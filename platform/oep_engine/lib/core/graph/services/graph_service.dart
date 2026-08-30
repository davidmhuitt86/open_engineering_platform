import '../../events/engine_event.dart';
import '../../events/engine_event_bus.dart';
import '../../interfaces/graph_provider.dart';
import '../../interfaces/validation_provider.dart';
import '../../shared/ids.dart';
import '../../validation/validation_report.dart';
import '../algorithms/graph_query.dart';
import '../models/engineering_graph.dart';
import '../models/engineering_node.dart';
import '../models/engineering_relationship.dart';

/// Public Engineering Graph service (SDD-026 `GraphService`):
/// create/open/close/save/load/query/update/validate.
///
/// Delegates storage to a [GraphProvider] and validation to a
/// [ValidationProvider] — both resolved by `EngineeringEngine` through the
/// [EngineRegistry] and injected here. `GraphService` itself holds no
/// storage; it is the orchestration/event layer above the provider.
class GraphService {
  final GraphProvider _provider;
  final ValidationProvider _validation;
  final EngineEventBus _events;

  GraphService({
    required GraphProvider provider,
    required ValidationProvider validation,
    required EngineEventBus events,
  })  : _provider = provider,
        _validation = validation,
        _events = events;

  Future<EngineeringGraph> create({String? id}) => _provider.createGraph(id: id);

  Future<EngineeringGraph?> open(String id) => _provider.openGraph(id);

  Future<void> close(String id) => _provider.closeGraph(id);

  Future<void> save(EngineeringGraph graph) => _provider.saveGraph(graph);

  Future<EngineeringGraph?> load(String id) => _provider.loadGraph(id);

  EngineeringGraph? current(String id) => _provider.currentGraph(id);

  GraphQuery query(EngineeringGraph graph) => GraphQuery(graph);

  ValidationReport validate(EngineeringGraph graph) => _validation.validate(graph);

  Future<EngineeringGraph> addNode(
    EngineeringGraph graph,
    EngineeringNode node,
  ) async {
    final updated = await _provider.updateGraph(graph.withNode(node));
    _events.emit(EngineEvent(
      kind: EngineEventKind.graphChanged,
      graphId: graph.id,
      subjectId: node.id,
      payload: const {'operation': 'addNode'},
    ));
    return updated;
  }

  Future<EngineeringGraph> removeNode(
    EngineeringGraph graph,
    String nodeId,
  ) async {
    final updated = await _provider.updateGraph(graph.withoutNode(nodeId));
    _events.emit(EngineEvent(
      kind: EngineEventKind.graphChanged,
      graphId: graph.id,
      subjectId: nodeId,
      payload: const {'operation': 'removeNode'},
    ));
    return updated;
  }

  Future<EngineeringGraph> addRelationship(
    EngineeringGraph graph,
    EngineeringRelationship relationship,
  ) async {
    final updated = await _provider.updateGraph(graph.withRelationship(relationship));
    _events.emit(EngineEvent(
      kind: EngineEventKind.relationshipAdded,
      graphId: graph.id,
      subjectId: relationship.id,
    ));
    return updated;
  }

  Future<EngineeringGraph> removeRelationship(
    EngineeringGraph graph,
    String relationshipId,
  ) async {
    final updated =
        await _provider.updateGraph(graph.withoutRelationship(relationshipId));
    _events.emit(EngineEvent(
      kind: EngineEventKind.graphChanged,
      graphId: graph.id,
      subjectId: relationshipId,
      payload: const {'operation': 'removeRelationship'},
    ));
    return updated;
  }

  /// Merges [metadata] into [graph]'s existing metadata bag and persists
  /// the result (AP-OEP-FOUNDATION-BRIDGE-003 — the smallest existing
  /// path for retaining a value, such as
  /// [EngineeringGraph.diagramRepositoryIdMetadataKey], across whatever
  /// [GraphProvider] this service is backed by). Mirrors [addNode]'s own
  /// update-then-emit shape; existing keys not present in [metadata] are
  /// left untouched.
  Future<EngineeringGraph> updateMetadata(
    EngineeringGraph graph,
    Map<String, Object?> metadata,
  ) async {
    final updated = await _provider.updateGraph(
      graph.copyWith(metadata: {...graph.metadata, ...metadata}),
    );
    _events.emit(EngineEvent(
      kind: EngineEventKind.graphChanged,
      graphId: graph.id,
      subjectId: graph.id,
      payload: const {'operation': 'updateMetadata'},
    ));
    return updated;
  }

  String generateId(String prefix) => EngineIds.generate(prefix);
}
