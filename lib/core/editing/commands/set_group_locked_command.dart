import '../editing_command.dart';
import '../editing_session.dart';

/// Sets a group's persisted `locked` intent (ENGINE-TASK-000082: "Lock").
/// Unlike collapse/expand/visibility, lock is a real engineering decision
/// worth preserving, not transient runtime state.
class SetGroupLockedCommand implements EditingCommand {
  final String groupId;
  final bool locked;

  bool? _previousLocked;

  SetGroupLockedCommand(this.groupId, this.locked);

  @override
  String get description => locked ? 'Lock group' : 'Unlock group';

  @override
  EditingSession apply(EditingSession session) {
    final group = session.graph.groups[groupId];
    if (group == null) return session;
    _previousLocked = group.locked;
    return session.copyWith(graph: session.graph.withGroup(group.copyWith(locked: locked)));
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousLocked;
    final group = session.graph.groups[groupId];
    if (previous == null || group == null) return session;
    return session.copyWith(
      graph: session.graph.withGroup(group.copyWith(locked: previous)),
    );
  }
}
