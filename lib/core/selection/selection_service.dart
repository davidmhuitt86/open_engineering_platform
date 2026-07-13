import 'dart:async';

import '../events/engine_event.dart';
import '../events/engine_event_bus.dart';
import '../graph/models/engineering_graph.dart';
import '../interfaces/selection_provider.dart';
import 'focus_state.dart';
import 'graph_selection.dart';

/// Runtime multi-select selection state (SDD-026 `SelectionEngine`,
/// extended in WORK_PACKAGE_021 ENGINE-TASK-000080).
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
            )
          : GraphSelection(groupIds: {groupId}),
    );
  }

  @override
  void selectMany({
    Set<String> nodeIds = const {},
    Set<String> relationshipIds = const {},
    Set<String> groupIds = const {},
    bool additive = false,
  }) {
    _setSelection(
      additive
          ? GraphSelection(
              nodeIds: {..._current.nodeIds, ...nodeIds},
              relationshipIds: {..._current.relationshipIds, ...relationshipIds},
              groupIds: {..._current.groupIds, ...groupIds},
            )
          : GraphSelection(
              nodeIds: nodeIds,
              relationshipIds: relationshipIds,
              groupIds: groupIds,
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
    ));
  }

  @override
  void selectAll(EngineeringGraph graph) {
    _setSelection(GraphSelection(
      nodeIds: graph.nodes.keys.toSet(),
      relationshipIds: graph.relationships.keys.toSet(),
      groupIds: graph.groups.keys.toSet(),
    ));
  }

  @override
  void deselectAll() => _setSelection(GraphSelection.empty);

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
