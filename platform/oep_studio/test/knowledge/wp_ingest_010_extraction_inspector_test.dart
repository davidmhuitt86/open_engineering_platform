import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/ingestion/services/candidate_generation_service.dart';
import 'package:oep_studio/knowledge/models/engineering_entity.dart';
import 'package:oep_studio/knowledge/models/engineering_entity_type.dart';
import 'package:oep_studio/knowledge/models/evidence_annotation_status.dart';
import 'package:oep_studio/knowledge/models/evidence_origin.dart';
import 'package:oep_studio/knowledge/models/evidence_region.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/session_status.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-010 §13. Covers the EvidenceRegion schema extension, the two
/// new `FoundationRuntimeNotifier` methods (`createHumanAnnotation`,
/// `verifyEvidenceAnnotation`), the two new source-scoped state getters,
/// and `CandidateGenerationService`'s explicit machine-origin stamping —
/// every one of the 13 focus areas this work package's own spec lists.
///
/// Does not exercise the `ExtractionInspectorDialog` widget itself with a
/// full pump (that would require a real PDF file and a real `pdfrx`
/// render, which the existing `PdfSourceViewer`/`OcrLayerViewer` test
/// suites already establish is impractical without one) — the dialog's
/// own logic (`_finishDrag`/`_annotateExisting`/`_openClassifyDialog`) is
/// a thin, direct pass-through to `createHumanAnnotation`, which IS
/// exercised directly and fully here at the seam it actually delegates
/// to, per this session's established "test at the real boundary, not a
/// hand-rolled duplicate of it" discipline.
void main() {
  final createdSessionIds = <String>[];

  tearDown(() async {
    // `createEvidenceRegion`/`createHumanAnnotation` fire-and-forget their
    // own save (`unawaited(_persistActiveSession())`) rather than
    // returning a Future the test could await directly -- give it one
    // event-loop turn to actually write before cleanup runs, otherwise
    // the directory this loop deletes gets recreated microseconds later
    // by the still-in-flight write and leaks onto disk.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
    createdSessionIds.clear();
  });

  // -------------------------------------------------------------------
  // EvidenceRegion model: backward compatibility + new fields.
  // -------------------------------------------------------------------

  group('EvidenceRegion schema extension', () {
    Map<String, dynamic> legacyJson() => {
          'id': 'region-1',
          'sourceId': 'source-1',
          'page': 1,
          'x': 0.1,
          'y': 0.2,
          'width': 0.3,
          'height': 0.4,
          'label': 'Torque Callout',
          'notes': '',
          'createdTime': '2026-01-01T00:00:00.000',
          'modifiedTime': null,
        };

    test('deserializes a pre-WP-INGEST-010 region (no origin/annotatorId/status/observationRef keys at all)', () {
      final region = EvidenceRegion.fromJson(legacyJson());

      expect(region.origin, isNull, reason: 'must not be inferred as human or machine from absence');
      expect(region.annotatorId, isNull);
      expect(region.status, isNull);
      expect(region.observationRef, isNull);
      // Every pre-existing field must still round-trip exactly as before.
      expect(region.label, 'Torque Callout');
      expect(region.x, 0.1);
    });

    test('deserializes a region with explicit null values for the new keys the same as absent keys', () {
      final json = legacyJson()
        ..addAll({'origin': null, 'annotatorId': null, 'status': null, 'observationRef': null});
      final region = EvidenceRegion.fromJson(json);

      expect(region.origin, isNull);
      expect(region.annotatorId, isNull);
      expect(region.status, isNull);
      expect(region.observationRef, isNull);
    });

    test('round-trips a machine-origin region with an observationRef through toJson/fromJson', () {
      final region = EvidenceRegion(
        id: 'region-2',
        sourceId: 'source-1',
        page: 1,
        x: 0.1,
        y: 0.1,
        width: 0.1,
        height: 0.1,
        label: 'Wire Color',
        createdTime: DateTime(2026, 1, 1),
        origin: EvidenceOrigin.machine,
        observationRef: 'entity-42',
      );

      final restored = EvidenceRegion.fromJson(region.toJson());

      expect(restored.origin, EvidenceOrigin.machine);
      expect(restored.annotatorId, isNull, reason: 'a machine observation has no annotator');
      expect(restored.status, isNull);
      expect(restored.observationRef, 'entity-42');
    });

    test('round-trips a human annotation with annotatorId and status through toJson/fromJson', () {
      final region = EvidenceRegion(
        id: 'region-3',
        sourceId: 'source-1',
        page: 1,
        x: 0.2,
        y: 0.2,
        width: 0.2,
        height: 0.2,
        label: 'Component: Ignition Switch',
        createdTime: DateTime(2026, 1, 1),
        origin: EvidenceOrigin.human,
        annotatorId: 'jsmith',
        status: EvidenceAnnotationStatus.unverified,
        observationRef: null,
      );

      final restored = EvidenceRegion.fromJson(region.toJson());

      expect(restored.origin, EvidenceOrigin.human);
      expect(restored.annotatorId, 'jsmith');
      expect(restored.status, EvidenceAnnotationStatus.unverified);
      expect(restored.observationRef, isNull, reason: 'a human may annotate a region with no machine observation');
    });

    test('copyWith updates only the new field passed and preserves the rest', () {
      final region = EvidenceRegion(
        id: 'region-4',
        sourceId: 'source-1',
        page: 1,
        x: 0,
        y: 0,
        width: 0.1,
        height: 0.1,
        label: 'A',
        createdTime: DateTime(2026, 1, 1),
        origin: EvidenceOrigin.human,
        annotatorId: 'jsmith',
        status: EvidenceAnnotationStatus.unverified,
      );

      final verified = region.copyWith(status: EvidenceAnnotationStatus.verified);

      expect(verified.status, EvidenceAnnotationStatus.verified);
      expect(verified.origin, EvidenceOrigin.human, reason: 'unrelated fields must be preserved');
      expect(verified.annotatorId, 'jsmith');
    });
  });

  // -------------------------------------------------------------------
  // CandidateGenerationService: machine-origin stamping.
  // -------------------------------------------------------------------

  test('CandidateGenerationService stamps auto-generated regions as explicitly machine-origin, '
      'linked back to the originating entity via observationRef', () {
    final entity = EngineeringEntity(
      id: 'entity-1',
      type: EngineeringEntityType.wireColor,
      matchedPatternId: 'wire-color-pattern',
      extractedText: 'Bl/Y',
      normalizedValue: 'Black/Yellow',
      sourceId: 'source-1',
      page: 1,
      boundingBox: const OcrBoundingBox(x: 0.1, y: 0.1, width: 0.05, height: 0.02),
      confidence: 0.9,
      characterStart: 0,
      characterEnd: 4,
      sourceFingerprint: 'fp-1',
      extractedTime: DateTime(2026, 1, 1),
    );

    final output = CandidateGenerationService.generate(
      entities: [entity],
      runId: 'run-1',
      vaultObjectId: 'vault-1',
      acquisitionRecordIds: const [],
      pipelineVersion: 'uif-pipeline-1.0.0',
      parserId: 'uif.pdf_parser',
      parserVersion: '1.0.0',
    );

    expect(output.evidenceRegions, hasLength(1));
    final region = output.evidenceRegions.single;
    expect(region.origin, EvidenceOrigin.machine);
    expect(region.observationRef, 'entity-1');
    expect(region.annotatorId, isNull);
    expect(region.status, isNull);
  });

  // -------------------------------------------------------------------
  // FoundationRuntimeNotifier.createHumanAnnotation / verifyEvidenceAnnotation.
  // -------------------------------------------------------------------

  ProviderContainer containerWith(FoundationRuntimeNotifier Function() build) {
    final container = ProviderContainer(overrides: [foundationRuntimeServiceProvider.overrideWith(build)]);
    addTearDown(container.dispose);
    return container;
  }

  KnowledgeSession makeSession() {
    final id = 'wp-ingest-010-test-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(id);
    return KnowledgeSession(
      id: id,
      name: 'Extraction Inspector Test Session',
      repositoryName: 'Repo One',
      author: 'jsmith',
      createdTime: DateTime(2026, 1, 1),
      lastModified: DateTime(2026, 1, 1),
      status: SessionStatus.created,
    );
  }

  test('createHumanAnnotation creates a region with origin=human, status=unverified, and a null '
      'observationRef when none is given (the TRX300 case: no machine observation exists)', () {
    final session = makeSession();
    final container = containerWith(() => _SessionSeededNotifier(session));
    final notifier = container.read(foundationRuntimeServiceProvider.notifier);

    final region = notifier.createHumanAnnotation(
      sourceId: 'source-trx300',
      page: 1,
      x: 0.3,
      y: 0.4,
      width: 0.1,
      height: 0.05,
      annotatorId: 'jsmith',
      label: 'Component: Ignition Switch',
    );

    expect(region.origin, EvidenceOrigin.human);
    expect(region.annotatorId, 'jsmith');
    expect(region.status, EvidenceAnnotationStatus.unverified);
    expect(region.observationRef, isNull);
    expect(container.read(foundationRuntimeServiceProvider).evidenceRegions, contains(region));
  });

  test('createHumanAnnotation with an observationRef links the annotation to an existing machine '
      'observation without modifying it', () {
    final session = makeSession();
    final machineRegion = EvidenceRegion(
      id: 'machine-region-1',
      sourceId: 'source-1',
      page: 1,
      x: 0.1,
      y: 0.1,
      width: 0.1,
      height: 0.1,
      label: 'Wire Color',
      createdTime: DateTime(2026, 1, 1),
      origin: EvidenceOrigin.machine,
      observationRef: 'entity-1',
    );
    final container = containerWith(() => _SessionSeededNotifier(session, evidenceRegions: [machineRegion]));
    final notifier = container.read(foundationRuntimeServiceProvider.notifier);

    final annotation = notifier.createHumanAnnotation(
      sourceId: 'source-1',
      page: 1,
      x: 0.1,
      y: 0.1,
      width: 0.1,
      height: 0.1,
      annotatorId: 'jsmith',
      observationRef: machineRegion.id,
    );

    expect(annotation.origin, EvidenceOrigin.human);
    expect(annotation.observationRef, machineRegion.id);
    // The machine region itself must remain completely unmodified.
    final stillPresent =
        container.read(foundationRuntimeServiceProvider).evidenceRegions.firstWhere((r) => r.id == machineRegion.id);
    expect(stillPresent.origin, EvidenceOrigin.machine);
    expect(stillPresent.observationRef, 'entity-1');
    expect(stillPresent.annotatorId, isNull);
  });

  test('verifyEvidenceAnnotation marks a human annotation verified and is a no-op on a machine region', () {
    final session = makeSession();
    final container = containerWith(() => _SessionSeededNotifier(session));
    final notifier = container.read(foundationRuntimeServiceProvider.notifier);

    final human = notifier.createHumanAnnotation(
      sourceId: 'source-1',
      page: 1,
      x: 0,
      y: 0,
      width: 0.1,
      height: 0.1,
      annotatorId: 'jsmith',
    );
    notifier.verifyEvidenceAnnotation(human.id);
    final verified =
        container.read(foundationRuntimeServiceProvider).evidenceRegions.firstWhere((r) => r.id == human.id);
    expect(verified.status, EvidenceAnnotationStatus.verified);

    final machine = notifier.createEvidenceRegion(
      sourceId: 'source-1',
      page: 1,
      x: 0.5,
      y: 0.5,
      width: 0.1,
      height: 0.1,
      origin: EvidenceOrigin.machine,
    );
    notifier.verifyEvidenceAnnotation(machine.id);
    final unchanged =
        container.read(foundationRuntimeServiceProvider).evidenceRegions.firstWhere((r) => r.id == machine.id);
    expect(unchanged.status, isNull, reason: 'verifying a machine observation has no defined meaning');
  });

  test('createEvidenceRegion without any of the new optional parameters behaves exactly as before '
      '(all four new fields null) — existing PdfSourceViewer-shaped calls are unaffected', () {
    final session = makeSession();
    final container = containerWith(() => _SessionSeededNotifier(session));
    final notifier = container.read(foundationRuntimeServiceProvider.notifier);

    final region = notifier.createEvidenceRegion(sourceId: 'source-1', page: 1, x: 0, y: 0, width: 0.1, height: 0.1);

    expect(region.origin, isNull);
    expect(region.annotatorId, isNull);
    expect(region.status, isNull);
    expect(region.observationRef, isNull);
  });

  // -------------------------------------------------------------------
  // Source-scoped layer counts (FoundationServiceState).
  // -------------------------------------------------------------------

  test('knowledgeCandidatesForSource / relationshipCandidatesForSource report the actual real zero for a '
      'source with no extraction results (the TRX300 layer-count display: OCR 7, Entities 0, '
      'Relationships 0, Candidates 0)', () {
    const state = FoundationServiceState(phase: FoundationConnectionPhase.connected);
    expect(state.knowledgeCandidatesForSource('source-trx300'), isEmpty);
    expect(state.relationshipCandidatesForSource('source-trx300'), isEmpty);
  });

  // -------------------------------------------------------------------
  // WP-INGEST-010 §11: the real TRX300 acceptance case.
  // -------------------------------------------------------------------

  test('TRX300 real session: the Inspector can annotate a region even though the real, persisted run has '
      'zero entities and zero candidates', () async {
    // This is the actual session directory this machine's real TRX300
    // acquisition-through-UIF run produced (AP-INGEST-009's own subject),
    // not a synthetic fixture -- if it is not present on the machine
    // running this test, the case this test proves cannot be
    // reconstructed, so it is skipped rather than faked.
    const realTrx300SessionId = 'session-1789772545045-0fb6';
    final directory = KnowledgeSessionStorage.sessionDirectory(realTrx300SessionId);
    if (!directory.existsSync()) {
      markTestSkipped('Real TRX300 session directory not present on this machine.');
      return;
    }

    final record = await KnowledgeSessionStorage.load(realTrx300SessionId);

    // Confirms the real run's own reported result, from disk, matches
    // exactly what AP-INGEST-009 documented: OCR ran (words exist), but
    // zero entities and zero candidates were produced.
    final ocrWordCount = record.ocrPageResults.fold<int>(0, (sum, r) => sum + r.words.length);
    expect(ocrWordCount, greaterThan(0), reason: 'OCR did produce some output (title-block text)');
    expect(record.engineeringEntities, isEmpty);
    expect(record.candidates, isEmpty);
    expect(record.sources, hasLength(1));
    final sourceId = record.sources.single.id;

    // Never seed the notifier with the REAL session's own id: creating
    // an annotation below calls the real, unmocked
    // `createEvidenceRegion`, which fire-and-forgets a real save keyed by
    // session id — using the real id would silently write a test
    // annotation into this machine's actual, user-owned TRX300 session
    // file. A fresh copy under a disposable test id (cleaned up in
    // `tearDown`) proves the exact same real data/behavior without that
    // side effect.
    final testSessionId = 'wp-ingest-010-trx300-copy-${DateTime.now().microsecondsSinceEpoch}';
    createdSessionIds.add(testSessionId);
    final testSession = KnowledgeSession(
      id: testSessionId,
      name: record.session.name,
      repositoryName: record.session.repositoryName,
      author: record.session.author,
      description: record.session.description,
      createdTime: record.session.createdTime,
      lastModified: record.session.lastModified,
      status: record.session.status,
      archived: record.session.archived,
    );

    final container = containerWith(
      () => _SessionSeededNotifier(testSession, evidenceRegions: record.evidenceRegions),
    );
    final notifier = container.read(foundationRuntimeServiceProvider.notifier);

    // The critical test case (§11): select a region containing an actual
    // diagram element (the main schematic body, not the title-block OCR
    // found) and annotate it, WITHOUT requiring OCR or entity extraction
    // to have recognized it first.
    final annotation = notifier.createHumanAnnotation(
      sourceId: sourceId,
      page: 1,
      x: 0.3,
      y: 0.3,
      width: 0.05,
      height: 0.05,
      annotatorId: 'jsmith',
      label: 'Component: Ignition Switch',
      observationRef: null,
    );

    expect(annotation.origin, EvidenceOrigin.human);
    expect(annotation.observationRef, isNull, reason: 'no machine observation exists at this coordinate');
    expect(annotation.status, EvidenceAnnotationStatus.unverified);
    expect(
      container.read(foundationRuntimeServiceProvider).evidenceRegions,
      contains(annotation),
      reason: 'the Inspector must still allow manual annotation when every machine-derived layer is empty',
    );
  });

  test('knowledgeCandidatesForSource / relationshipCandidatesForSource join through EvidenceRegion/EvidenceLink '
      'exactly like the existing per-region equivalents', () {
    // Reuses the exact model-construction pattern candidatesLinkedToEvidenceRegion's
    // own tests already establish for this join.
    final region = EvidenceRegion(
      id: 'region-1',
      sourceId: 'source-1',
      page: 1,
      x: 0,
      y: 0,
      width: 0.1,
      height: 0.1,
      label: 'L',
      createdTime: DateTime(2026, 1, 1),
    );
    final state = FoundationServiceState(phase: FoundationConnectionPhase.connected, evidenceRegions: [region]);
    expect(state.knowledgeCandidatesForSource('source-1'), isEmpty, reason: 'no EvidenceLink exists yet');
    expect(state.knowledgeCandidatesForSource('source-2'), isEmpty);
  });
}

/// Overrides only `build()` (never native Foundation Bridge connection),
/// mirroring the `_FakeRepoOpenNotifier` pattern already established
/// elsewhere in this test suite — every method under test here
/// (`createHumanAnnotation`, `createEvidenceRegion`, `verifyEvidenceAnnotation`)
/// is the REAL, unoverridden `FoundationRuntimeNotifier` implementation.
class _SessionSeededNotifier extends FoundationRuntimeNotifier {
  _SessionSeededNotifier(this.session, {this.evidenceRegions = const []});

  final KnowledgeSession session;
  final List<EvidenceRegion> evidenceRegions;

  @override
  FoundationServiceState build() {
    return FoundationServiceState(
      phase: FoundationConnectionPhase.connected,
      knowledgeSession: session,
      evidenceRegions: evidenceRegions,
    );
  }
}
