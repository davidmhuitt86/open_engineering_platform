import 'knowledge_graph_edge.dart';
import 'knowledge_graph_node.dart';

/// The complete Knowledge Session Graph (Work Package 011
/// STUDIO-TASK-000026) for the active Knowledge Curation Session —
/// "completely independent of Foundation Graph." Computed on demand by
/// `KnowledgeGraphService.buildGraph` from the Connection Manager's
/// existing session state — never stored, the same derived-not-stored
/// discipline `CommitPreview` (Work Package 008) and
/// `CandidateValidationResult` (Work Package 010) already established.
class KnowledgeSessionGraph {
  const KnowledgeSessionGraph({required this.nodes, required this.edges});

  final List<KnowledgeGraphNode> nodes;
  final List<KnowledgeGraphEdge> edges;

  bool get isEmpty => nodes.isEmpty;
}
