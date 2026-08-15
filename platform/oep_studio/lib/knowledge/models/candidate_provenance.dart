import 'evidence_region.dart';
import 'page_selection.dart';
import 'source_material.dart';

/// One step of a Knowledge Candidate's provenance chain (Work Package
/// 011 STUDIO-TASK-000027): "Knowledge Candidate → Evidence Region(s)
/// → Page Selection → Source Material." [pageSelection] is `null` when
/// [region]'s page was never explicitly toggled as a Page Selection
/// (Work Package 009) — a region can be drawn without the engineer
/// ever checking that page's Page Selection box, so the chain's
/// "Page Selection" link is present when it exists and simply absent
/// otherwise, rather than fabricated. [source] is `null` only for a
/// broken reference (the region's Source Material was deleted without
/// the region itself being cascade-removed) — this work package's
/// Error Handling: "Broken references."
class ProvenanceEntry {
  const ProvenanceEntry({required this.region, this.pageSelection, this.source});

  final EvidenceRegion region;
  final PageSelection? pageSelection;
  final SourceMaterial? source;
}

/// The full provenance chain for one Knowledge Candidate — every
/// [ProvenanceEntry] reachable from its Evidence Links. Computed on
/// demand by `ProvenanceService.computeProvenance` from data that
/// already exists elsewhere in session state ([EvidenceLink],
/// [EvidenceRegion], [PageSelection], [SourceMaterial]) — never
/// stored, never duplicated (this work package's own text:
/// "Provenance is derived from existing session state and shall not
/// duplicate persisted data").
class CandidateProvenance {
  const CandidateProvenance({required this.candidateId, required this.entries});

  final String candidateId;
  final List<ProvenanceEntry> entries;

  bool get hasEvidence => entries.isNotEmpty;
}
