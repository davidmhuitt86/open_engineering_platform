import '../../graph/models/evidence_link.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Replaces one evidence link on a node, matched by [EvidenceLink.id]
/// (ENGINE-TASK-000085: Evidence Link property editing).
class UpdateEvidenceLinkCommand implements EditingCommand {
  final String nodeId;
  final EvidenceLink updatedLink;

  EvidenceLink? _previousLink;

  UpdateEvidenceLinkCommand(this.nodeId, this.updatedLink);

  @override
  String get description => 'Update evidence link';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    final index = node.evidenceLinks.indexWhere((e) => e.id == updatedLink.id);
    if (index == -1) return session;
    _previousLink = node.evidenceLinks[index];
    final links = [...node.evidenceLinks];
    links[index] = updatedLink;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(evidenceLinks: links)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousLink;
    final node = session.graph.nodes[nodeId];
    if (previous == null || node == null) return session;
    final index = node.evidenceLinks.indexWhere((e) => e.id == updatedLink.id);
    if (index == -1) return session;
    final links = [...node.evidenceLinks];
    links[index] = previous;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(evidenceLinks: links)),
    );
  }
}
