import '../editing/commands/delete_many_command.dart';
import '../editing/commands/duplicate_selection_command.dart';
import '../editing/commands/paste_command.dart';
import '../editing/editing_session.dart';
import '../interfaces/clipboard_provider.dart';
import '../selection/graph_selection.dart';
import '../views/diagram/diagram_geometry.dart';
import 'clipboard_extraction.dart';

/// Copy/Cut/Paste/Duplicate orchestration (ENGINE-TASK-000083).
///
/// Copying itself isn't a graph edit, so it isn't a command — it just
/// writes to [ClipboardProvider] directly, the same way selection changes
/// don't go through the command system. Cut/Paste/Duplicate *do* mutate
/// the graph, so this returns [EditingCommand]s for the caller to run
/// through `EditingService.execute` — `ClipboardService` never executes
/// commands itself, keeping one place (`EditingService`) responsible for
/// the undo/redo history.
class ClipboardService {
  final ClipboardProvider provider;

  ClipboardService({required this.provider});

  bool get hasContent => provider.content != null && !provider.content!.isEmpty;

  void copy(EditingSession session, GraphSelection selection) {
    provider.write(ClipboardExtraction.extract(session, selection));
  }

  /// Copies the selection, then returns a command that deletes it — the
  /// caller executes the returned command via `EditingService`.
  DeleteManyCommand cut(EditingSession session, GraphSelection selection) {
    copy(session, selection);
    return DeleteManyCommand(
      nodeIds: selection.nodeIds,
      relationshipIds: selection.relationshipIds,
      groupIds: selection.groupIds,
    );
  }

  PasteCommand? paste({Point2D offset = const Point2D(24, 24)}) {
    final entry = provider.content;
    if (entry == null || entry.isEmpty) return null;
    return PasteCommand(entry, offset: offset);
  }

  DuplicateSelectionCommand duplicate(
    GraphSelection selection, {
    Point2D offset = const Point2D(24, 24),
  }) {
    return DuplicateSelectionCommand(selection, offset: offset);
  }
}
