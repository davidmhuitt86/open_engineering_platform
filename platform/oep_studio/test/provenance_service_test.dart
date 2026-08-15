import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/page_selection.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/models/source_material_type.dart';
import 'package:oep_studio/knowledge/services/provenance_service.dart';

final _region = EvidenceRegion(
  id: 'r1',
  sourceId: 's1',
  page: 2,
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
  group('computeProvenance', () {
    test('a candidate with no evidence links has an empty chain', () {
      final provenance = ProvenanceService.computeProvenance(
        candidateId: 'c1',
        evidenceLinks: const [],
        evidenceRegions: const [],
        pageSelections: const [],
        sourceMaterials: const [],
      );
      expect(provenance.hasEvidence, isFalse);
      expect(provenance.entries, isEmpty);
    });

    test('builds the full chain: region -> page selection -> source', () {
      final link = EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1));
      final pageSelection = PageSelection(id: 'p1', sourceId: 's1', page: 2, createdTime: DateTime(2026, 1, 1));
      final provenance = ProvenanceService.computeProvenance(
        candidateId: 'c1',
        evidenceLinks: [link],
        evidenceRegions: [_region],
        pageSelections: [pageSelection],
        sourceMaterials: [_source],
      );
      expect(provenance.hasEvidence, isTrue);
      final entry = provenance.entries.single;
      expect(entry.region.id, 'r1');
      expect(entry.pageSelection?.id, 'p1');
      expect(entry.source?.id, 's1');
    });

    test('pageSelection is null when the region\'s page was never toggled', () {
      final link = EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1));
      final provenance = ProvenanceService.computeProvenance(
        candidateId: 'c1',
        evidenceLinks: [link],
        evidenceRegions: [_region],
        pageSelections: const [],
        sourceMaterials: [_source],
      );
      expect(provenance.entries.single.pageSelection, isNull);
      expect(provenance.entries.single.source, isNotNull);
    });

    test('source is null (marked missing) when the region\'s source no longer exists', () {
      final link = EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'r1', createdTime: DateTime(2026, 1, 1));
      final provenance = ProvenanceService.computeProvenance(
        candidateId: 'c1',
        evidenceLinks: [link],
        evidenceRegions: [_region],
        pageSelections: const [],
        sourceMaterials: const [],
      );
      expect(provenance.entries.single.source, isNull);
    });

    test('skips a link whose region no longer exists (broken reference)', () {
      final link = EvidenceLink(id: 'link1', candidateId: 'c1', regionId: 'missing', createdTime: DateTime(2026, 1, 1));
      final provenance = ProvenanceService.computeProvenance(
        candidateId: 'c1',
        evidenceLinks: [link],
        evidenceRegions: const [],
        pageSelections: const [],
        sourceMaterials: const [],
      );
      expect(provenance.entries, isEmpty);
    });

    test('only includes links for the requested candidate', () {
      final link = EvidenceLink(id: 'link1', candidateId: 'other', regionId: 'r1', createdTime: DateTime(2026, 1, 1));
      final provenance = ProvenanceService.computeProvenance(
        candidateId: 'c1',
        evidenceLinks: [link],
        evidenceRegions: [_region],
        pageSelections: const [],
        sourceMaterials: [_source],
      );
      expect(provenance.entries, isEmpty);
    });
  });
}
