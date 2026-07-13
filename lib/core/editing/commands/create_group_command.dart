import '../../graph/models/engineering_group.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Creates a group (ENGINE-TASK-000082).
class CreateGroupCommand implements EditingCommand {
  final EngineeringGroup group;

  CreateGroupCommand(this.group);

  @override
  String get description => 'Create group ${group.displayName}';

  @override
  EditingSession apply(EditingSession session) {
    return session.copyWith(graph: session.graph.withGroup(group));
  }

  @override
  EditingSession revert(EditingSession session) {
    return session.copyWith(graph: session.graph.withoutGroup(group.id));
  }
}
