import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/knowledge/models/evidence_link.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_type.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/workspaces/extraction_inspector_dialog.dart';

/// WP-INGEST-012 TEST-A through TEST-J. The Inspector dialog itself is
/// private and hosts a real `pdfrx` `PdfViewer` (no test in this codebase
/// renders one), so per this work package's own instruction the
/// eligibility/count calculation is exercised through the small pure
/// `ExtractionInspectorSummary`, and classification through the public
/// `applyRegionClassification` against the real, unmodified
/// `FoundationRuntimeNotifier`.
void main() {
  const source = 'source-1';
  final now = DateTime(2026, 1, 1);
  final createdSessionIds = <String>[];

  tearDown(() async {
    // Notifier mutations fire-and-forget a session save; let it land before
    // deleting the directory (same discipline as wp_ingest_010's tests).
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      // A still-running fire-and-forget save can briefly hold the file on
      // Windows; retry rather than fail (or leak) over disposable test data.
      for (var attempt = 0; attempt < 10 && directory.existsSync(); attempt++) {
        try {
          await directory.delete(recursive: true);
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    createdSessionIds.clear();
  });

  EvidenceRegion region(String id,
          {required EvidenceOrigin origin,
          String label = 'Unclassified',
          String sourceId = source}) =>
      EvidenceRegion(
        id: id,
        sourceId: sourceId,
        page: 1,
        x: 0.1,
        y: 0.1,
        width: 0.1,
        height: 0.1,
        label: label,
        createdTime: now,
        origin: origin,
      );

  KnowledgeCandidate candidate(String id, {String author = 'uif'}) =>
      KnowledgeCandidate(
        id: id,
        type: KnowledgeCandidateType.component,
        name: 'Candidate $id',
        author: author,
        createdTime: now,
      );

  EvidenceLink link(String candidateId, String regionId) => EvidenceLink(
        id: 'link-$candidateId-$regionId',
        candidateId: candidateId,
        regionId: regionId,
        createdTime: now,
      );

  FoundationServiceState state({
    List<EvidenceRegion> regions = const [],
    List<KnowledgeCandidate> candidates = const [],
    List<EvidenceLink> links = const [],
  }) =>
      FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        evidenceRegions: regions,
        candidates: candidates,
        evidenceLinks: links,
      );

  ExtractionInspectorSummary summaryOf(FoundationServiceState s) =>
      ExtractionInspectorSummary.from(s, source);

  group('New Relationship eligibility', () {
    test('TEST-A: two unclassified human annotations -> disabled', () {
      final summary = summaryOf(state(regions: [
        region('h1', origin: EvidenceOrigin.human),
        region('h2', origin: EvidenceOrigin.human),
      ]));
      expect(summary.classifiedHumanAnnotationCount, 0);
      expect(summary.canCreateRelationship, isFalse);
    });

    test('TEST-B: one classified + one unclassified human annotation -> disabled', () {
      final summary = summaryOf(state(regions: [
        region('h1', origin: EvidenceOrigin.human, label: 'Component'),
        region('h2', origin: EvidenceOrigin.human),
      ]));
      expect(summary.classifiedHumanAnnotationCount, 1);
      expect(summary.canCreateRelationship, isFalse);
    });

    test('TEST-C: two classified human annotations -> enabled (with or without a custom name)', () {
      final summary = summaryOf(state(regions: [
        region('h1', origin: EvidenceOrigin.human, label: 'Component'),
        region('h2', origin: EvidenceOrigin.human, label: 'Text: Ignition Switch'),
      ]));
      expect(summary.classifiedHumanAnnotationCount, 2);
      expect(summary.canCreateRelationship, isTrue);
    });

    test('TEST-D: two machine-generated candidates and zero classified human annotations -> disabled', () {
      final summary = summaryOf(state(
        regions: [
          // A machine region whose label happens to equal a type name must
          // still not count: only HUMAN annotations do.
          region('m1', origin: EvidenceOrigin.machine, label: 'Component'),
          region('m2', origin: EvidenceOrigin.machine, label: 'Component'),
        ],
        candidates: [candidate('c1'), candidate('c2')],
        links: [link('c1', 'm1'), link('c2', 'm2')],
      ));
      expect(summary.candidateCount, 2);
      expect(summary.canCreateRelationship, isFalse);
    });

    test('TEST-E: candidates of unrelated evidence / other sources never enable it', () {
      final summary = summaryOf(state(
        regions: [
          region('other-h1', origin: EvidenceOrigin.human, label: 'Component', sourceId: 'other'),
          region('other-h2', origin: EvidenceOrigin.human, label: 'Tool', sourceId: 'other'),
          region('h1', origin: EvidenceOrigin.human, label: 'Component'),
        ],
        // Plenty of candidates in the session, none related to this source.
        candidates: [candidate('c1'), candidate('c2'), candidate('c3')],
        links: [link('c1', 'other-h1'), link('c2', 'other-h2')],
      ));
      expect(summary.candidateCount, 0, reason: 'none of the session candidates belong to this source');
      expect(summary.classifiedHumanAnnotationCount, 1, reason: 'other-source annotations do not count');
      expect(summary.canCreateRelationship, isFalse);
    });
  });

  group('counts', () {
    test('TEST-F: evidence and candidate counts are independently correct', () {
      final summary = summaryOf(state(
        regions: [
          region('m1', origin: EvidenceOrigin.machine),
          region('h1', origin: EvidenceOrigin.human),
          region('h2', origin: EvidenceOrigin.human),
          region('elsewhere', origin: EvidenceOrigin.human, sourceId: 'other'),
        ],
        candidates: [candidate('c1')],
        links: [link('c1', 'm1')],
      ));
      expect(summary.evidenceCount, 3, reason: 'every region of this source, any origin');
      expect(summary.candidateCount, 1, reason: 'candidates are not evidence and are counted separately');
    });

    test('TEST-G: zero evidence and zero candidates are explicitly zero', () {
      final summary = summaryOf(state());
      expect(summary.evidenceCount, 0);
      expect(summary.candidateCount, 0);
      expect(summary.classifiedHumanAnnotationCount, 0);
      expect(summary.canCreateRelationship, isFalse);
    });
  });

  group('classification semantics (real FoundationRuntimeNotifier)', () {
    ProviderContainer containerWithSession() {
      final id = 'wp-ingest-012-${DateTime.now().microsecondsSinceEpoch}';
      createdSessionIds.add(id);
      final container = ProviderContainer(overrides: [
        foundationRuntimeServiceProvider.overrideWith(
          () => _SessionSeededNotifier(KnowledgeSession(
            id: id,
            name: 'WP-INGEST-012 test',
            repositoryName: 'Repo One',
            author: 'jsmith',
            createdTime: now,
            lastModified: now,
          )),
        ),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    void classify(ProviderContainer container, EvidenceRegion r, KnowledgeCandidateType type, String name) {
      final s = container.read(foundationRuntimeServiceProvider);
      applyRegionClassification(
        notifier: container.read(foundationRuntimeServiceProvider.notifier),
        region: s.evidenceRegions.firstWhere((e) => e.id == r.id),
        linkedCandidateIds: s.candidatesLinkedToEvidenceRegion(r.id).map((c) => c.id).toList(),
        type: type,
        customName: name,
        annotatorId: 'jsmith',
      );
    }

    test('TEST-H: classifying an annotation creates exactly one linked candidate, and nothing else', () {
      final container = containerWithSession();
      final notifier = container.read(foundationRuntimeServiceProvider.notifier);
      final annotation = notifier.createHumanAnnotation(
        sourceId: source,
        page: 1,
        x: 0.1,
        y: 0.1,
        width: 0.1,
        height: 0.1,
        annotatorId: 'jsmith',
        label: 'Unclassified',
      );
      expect(container.read(foundationRuntimeServiceProvider).candidates, isEmpty);

      classify(container, annotation, KnowledgeCandidateType.component, 'Ignition Switch');

      final s = container.read(foundationRuntimeServiceProvider);
      expect(s.candidates, hasLength(1));
      expect(s.candidatesLinkedToEvidenceRegion(annotation.id).single.id, s.candidates.single.id);
      expect(s.candidates.single.type, KnowledgeCandidateType.component);
      expect(s.candidates.single.name, 'Ignition Switch');
      // Candidate-level only: still pending, never committed to a Repository.
      expect(s.candidates.single.isCommitted, isFalse);
      final classified = s.evidenceRegions.single;
      expect(classified.label, 'Component: Ignition Switch');
      expect(classified.origin, EvidenceOrigin.human, reason: 'origin is never altered by classification');
    });

    test('TEST-I: reclassifying updates the existing linked candidate instead of duplicating it', () {
      final container = containerWithSession();
      final notifier = container.read(foundationRuntimeServiceProvider.notifier);
      final annotation = notifier.createHumanAnnotation(
        sourceId: source,
        page: 1,
        x: 0.1,
        y: 0.1,
        width: 0.1,
        height: 0.1,
        annotatorId: 'jsmith',
      );

      classify(container, annotation, KnowledgeCandidateType.component, 'Switch');
      final firstId = container.read(foundationRuntimeServiceProvider).candidates.single.id;
      classify(container, annotation, KnowledgeCandidateType.text, 'Switch label');

      final s = container.read(foundationRuntimeServiceProvider);
      expect(s.candidates, hasLength(1), reason: 'no duplicate candidate');
      expect(s.candidates.single.id, firstId, reason: 'the same candidate was updated');
      expect(s.candidates.single.type, KnowledgeCandidateType.text);
      expect(s.candidates.single.name, 'Switch label');
      expect(s.evidenceLinks, hasLength(1), reason: 'no duplicate evidence link');
      expect(s.evidenceRegions.single.label, 'Text: Switch label');
    });
  });

  test('TEST-J: the relationship button still invokes the existing RelationshipCandidateFormDialog, unmodified',
      () {
    final inspector = File('lib/knowledge/workspaces/extraction_inspector_dialog.dart').readAsStringSync();
    expect(
      RegExp(r'onNewRelationship:\s*\(\)\s*=>\s*showRelationshipCandidateFormDialog\(context\)').hasMatch(inspector),
      isTrue,
      reason: 'the panel action must be the existing dialog, not a new relationship workflow',
    );
    expect(inspector, contains("import '../review/relationship_candidate_form_dialog.dart';"));
    // The conflated count chip is gone; both are separate, explicit chips.
    expect(inspector, isNot(contains("'Evidence/Candidates'")));
    expect(inspector, contains("label: 'Evidence'"));
    expect(inspector, contains("label: 'Candidates'"));
    // The enablement condition is the summary, never a raw candidate count.
    expect(inspector, contains('canCreateRelationship: summary.canCreateRelationship'));
    expect(inspector, isNot(contains('candidates.length >= 2')));
  });
}

/// Overrides only `build()` (never a native Foundation Bridge connection),
/// the same seam `wp_ingest_010`'s and `eam_003`'s tests already use.
class _SessionSeededNotifier extends FoundationRuntimeNotifier {
  _SessionSeededNotifier(this.session);

  final KnowledgeSession session;

  @override
  FoundationServiceState build() =>
      FoundationServiceState(phase: FoundationConnectionPhase.connected, knowledgeSession: session);
}
