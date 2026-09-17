import '../../core/models/relationship_type.dart' as core;
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/relationship_candidate.dart';
import '../../knowledge/services/knowledge_session_service.dart';

/// A deterministic, minimal relationship candidate representation
/// (AP-INGEST-001 § 14, WP-INGEST-001 § 12).
///
/// **Known limitation, explicitly documented per WP-INGEST-001 § 12**
/// ("If relationship extraction is not yet sufficiently generalized for
/// the TRX300 benchmark, implement the adapter/representation necessary
/// to preserve candidate relationships and clearly document any remaining
/// extraction limitation"): no true topological wire/connector
/// relationship extraction exists anywhere in this codebase to reuse
/// (`EngineeringEntityExtractionService` recognizes individual entities
/// only — torque values, wire gauges, etc. — with no cross-entity
/// relationship logic). Building a real schematic-topology relationship
/// extractor (tracing which wire connects which connector/component) is
/// exactly the "symbol/schematic recognition" capability AP-INGEST-001
/// § 30/§ 34 explicitly defers to future work, and is far beyond a "PDF
/// parser + reused OCR + reused entity extraction" vertical slice.
///
/// What this service *does* provide, so AC-009/TEST candidate-relationship
/// representation is real rather than absent: candidates whose source
/// [KnowledgeCandidate]s were extracted from entities appearing on the
/// same page, in the same (page, then reading-order) sequence entity
/// extraction already produces, are connected pairwise by a
/// [core.RelationshipType.references] candidate — "this finding co-occurs
/// on the same page as that finding," a true, source-supported,
/// deterministic relationship, just not a wire-topology one. Uses the
/// existing [core.RelationshipType] taxonomy (AP-INGEST-001 § 14: "Use the
/// existing OEP Relationship Model... Do not invent a competing
/// relationship taxonomy.") rather than a new one.
abstract final class RelationshipExtractionService {
  /// [orderedCandidates] must already be in the same-page, reading-order
  /// sequence entity/candidate extraction produced them in (see
  /// `CandidateGenerationService.generate`, which preserves
  /// `EngineeringEntityExtractionService`'s own page/line/reading-order
  /// traversal). Pairs consecutive candidates that share the same
  /// `originPage` (tracked via [candidatePages]).
  static List<RelationshipCandidate> extract({
    required List<KnowledgeCandidate> orderedCandidates,
    required Map<String, int> candidatePages,
  }) {
    final relationships = <RelationshipCandidate>[];
    final now = DateTime.now();
    for (var i = 0; i < orderedCandidates.length - 1; i++) {
      final current = orderedCandidates[i];
      final next = orderedCandidates[i + 1];
      if (candidatePages[current.id] != candidatePages[next.id]) continue;
      relationships.add(
        RelationshipCandidate(
          id: KnowledgeSessionService.generateId('uif-relationship'),
          sourceCandidateId: current.id,
          targetCandidateId: next.id,
          type: core.RelationshipType.references,
          description:
              'Co-located on the same source page (deterministic proximity heuristic — see '
              'RelationshipExtractionService doc comment for this vertical slice\'s known limitation).',
          createdTime: now,
        ),
      );
    }
    return relationships;
  }
}
