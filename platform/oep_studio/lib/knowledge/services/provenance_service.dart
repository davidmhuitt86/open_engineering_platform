import '../models/candidate_provenance.dart';
import '../models/evidence_link.dart';
import '../models/evidence_region.dart';
import '../models/page_selection.dart';
import '../models/source_material.dart';

/// Pure provenance-derivation logic for the Provenance Explorer (Work
/// Package 011 STUDIO-TASK-000027) — "Provenance is derived from
/// existing session state and shall not duplicate persisted data."
/// Holds no state of its own; every method takes a snapshot and
/// returns a value.
abstract final class ProvenanceService {
  /// Computes [candidateId]'s full provenance chain: every Evidence
  /// Region it is linked to, each with its Page Selection (if one
  /// exists for that region's page) and Source Material. Entries are
  /// sorted by source file name, then page, then region label, so the
  /// display order is stable across rebuilds. A region whose
  /// `EvidenceLink` still exists but whose own record has been removed
  /// is skipped (this work package's Error Handling: "Broken
  /// references") rather than crashing the Provenance Explorer — the
  /// Connection Manager's own cascading deletes already prevent this
  /// in the normal case.
  static CandidateProvenance computeProvenance({
    required String candidateId,
    required List<EvidenceLink> evidenceLinks,
    required List<EvidenceRegion> evidenceRegions,
    required List<PageSelection> pageSelections,
    required List<SourceMaterial> sourceMaterials,
  }) {
    final regionsById = {for (final region in evidenceRegions) region.id: region};
    final sourcesById = {for (final source in sourceMaterials) source.id: source};

    final entries = <ProvenanceEntry>[];
    for (final link in evidenceLinks) {
      if (link.candidateId != candidateId) continue;
      final region = regionsById[link.regionId];
      if (region == null) continue;

      PageSelection? pageSelection;
      for (final selection in pageSelections) {
        if (selection.sourceId == region.sourceId && selection.page == region.page) {
          pageSelection = selection;
          break;
        }
      }

      entries.add(ProvenanceEntry(region: region, pageSelection: pageSelection, source: sourcesById[region.sourceId]));
    }

    entries.sort((a, b) {
      final sourceCompare = (a.source?.originalFileName ?? '').compareTo(b.source?.originalFileName ?? '');
      if (sourceCompare != 0) return sourceCompare;
      final pageCompare = a.region.page.compareTo(b.region.page);
      if (pageCompare != 0) return pageCompare;
      return a.region.label.compareTo(b.region.label);
    });

    return CandidateProvenance(candidateId: candidateId, entries: entries);
  }
}
