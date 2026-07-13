import 'dart:async';

import '../events/engine_event.dart';
import '../events/engine_event_bus.dart';
import 'command_history.dart';
import 'editing_command.dart';
import 'editing_session.dart';

/// Orchestrates undoable editing (WORK_PACKAGE_021).
///
/// The single object Views observe to satisfy ENGINE-TASK-000087 ("Diagram
/// View shall automatically observe... No manual refreshes. Views remain
/// passive.") — a host subscribes once to [sessionChanges] and re-renders
/// on every emission, instead of Phase 1's per-handler manual graph
/// rewriting.
class EditingService {
  final CommandHistory _history;
  final EngineEventBus _events;
  final StreamController<EditingSession> _controller =
      StreamController<EditingSession>.broadcast();

  EditingSession _session;

  EditingService({
    required EditingSession initialSession,
    required EngineEventBus events,
    CommandHistory? history,
  })  : _session = initialSession,
        _events = events,
        _history = history ?? CommandHistory();

  EditingSession get session => _session;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get nextUndoDescription => _history.nextUndoDescription;
  String? get nextRedoDescription => _history.nextRedoDescription;

  Stream<EditingSession> get sessionChanges => _controller.stream;

  EditingSession execute(EditingCommand command) {
    _session = _history.execute(command, _session);
    _notify(command.description);
    return _session;
  }

  EditingSession undo() {
    if (!canUndo) return _session;
    _session = _history.undo(_session);
    _notify('undo');
    return _session;
  }

  EditingSession redo() {
    if (!canRedo) return _session;
    _session = _history.redo(_session);
    _notify('redo');
    return _session;
  }

  /// Replaces the session without going through the command history —
  /// used only to load/seed a session (e.g. the Demonstration Host's
  /// initial sample graph), never as an editing shortcut.
  void resetSession(EditingSession session) {
    _session = session;
    _history.clear();
    _notify('reset');
  }

  /// Toggles a group's transient collapse/expand state
  /// (ENGINE-TASK-000082). Deliberately outside the command system —
  /// `RuntimeMetadata.expanded` is transient, never-persisted state
  /// (SDD-027), the same reasoning that keeps `SelectionService` outside
  /// undo/redo (ENGINE-TASK-000084's history list never mentions
  /// selection or collapse/expand).
  void toggleGroupExpanded(String groupId) {
    final group = _session.graph.groups[groupId];
    if (group == null) return;
    final updated = group.copyWith(
      runtime: group.runtime.copyWith(expanded: !group.runtime.expanded),
    );
    _session = _session.copyWith(graph: _session.graph.withGroup(updated));
    _notify('toggleGroupExpanded');
  }

  /// Sets a group's transient visibility (ENGINE-TASK-000082). Same
  /// non-undoable reasoning as [toggleGroupExpanded].
  void setGroupVisible(String groupId, bool visible) {
    final group = _session.graph.groups[groupId];
    if (group == null) return;
    final updated = group.copyWith(runtime: group.runtime.copyWith(visible: visible));
    _session = _session.copyWith(graph: _session.graph.withGroup(updated));
    _notify('setGroupVisible');
  }

  void _notify(String operation) {
    _controller.add(_session);
    _events.emit(EngineEvent(
      kind: EngineEventKind.graphChanged,
      graphId: _session.graph.id,
      payload: {'operation': operation},
    ));
  }

  Future<void> dispose() => _controller.close();
}
