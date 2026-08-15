import 'package:flutter/material.dart';

import '../models/evidence_link.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_graph_edge.dart';
import '../models/knowledge_graph_node.dart';
import '../models/knowledge_session_graph.dart';
import '../models/procedure_step.dart';
import '../models/relationship_candidate.dart';
import '../models/source_material.dart';

/// The Knowledge Session Graph icon used for every Evidence Region
/// node — matches the region-drawing tool's own icon
/// (`pdf_source_viewer.dart`'s "Draw Evidence Region" button), so an
/// Evidence Region reads as the same concept everywhere it appears.
const _evidenceRegionIcon = Icons.crop_din;

/// Pure graph-construction logic for the Knowledge Session Graph (Work
/// Package 011 STUDIO-TASK-000026) — "Graph construction belongs in
/// services." Holds no state; every method takes a snapshot of the
/// active session's data and returns a value.
abstract final class KnowledgeGraphService {
  /// Builds the complete [KnowledgeSessionGraph] for the active
  /// session. Never throws on a broken reference (a
  /// `RelationshipCandidate`/`EvidenceLink`/`ProcedureStep` pointing at
  /// something that no longer exists) — this work package's Error
  /// Handling: "Broken references, Invalid graph nodes" — such an edge
  /// is silently omitted rather than crashing the graph, since the
  /// Connection Manager's own cascading deletes already prevent this
  /// in the normal case; this is defensive, not the expected path.
  static KnowledgeSessionGraph buildGraph({
    required List<KnowledgeCandidate> candidates,
    required List<RelationshipCandidate> relationshipCandidates,
    required List<EvidenceRegion> evidenceRegions,
    required List<EvidenceLink> evidenceLinks,
    required List<SourceMaterial> sourceMaterials,
    required List<ProcedureStep> procedureSteps,
  }) {
    final candidateIds = candidates.map((candidate) => candidate.id).toSet();
    final regionIds = evidenceRegions.map((region) => region.id).toSet();
    final sourceIds = sourceMaterials.map((source) => source.id).toSet();

    final nodes = <KnowledgeGraphNode>[
      for (final candidate in candidates)
        KnowledgeGraphNode(
          id: candidate.id,
          kind: KnowledgeGraphNodeKind.candidate,
          label: candidate.name,
          icon: candidate.type.icon,
        ),
      for (final region in evidenceRegions)
        KnowledgeGraphNode(
          id: region.id,
          kind: KnowledgeGraphNodeKind.evidenceRegion,
          label: region.label,
          icon: _evidenceRegionIcon,
        ),
      for (final source in sourceMaterials)
        KnowledgeGraphNode(
          id: source.id,
          kind: KnowledgeGraphNodeKind.sourceMaterial,
          label: source.originalFileName,
          icon: source.type.icon,
        ),
    ];

    final edges = <KnowledgeGraphEdge>[
      for (final relationship in relationshipCandidates)
        if (candidateIds.contains(relationship.sourceCandidateId) && candidateIds.contains(relationship.targetCandidateId))
          KnowledgeGraphEdge(
            id: 'rel-${relationship.id}',
            sourceNodeId: relationship.sourceCandidateId,
            targetNodeId: relationship.targetCandidateId,
            kind: KnowledgeGraphEdgeKind.relationshipCandidate,
            label: relationship.type.label,
          ),
      for (final link in evidenceLinks)
        if (regionIds.contains(link.regionId) && candidateIds.contains(link.candidateId))
          KnowledgeGraphEdge(
            id: 'link-${link.id}',
            sourceNodeId: link.regionId,
            targetNodeId: link.candidateId,
            kind: KnowledgeGraphEdgeKind.evidenceLink,
          ),
      for (final region in evidenceRegions)
        if (sourceIds.contains(region.sourceId))
          KnowledgeGraphEdge(
            id: 'contains-${region.id}',
            sourceNodeId: region.sourceId,
            targetNodeId: region.id,
            kind: KnowledgeGraphEdgeKind.sourceContainsRegion,
          ),
      for (final step in procedureSteps) ...[
        if (candidateIds.contains(step.candidateId))
          for (final referencedId in step.referencedCandidateIds)
            if (candidateIds.contains(referencedId) && referencedId != step.candidateId)
              KnowledgeGraphEdge(
                id: 'stepref-${step.id}-$referencedId',
                sourceNodeId: step.candidateId,
                targetNodeId: referencedId,
                kind: KnowledgeGraphEdgeKind.procedureReference,
              ),
        if (candidateIds.contains(step.candidateId))
          for (final referencedRegionId in step.referencedRegionIds)
            if (regionIds.contains(referencedRegionId))
              KnowledgeGraphEdge(
                id: 'stepref-${step.id}-$referencedRegionId',
                sourceNodeId: step.candidateId,
                targetNodeId: referencedRegionId,
                kind: KnowledgeGraphEdgeKind.procedureReference,
              ),
      ],
    ];

    return KnowledgeSessionGraph(nodes: nodes, edges: edges);
  }
}
