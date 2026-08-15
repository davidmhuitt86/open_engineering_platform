import '../../graph/models/engineering_group.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Removes a group without touching its member nodes (ENGINE-TASK-000082:
/// "Ungroup"). Any nested child groups are reparented to the removed
/// group's own parent, preserving nesting depth for the rest of the tree.
class UngroupCommand implements EditingCommand {
  final String groupId;

  EngineeringGroup? _removedGroup;
  Map<String, String?> _reparentedChildren = const {};

  UngroupCommand(this.groupId);

  @override
  String get description => 'Ungroup';

  @override
  EditingSession apply(EditingSession session) {
    final group = session.graph.groups[groupId];
    if (group == null) return session;
    _removedGroup = group;

    final children = session.graph.groups.values
        .where((g) => g.parentGroupId == groupId)
        .toList();
    _reparentedChildren = {for (final child in children) child.id: child.parentGroupId};

    final groups = {...session.graph.groups}..remove(groupId);
    for (final child in children) {
      groups[child.id] = child.copyWith(
        parentGroupId: group.parentGroupId,
        clearParentGroupId: group.parentGroupId == null,
      );
    }
    return session.copyWith(graph: session.graph.copyWith(groups: groups));
  }

  @override
  EditingSession revert(EditingSession session) {
    final removed = _removedGroup;
    if (removed == null) return session;
    final groups = {...session.graph.groups, removed.id: removed};
    for (final entry in _reparentedChildren.entries) {
      final child = groups[entry.key];
      if (child == null) continue;
      groups[entry.key] = child.copyWith(
        parentGroupId: entry.value,
        clearParentGroupId: entry.value == null,
      );
    }
    return session.copyWith(graph: session.graph.copyWith(groups: groups));
  }
}
