import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/models/relationship_type.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_graph_edge.dart';
import 'package:oep_studio/knowledge/models/knowledge_graph_node.dart';
import 'package:oep_studio/knowledge/models/procedure_step.dart';
import 'package:oep_studio/knowledge/models/relationship_candidate.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/knowledge_graph_service.dart';

final _cover = KnowledgeCandidate(
  id: 'c1',
  type: KnowledgeCandidateType.component,
  name: 'Timing Cover',
  createdTime: DateTime(2026, 1, 1),
);
final _install = KnowledgeCandidate(
  id: 'c2',
  type: KnowledgeCandidateType.procedure,
  name: 'Install Timing Cover',
  createdTime: DateTime(2026, 1, 1),
);
final _region = EvidenceRegion(
  id: 'r1',
  sourceId: 's1',
  page: 1,
  x: 0,
  y: 0,
  width: 0.2,
  height: 0.2,
  label: 'Torque Spec',
  createdTime: DateTime(2026, 1, 1),
);
final _source = SourceMaterial(
  id: 's1',
  originalFileName: 'manual.pdf',
  localPath: '/tmp/manual.pdf',
  type: SourceMaterialType.pdf,
  sizeBytes: 100,
  importDate: DateTime(2026, 1, 1),
  addedBy: 'jsmith',
);

void main() {
  group('buildGraph', () {
    test('creates one node per candidate/region/source', () {
      final graph = KnowledgeGraphService.buildGraph(
        candidates: [_cover, _install],
        relationshipCandidates: const [],
        evidenceRegions: [_region],
        evidenceLinks: const [],
        sourceMaterials: [_source],
        procedureSteps: const [],
      );
      expect(graph.nodes, hasLength(4));
      expect(graph.nodes.map((n) => n.id).toSet(), {'c1', 'c2', 'r1', 's1'});
      expect(graph.nodes.singleWhere((n) => n.id == 'c1').kind, KnowledgeGraphNodeKind.candidate);
      expect(graph.nodes.singleWhere((n) => n.id == 'r1').kind, KnowledgeGraphNodeKind.evidenceRegion);
      expect(graph.nodes.singleWhere((n) => n.id == 's1').kind, KnowledgeGraphNodeKind.sourceMaterial);
    });

    test('an empty session produces an empty graph', () {
      final graph = KnowledgeGraphService.buildGraph(
        candidates: const [],
        relationshipCandidates: const [],
        evidenceRegions: const [],
        evidenceLinks: const [],
        sourceMaterials: const [],
        procedureSteps: const [],
      );
      expect(graph.isEmpty, isTrue);
    });

    test('draws a relationship candidate as an edge between two candidates', () {
      final relationship = RelationshipCandidate(
        id: 'rel1',
        sourceCandidateId: 'c1',
        targetCandidateId: 'c2',
        type: RelationshipType.references,
        createdTime: DateTime(2026, 1, 1),
      );
      final graph = KnowledgeGraphService.buildGraph(
        candidates: [_cover, _install],
        relationshipCandidates: [relationship],
        evidenceRegions: const [],
        evidenceLinks: const [],
        sourceMaterials: const [],
        procedureSteps: const [],
      );
      final edge = graph.edges.single;
      expect(edge.kind, KnowledgeGraphEdgeKind.relationshipCandidate);
      expect(edge.sourceNodeId, 'c1');
      expect(edge.targetNodeId, 'c2');
    });

    test('skips a relationship candidate whose endpoint no longer exists (broken reference)', () {
      final relationship = RelationshipCandidate(
        id: 'rel1',
        sourceCandidateId: 'c1',
        targetCandidateId: 'missing',
        type: RelationshipType.references,
        createdTime: DateTime(2026, 1, 1),
      );
      final graph = KnowledgeGraphService.buildGraph(
        candidates: [_cover],
        relationshipCandidates: [relationship],
        evidenceRegions: const [],
        evidenceLinks: const [],
        sourceMaterials: const [],
        procedureSteps: const [],
      );
      expect(graph.edges, isEmpty);
    });

    test('draws an evidence link as region -> candidate', () {
      final link = EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1));
      final graph = KnowledgeGraphService.buildGraph(
        candidates: [_cover],
        relationshipCandidates: const [],
        evidenceRegions: [_region],
        evidenceLinks: [link],
        sourceMaterials: const [],
        procedureSteps: const [],
      );
      final edge = graph.edges.single;
      expect(edge.kind, KnowledgeGraphEdgeKind.evidenceLink);
      expect(edge.sourceNodeId, 'r1');
      expect(edge.targetNodeId, 'c1');
    });

    test('draws source-contains-region for every region on a known source', () {
      final graph = KnowledgeGraphService.buildGraph(
        candidates: const [],
        relationshipCandidates: const [],
        evidenceRegions: [_region],
        evidenceLinks: const [],
        sourceMaterials: [_source],
        procedureSteps: const [],
      );
      final edge = graph.edges.single;
      expect(edge.kind, KnowledgeGraphEdgeKind.sourceContainsRegion);
      expect(edge.sourceNodeId, 's1');
      expect(edge.targetNodeId, 'r1');
    });

    test('draws a procedure-reference edge for each of a step\'s references', () {
      final step = ProcedureStep(
        id: 'step1',
        candidateId: 'c2',
        title: 'Torque bolts',
        referencedCandidateIds: const ['c1'],
        referencedRegionIds: const ['r1'],
        createdTime: DateTime(2026, 1, 1),
      );
      final graph = KnowledgeGraphService.buildGraph(
        candidates: [_cover, _install],
        relationshipCandidates: const [],
        evidenceRegions: [_region],
        evidenceLinks: const [],
        sourceMaterials: const [],
        procedureSteps: [step],
      );
      expect(graph.edges, hasLength(2));
      expect(graph.edges.every((edge) => edge.kind == KnowledgeGraphEdgeKind.procedureReference), isTrue);
      expect(graph.edges.every((edge) => edge.sourceNodeId == 'c2'), isTrue);
      expect(graph.edges.map((edge) => edge.targetNodeId).toSet(), {'c1', 'r1'});
    });

    test('skips a procedure step reference pointing at a deleted candidate or region', () {
      final step = ProcedureStep(
        id: 'step1',
        candidateId: 'c2',
        title: 'Torque bolts',
        referencedCandidateIds: const ['missing-candidate'],
        referencedRegionIds: const ['missing-region'],
        createdTime: DateTime(2026, 1, 1),
      );
      final graph = KnowledgeGraphService.buildGraph(
        candidates: [_install],
        relationshipCandidates: const [],
        evidenceRegions: const [],
        evidenceLinks: const [],
        sourceMaterials: const [],
        procedureSteps: [step],
      );
      expect(graph.edges, isEmpty);
    });
  });
}
