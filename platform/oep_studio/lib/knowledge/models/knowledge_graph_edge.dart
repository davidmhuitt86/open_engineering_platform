/// What kind of existing relationship a [KnowledgeGraphEdge] renders
/// (Work Package 011 STUDIO-TASK-000026). Every edge kind corresponds
/// to data that already exists elsewhere in session state — the graph
/// draws it, it does not define it:
///
/// * [relationshipCandidate] — a `RelationshipCandidate` (Work Package
///   008), source → target. "Relationship Candidates remain edges."
/// * [evidenceLink] — an `EvidenceLink` (Work Package 009), drawn
///   region → candidate. "Evidence Regions connect to Knowledge
///   Candidates."
/// * [sourceContainsRegion] — the structural fact that an
///   `EvidenceRegion.sourceId` names the `SourceMaterial` it was drawn
///   on, drawn source → region. Not separately named in this work
///   package's edge list, but necessary for a Source Material node to
///   connect to anything at all in the graph — see
///   `docs/KNOWLEDGE_GRAPH.md` § Architectural Observations.
/// * [procedureReference] — a `ProcedureStep.referencedCandidateIds`/
///   `referencedRegionIds` entry, drawn from the owning Procedure
///   Candidate to whatever its step references. This work package's
///   own text: "Procedures connect to their Procedure Steps" — read as
///   "a Procedure connects, via its steps, to what those steps
///   reference," since Procedure Steps themselves are not listed among
///   the artifacts this graph visualizes (see `docs/KNOWLEDGE_GRAPH.md`
///   § Architectural Observations).
enum KnowledgeGraphEdgeKind { relationshipCandidate, evidenceLink, sourceContainsRegion, procedureReference }

/// One edge in the Knowledge Session Graph — connects two
/// [KnowledgeGraphNode]s by their `id`s. [label] is optional display
/// text (a `RelationshipCandidate`'s `RelationshipType.label`, for
/// example); most edge kinds have none.
class KnowledgeGraphEdge {
  const KnowledgeGraphEdge({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.kind,
    this.label,
  });

  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final KnowledgeGraphEdgeKind kind;
  final String? label;
}
