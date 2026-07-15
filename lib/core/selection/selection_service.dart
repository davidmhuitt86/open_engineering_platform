import 'dart:async';

import '../events/engine_event.dart';
import '../events/engine_event_bus.dart';
import '../graph/algorithms/graph_query.dart';
import '../graph/models/engineering_graph.dart';
import '../graph/models/engineering_node.dart';
import '../interfaces/selection_provider.dart';
import '../views/diagram/diagram_geometry.dart';
import '../views/diagram/diagram_hit_testing.dart';
import '../views/diagram/diagram_layout_state.dart';
import '../views/diagram/diagram_scene.dart';
import '../views/diagram/rect2d.dart';
import 'focus_state.dart';
import 'graph_selection.dart';

/// Runtime multi-select selection state (SDD-026 `SelectionEngine`,
/// extended in WORK_PACKAGE_021 ENGINE-TASK-000080, and again in
/// WORK_PACKAGE_023 ENGINE-TASK-000098 with query-driven selection
/// modes).
///
/// Deliberately holds only *which* things are selected — never computes
/// highlight sets or paths. That responsibility belongs to
/// [NavigationService], mirroring the reference implementation's split
/// between its selection manager (state) and its path highlighter
/// (traversal-derived rendering hints).
class SelectionService implements SelectionProvider {
  final EngineEventBus _events;
  final StreamController<GraphSelection> _changes =
      StreamController<GraphSelection>.broadcast();
  final StreamController<FocusState> _focusChanges =
      StreamController<FocusState>.broadcast();

  GraphSelection _current = GraphSelection.empty;
  FocusState _focus = const FocusState.none();

  SelectionService({required EngineEventBus events}) : _events = events;

  @override
  GraphSelection get current => _current;

  @override
  Stream<GraphSelection> get changes => _changes.stream;

  @override
  FocusState get focus => _focus;

  @override
  Stream<FocusState> get focusChanges => _focusChanges.stream;

  void _setSelection(GraphSelection selection, {String? subjectId}) {
    _current = selection;
    _changes.add(selection);
    if (subjectId != null) {
      _events.emit(EngineEvent(
        kind: EngineEventKind.nodeSelected,
        subjectId: subjectId,
      ));
    }
  }

  void _setFocus(FocusState state, {EngineEventKind? emit, String? subjectId}) {
    _focus = state;
    _focusChanges.add(state);
    if (emit != null) {
      _events.emit(EngineEvent(kind: emit, subjectId: subjectId));
    }
  }

  @override
  void selectNode(String nodeId, {bool additive = false}) {
    _setSelection(
      additive
          ? GraphSelection(
              nodeIds: {..._current.nodeIds, nodeId},
              relationshipIds: _current.relationshipIds,
              groupIds: _current.groupIds,
              annotationIds: _current.annotationIds,
            )
          : GraphSelection(nodeIds: {nodeId}),
      subjectId: nodeId,
    );
  }

  @override
  void selectRelationship(String relationshipId, {bool additive = false}) {
    _setSelection(
      additive
          ? GraphSelection(
              nodeIds: _current.nodeIds,
              relationshipIds: {..._current.relationshipIds, relationshipId},
              groupIds: _current.groupIds,
              annotationIds: _current.annotationIds,
            )
          : GraphSelection(relationshipIds: {relationshipId}),
    );
  }

  @override
  void selectGroup(String groupId, {bool additive = false}) {
    _setSelection(
      additive
          ? GraphSelection(
              nodeIds: _current.nodeIds,
              relationshipIds: _current.relationshipIds,
              groupIds: {..._current.groupIds, groupId},
              annotationIds: _current.annotationIds,
            )
          : GraphSelection(groupIds: {groupId}),
    );
  }

  @override
  void selectAnnotation(String annotationId, {bool additive = false}) {
    _setSelection(
      additive
          ? GraphSelection(
              nodeIds: _current.nodeIds,
              relationshipIds: _current.relationshipIds,
              groupIds: _current.groupIds,
              annotationIds: {..._current.annotationIds, annotationId},
            )
          : GraphSelection(annotationIds: {annotationId}),
    );
  }

  @override
  void selectMany({
    Set<String> nodeIds = const {},
    Set<String> relationshipIds = const {},
    Set<String> groupIds = const {},
    Set<String> annotationIds = const {},
    bool additive = false,
  }) {
    _setSelection(
      additive
          ? GraphSelection(
              nodeIds: {..._current.nodeIds, ...nodeIds},
              relationshipIds: {..._current.relationshipIds, ...relationshipIds},
              groupIds: {..._current.groupIds, ...groupIds},
              annotationIds: {..._current.annotationIds, ...annotationIds},
            )
          : GraphSelection(
              nodeIds: nodeIds,
              relationshipIds: relationshipIds,
              groupIds: groupIds,
              annotationIds: annotationIds,
            ),
    );
  }

