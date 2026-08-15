import '../editing_command.dart';
import '../editing_session.dart';

/// Replaces a node's visual symbol (WORK_PACKAGE_023, ENGINE-TASK-000102:
/// "Replace Symbol") — `symbolId` is already a mutable `EngineeringNode`
/// field (SDD-027), so this is a small Graph-layer command, the same
/// shape as `RenameNodeCommand`/`ChangeNodeCategoryCommand`. The node's
/// identity, relationships, and properties are unaffected — only which
/// symbol renders it changes.
class ReplaceSymbolCommand implements EditingCommand {
  final String nodeId;
  final String newSymbolId;

  String? _previousSymbolId;

  ReplaceSymbolCommand(this.nodeId, this.newSymbolId);

  @override
  String get description => 'Replace symbol';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    _previousSymbolId = node.symbolId;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(symbolId: newSymbolId)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    final previous = _previousSymbolId;
    return session.copyWith(
      graph: session.graph.withNode(
        previous == null
            ? node.copyWith(clearSymbolId: true)
            : node.copyWith(symbolId: previous),
      ),
    );
  }
}
