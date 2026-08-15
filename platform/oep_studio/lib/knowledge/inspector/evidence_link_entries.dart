import '../models/evidence_link.dart';
import '../models/evidence_region.dart';
import '../models/knowledge_candidate.dart';

/// One [EvidenceLink] resolved from an Evidence Region's point of view —
/// which Knowledge Candidate it's linked to (Work Package 009
/// STUDIO-TASK-000021 Property Inspector: "Knowledge Candidate Evidence").
class LinkedCandidateEntry {
  const LinkedCandidateEntry({required this.link, required this.candidate});

  final EvidenceLink link;
  final KnowledgeCandidate candidate;
}

/// One [EvidenceLink] resolved from a Knowledge Candidate's point of
/// view — which Evidence Region it's linked to, plus the region's
/// source document name for display (Work Package 009
/// STUDIO-TASK-000021 Property Inspector: "Evidence Links").
class LinkedRegionEntry {
  const LinkedRegionEntry({required this.link, required this.region, required this.sourceName});

  final EvidenceLink link;
  final EvidenceRegion region;
  final String sourceName;
}
