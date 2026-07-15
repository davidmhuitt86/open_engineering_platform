import 'editing_command.dart';
import 'editing_session.dart';

/// Deterministic undo/redo stack over [EditingCommand]s
/// (WORK_PACKAGE_021, ENGINE-TASK-000084).
///
/// Selection is deliberately not tracked here — WP021's undo-history list
/// (Create/Delete/Move/Property Change/Relationship/Grouping/Clipboard)
/// never includes selection changes, so `SelectionService` stays outside
/// the command system entirely.
class CommandHistory {
  final int maxDepth;
  final List<EditingCommand> _undoStack = [];
  final List<EditingCommand> _redoStack = [];

  CommandHistory({this.maxDepth = 100});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String? get nextUndoDescription =>
      _undoStack.isEmpty ? null : _undoStack.last.description;
  String? get nextRedoDescription =>
      _redoStack.isEmpty ? null : _redoStack.last.description;

  /// Descriptions of every executed command still on the undo stack,
  /// most-recent-first (WORK_PACKAGE_023, ENGINE-TASK-000105: "Recent
  /// Commands") — reuses the undo stack the history already maintains
  /// rather than tracking a second, parallel list.
  List<String> get recentDescriptions =>
      _undoStack.reversed.map((c) => c.description).toList(growable: false);

  EditingSession execute(EditingCommand command, EditingSession session) {
    final next = command.apply(session);
    _undoStack.add(command);
    if (_undoStack.length > maxDepth) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    return next;
  }

  EditingSession undo(EditingSession session) {
    if (_undoStack.isEmpty) return session;
    final command = _undoStack.removeLast();
    final previous = command.revert(session);
    _redoStack.add(command);
    return previous;
  }

  EditingSession redo(EditingSession session) {
    if (_redoStack.isEmpty) return session;
    final command = _redoStack.removeLast();
    final next = command.apply(session);
    _undoStack.add(command);
    return next;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
