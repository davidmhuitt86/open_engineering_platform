import 'dart:async';

import '../events/engine_event.dart';
import '../events/engine_event_bus.dart';
import '../interfaces/selection_provider.dart';
import 'selection_state.dart';

/// Runtime selection state (SDD-026 `SelectionEngine`).
///
/// Deliberately holds only *which* thing is selected — never computes
/// highlight sets or paths. That responsibility belongs to
/// [NavigationService], mirroring the reference implementation's split
/// between its selection manager (state) and its path highlighter
/// (traversal-derived rendering hints).
class SelectionService implements SelectionProvider {
  final EngineEventBus _events;
  final StreamController<SelectionState> _changes =
      StreamController<SelectionState>.broadcast();

  SelectionState _current = const SelectionState.none();

  SelectionService({required EngineEventBus events}) : _events = events;

  @override
  SelectionState get current => _current;

  @override
  Stream<SelectionState> get changes => _changes.stream;

  void _set(SelectionState state, {EngineEventKind? emit, String? subjectId}) {
    _current = state;
    _changes.add(state);
    if (emit != null) {
      _events.emit(EngineEvent(kind: emit, subjectId: subjectId));
    }
  }

  @override
  void selectNode(String nodeId) => _set(
        SelectionState.node(nodeId),
        emit: EngineEventKind.nodeSelected,
        subjectId: nodeId,
      );

  @override
  void selectRelationship(String relationshipId) =>
      _set(SelectionState.relationship(relationshipId));

  @override
  void selectPort(String nodeId, String portId) =>
      _set(SelectionState.port(nodeId, portId));

  @override
  void selectSymbol(String symbolId) => _set(SelectionState.symbol(symbolId));

  @override
  void selectGroup(String groupId) => _set(SelectionState.group(groupId));

  @override
  void selectEvidence(String evidenceId) => _set(
        SelectionState.evidence(evidenceId),
        emit: EngineEventKind.evidenceSelected,
        subjectId: evidenceId,
      );

  @override
  void clear() => _set(const SelectionState.none());

  Future<void> dispose() => _changes.close();
}