  @override
  void toggleNode(String nodeId) {
    final nodeIds = {..._current.nodeIds};
    if (!nodeIds.remove(nodeId)) nodeIds.add(nodeId);
    _setSelection(GraphSelection(
      nodeIds: nodeIds,
      relationshipIds: _current.relationshipIds,
      groupIds: _current.groupIds,
      annotationIds: _current.annotationIds,
    ));
  }

  @override
  void toggleRelationship(String relationshipId) {
    final relationshipIds = {..._current.relationshipIds};
    if (!relationshipIds.remove(relationshipId)) relationshipIds.add(relationshipId);
    _setSelection(GraphSelection(
      nodeIds: _current.nodeIds,
      relationshipIds: relationshipIds,
      groupIds: _current.groupIds,
      annotationIds: _current.annotationIds,
    ));
  }

  @override
  void toggleGroup(String groupId) {
    final groupIds = {..._current.groupIds};
    if (!groupIds.remove(groupId)) groupIds.add(groupId);
    _setSelection(GraphSelection(
      nodeIds: _current.nodeIds,
      relationshipIds: _current.relationshipIds,
      groupIds: groupIds,
      annotationIds: _current.annotationIds,
    ));
  }

  @override
  void toggleAnnotation(String annotationId) {
    final annotationIds = {..._current.annotationIds};
    if (!annotationIds.remove(annotationId)) annotationIds.add(annotationId);
    _setSelection(GraphSelection(
      nodeIds: _current.nodeIds,
      relationshipIds: _current.relationshipIds,
      groupIds: _current.groupIds,
      annotationIds: annotationIds,
    ));
  }

  @override
  void selectAll(EngineeringGraph graph, {DiagramLayoutState? layout}) {
    _setSelection(GraphSelection(
      nodeIds: graph.nodes.keys.toSet(),
      relationshipIds: graph.relationships.keys.toSet(),
      groupIds: graph.groups.keys.toSet(),
      annotationIds: layout?.annotations.keys.toSet() ?? const {},
    ));
  }

  @override
  void deselectAll() => _setSelection(GraphSelection.empty);

  @override
  void invertSelection(EngineeringGraph graph, DiagramLayoutState layout) {
    _setSelection(GraphSelection(
      nodeIds: graph.nodes.keys.toSet().difference(_current.nodeIds),
      relationshipIds:
          graph.relationships.keys.toSet().difference(_current.relationshipIds),
      groupIds: graph.groups.keys.toSet().difference(_current.groupIds),
      annotationIds: layout.annotations.keys.toSet().difference(_current.annotationIds),
    ));
  }

  @override
  void selectByLasso(DiagramScene scene, List<Point2D> polygon, {bool additive = false}) {
    selectMany(nodeIds: DiagramHitTesting.nodesInPolygon(scene, polygon), additive: additive);
  }

  @override
  void selectByRect(DiagramScene scene, Rect2D rect,
      {bool crossing = true, bool additive = false}) {
    final ids = crossing
        ? DiagramHitTesting.nodesInRect(scene, rect)
        : DiagramHitTesting.nodesFullyInRect(scene, rect);
    selectMany(nodeIds: ids, additive: additive);
  }

  @override
  void selectConnectedComponent(EngineeringGraph graph, String seedNodeId,
      {bool additive = false}) {
    selectMany(
      nodeIds: GraphQuery(graph).reachableFrom(seedNodeId),
      additive: additive,
    );
  }

  @override
  void selectSimilar(EngineeringGraph graph, EngineeringNode node, {bool additive = false}) {
    selectMany(
      nodeIds: GraphQuery(graph).similarTo(node).map((n) => n.id).toSet(),
      additive: additive,
    );
  }

  @override
  void selectByCategory(EngineeringGraph graph, NodeCategory category,
      {bool additive = false}) {
    selectMany(
      nodeIds: GraphQuery(graph).nodesByCategory(category).map((n) => n.id).toSet(),
      additive: additive,
    );
  }

  @override
  void selectByLayer(DiagramLayoutState layout, String layerId, {bool additive = false}) {
    final entityIds = layout.entitiesOnLayer(layerId);
    selectMany(
      nodeIds: entityIds.where((id) => !layout.annotations.containsKey(id)).toSet(),
      annotationIds: entityIds.where((id) => layout.annotations.containsKey(id)).toSet(),
      additive: additive,
    );
  }

  @override
  void focusPort(String nodeId, String portId) => _setFocus(FocusState.port(nodeId, portId));

  @override
  void focusSymbol(String symbolId) => _setFocus(FocusState.symbol(symbolId));

  @override
  void focusEvidence(String evidenceId) => _setFocus(
        FocusState.evidence(evidenceId),
        emit: EngineEventKind.evidenceSelected,
        subjectId: evidenceId,
      );

  @override
  void clearFocus() => _setFocus(const FocusState.none());

  Future<void> dispose() async {
    await _changes.close();
    await _focusChanges.close();
  }
}
