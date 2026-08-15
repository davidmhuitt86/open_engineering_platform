import 'package:engineering_engine/engineering_engine.dart';

/// Undo/Redo/Copy/Cut/Paste/Delete/Duplicate, wired directly to
/// `engine.editing`/`engine.clipboard`/`engine.registry.selection`
/// (WORK_PACKAGE_024, ENGINE-TASK-000112) — the same direct-callback
/// pattern every other Studio feature already uses (there is no
/// Studio-wide command bus to integrate with; see `docs/
/// STUDIO_ENGINE_HOST.md`). Shared by Diagram Studio's toolbar buttons
/// and its `CallbackShortcuts` keyboard bindings so both paths stay in
/// sync by construction.
class StudioCommandActions {
  const StudioCommandActions(this.engine);

  final EngineeringEngine engine;

  bool get canUndo => engine.editing.canUndo;
  bool get canRedo => engine.editing.canRedo;
  bool get hasClipboardContent => engine.clipboard.hasContent;

  void undo() => engine.editing.undo();
  void redo() => engine.editing.redo();

  void copy(EditingSession session, GraphSelection selection) {
    engine.clipboard.copy(session, selection);
  }

  void cut(EditingSession session, GraphSelection selection) {
    if (selection.isEmpty) return;
    final command = engine.clipboard.cut(session, selection);
    engine.editing.execute(command);
    engine.registry.selection.deselectAll();
  }

  void paste() {
    final command = engine.clipboard.paste();
    if (command == null) return;
    engine.editing.execute(command);
    engine.registry.selection.selectMany(nodeIds: command.pastedNodeIds.toSet());
  }

  void duplicate(GraphSelection selection) {
    if (selection.isEmpty) return;
    final command = engine.clipboard.duplicate(selection);
    engine.editing.execute(command);
    engine.registry.selection.selectMany(nodeIds: command.duplicatedNodeIds.toSet());
  }

  void delete(GraphSelection selection) {
    if (selection.isEmpty) return;
    engine.editing.execute(DeleteManyCommand(
      nodeIds: selection.nodeIds,
      relationshipIds: selection.relationshipIds,
      groupIds: selection.groupIds,
      annotationIds: selection.annotationIds,
    ));
    engine.registry.selection.deselectAll();
  }
}
