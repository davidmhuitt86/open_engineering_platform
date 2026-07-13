import '../editing_command.dart';
import '../editing_session.dart';

/// Renames a group (ENGINE-TASK-000082).
class RenameGroupCommand implements EditingCommand {
  final String groupId;
  final String newDisplayName;

  String? _previousDisplayName;

  RenameGroupCommand(this.groupId, this.newDisplayName);

  @override
  String get description => 'Rename group';

  @override
  EditingSession apply(EditingSession session) {
    final group = session.graph.groups[groupId];
    if (group == null) return session;
    _previousDisplayName = group.displayName;
    return session.copyWith(
      graph: session.graph.withGroup(group.copyWith(displayName: newDisplayName)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousDisplayName;
    final group = session.graph.groups[groupId];
    if (previous == null || group == null) return session;
    return session.copyWith(
      graph: session.graph.withGroup(group.copyWith(displayName: previous)),
    );
  }
}
