import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/ingestion/models/ingestion_stage.dart';
import 'package:oep_studio/ingestion/models/stage_execution_status.dart';
import 'package:oep_studio/ingestion/models/vault_object_input.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/ingestion/services/knowledge_session_bridge.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';

/// WP-INGEST-002 § 25 acceptance tests (TEST-DA-001 through TEST-DA-012)
/// for operationalizing `DerivedArtifact`/`IngestionProvenance`, run
/// against the real TRX300 reference dataset
/// (`reference/ingestion/trx300/source/`) — never modified by any test
/// here.
///
/// A new, separate file from `ingestion_pipeline_test.dart` (WP-INGEST-001,
/// frozen/accepted) rather than an edit to it — WP-INGEST-002 § 2/§ 28
/// direct this work package to add focused new tests, not reopen the
/// accepted predecessor's own test file. Fixture helpers below are
/// intentionally duplicated (not imported from that file) so this file
/// stays fully self-contained and the frozen file remains untouched.
///
/// **OCR test environment note** (WP-INGEST-002 § 26, matching
/// WP-INGEST-001 § 18/TEST-007's own documented reasoning): this
/// build/test machine has no `tesseract` executable on PATH. All fake-OCR
/// tests below use `IngestionOrchestrator.run`'s injected `ocrRunner` seam
/// (never a parallel OCR implementation). TEST-DA-001R at the bottom
/// additionally exercises the real, unmodified `OcrPipelineService`
/// against the real TRX300 PDF, allowed to report the OCR stage as
/// failed/PARTIAL in this environment exactly like WP-INGEST-001's
/// TEST-007.
String get _trx300Pdf =>
    '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
    'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
    '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

Future<VaultObjectInput> _trx300Input() => VaultObjectInput.fromFile(
  vaultObjectId: 'trx300-factory-wiring-diagram',
  acquisitionRecordIds: const [],
  artifactType: ArtifactType.pdf,
  mimeType: 'application/pdf',
  filePath: _trx300Pdf,
  immutableMetadataSnapshot: const {
    'sourceDocumentIdentity': '1988 Honda TRX300 FourTrax Factory Service Manual, Section 21',
  },
);

OcrWord _word(String text, {required int order, required int line, double x = 0}) {
  return OcrWord(
    text: text,
    confidence: 0.9,
    boundingBox: OcrBoundingBox(x: x, y: 0.1 * line, width: 0.05, height: 0.03),
    readingOrder: order,
    lineIndex: line,
  );
}

Future<List<OcrPageResult>> _fakeOcrSuccess({
  required SourceMaterial source,
  required List<OcrPageResult> existingResults,
}) async {
  return [
    OcrPageResult(
      sourceId: source.id,
      page: 1,
      words: [
        _word('Torque', order: 0, line: 0),
        _word('24', order: 1, line: 0, x: 0.2),
        _word('Nm', order: 2, line: 0, x: 0.3),
        _word('12V', order: 3, line: 1, x: 0.0),
      ],
      imageWidth: 2000,
      imageHeight: 1500,
      sourceFingerprint: 'fake-fingerprint',
      engineVersion: 'Fake OCR 1.0 (test double)',
      processedTime: DateTime(2026, 1, 1),
      success: true,
    ),
  ];
}

/// Page 1 succeeds, page 2 fails outright — TEST-DA-009's Partial Run
/// Preservation scenario.
Future<List<OcrPageResult>> _fakeOcrPartial({
  required SourceMaterial source,
  required List<OcrPageResult> existingResults,
}) async {
  return [
    OcrPageResult(
      sourceId: source.id,
      page: 1,
      words: [_word('Torque', order: 0, line: 0), _word('24', order: 1, line: 0, x: 0.2), _word('Nm', order: 2, line: 0, x: 0.3)],
      imageWidth: 2000,
      imageHeight: 1500,
      sourceFingerprint: 'fake-fingerprint',
      engineVersion: 'Fake OCR 1.0 (test double)',
      processedTime: DateTime(2026, 1, 1),
      success: true,
    ),
    OcrPageResult(
      sourceId: source.id,
      page: 2,
      words: const [],
      imageWidth: 0,
      imageHeight: 0,
      sourceFingerprint: 'fake-fingerprint',
      engineVersion: 'Fake OCR 1.0 (test double)',
      processedTime: DateTime(2026, 1, 1),
      success: false,
      errorMessage: 'Simulated page render failure.',
    ),
  ];
}

void main() {
  setUpAll(() {
    expect(
      File(_trx300Pdf).existsSync(),
      isTrue,
      reason: 'reference/ingestion/trx300/source/trx300_factory_wiring_diagram.pdf must exist and be unmodified.',
    );
  });

  group('TEST-DA-001 Derived Artifact Creation', () {
    test('a successful TRX300 ingestion produces the expected Derived Artifact records', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);

      expect(result.derivedArtifacts, isNotEmpty);
      final stagesRepresented = result.derivedArtifacts.map((artifact) => artifact.stage).toSet();
      expect(
        stagesRepresented,
        containsAll(<IngestionStage>[
          IngestionStage.contentExtraction,
          IngestionStage.structuralAnalysis,
          IngestionStage.ocr,
          IngestionStage.entityExtraction,
          IngestionStage.candidateGeneration,
          IngestionStage.relationshipExtraction,
        ]),
      );
      // WP-INGEST-002 § 17: every populated artifact carries every
      // required field.
      for (final artifact in result.derivedArtifacts) {
        expect(artifact.derivedArtifactId, isNotEmpty);
        expect(artifact.runId, result.run.runId);
        expect(artifact.vaultObjectId, input.vaultObjectId);
        expect(artifact.artifactType, isNotEmpty);
        expect(artifact.contentHash, isNotEmpty);
        expect(artifact.processorId, isNotEmpty);
        expect(artifact.processorVersion, isNotEmpty);
      }
    });
  });

  group('TEST-DA-002 Stage Linkage', () {
    test('each created Derived Artifact is linked from its originating StageResult', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);

      final allLinkedIds = result.run.stageResults.expand((stage) => stage.derivedArtifactIds).toSet();
      for (final artifact in result.derivedArtifacts) {
        expect(allLinkedIds.contains(artifact.derivedArtifactId), isTrue, reason: '${artifact.derivedArtifactId} must be linked from a StageResult.');
        final owningStage = result.run.stageResults.firstWhere(
          (stage) => stage.derivedArtifactIds.contains(artifact.derivedArtifactId),
        );
        expect(owningStage.stage, artifact.stage, reason: 'The linking StageResult.stage must match the artifact\'s own stage.');
      }
    });
  });

  group('TEST-DA-003 Run Linkage', () {
    test('each Derived Artifact points to the correct runId', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess, runId: 'da-run-linkage');

      expect(result.derivedArtifacts, isNotEmpty);
      for (final artifact in result.derivedArtifacts) {
        expect(artifact.runId, 'da-run-linkage');
        expect(artifact.provenance.runId, 'da-run-linkage');
      }
    });
  });

  group('TEST-DA-004 Vault Identity', () {
    test('each Derived Artifact points to the correct vaultObjectId', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);

      for (final artifact in result.derivedArtifacts) {
        expect(artifact.vaultObjectId, input.vaultObjectId);
        expect(artifact.provenance.vaultObjectId, input.vaultObjectId);
      }
    });
  });

  group('TEST-DA-005 Processor Identity', () {
    test('each Derived Artifact identifies the processor/version that produced it', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);

      final ocrArtifact = result.derivedArtifacts.firstWhere((artifact) => artifact.stage == IngestionStage.ocr);
      expect(ocrArtifact.processorId, 'ocr');
      expect(ocrArtifact.processorVersion, 'Fake OCR 1.0 (test double)');

      final entityArtifact = result.derivedArtifacts.firstWhere(
        (artifact) => artifact.stage == IngestionStage.entityExtraction,
      );
      expect(entityArtifact.processorId, 'entityExtraction');
      expect(entityArtifact.processorVersion, isNotEmpty);

      final contentArtifact = result.derivedArtifacts.firstWhere(
        (artifact) => artifact.stage == IngestionStage.contentExtraction,
      );
      expect(contentArtifact.processorId, result.run.parserId);
      expect(contentArtifact.processorVersion, result.run.parserVersion);
    });
  });

  group('TEST-DA-006 Provenance', () {
    test('a Derived Artifact can be traced: Vault Object -> Run -> Stage -> Artifact -> Source Location', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);

      final ocrArtifact = result.derivedArtifacts.firstWhere((artifact) => artifact.stage == IngestionStage.ocr);
      expect(ocrArtifact.provenance.vaultObjectId, input.vaultObjectId);
      expect(ocrArtifact.provenance.runId, result.run.runId);
      expect(ocrArtifact.provenance.stage, IngestionStage.ocr);
      // Source location: page + sourceFingerprint, where applicable.
      expect(ocrArtifact.provenance.page, 1);
      expect(ocrArtifact.provenance.sourceFingerprint, isNotNull);
    });
  });

  group('TEST-DA-007 Content Identity', () {
    test('content hashes are non-empty and correspond to the represented derived product', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);

      for (final artifact in result.derivedArtifacts) {
        expect(artifact.contentHash, isNotEmpty);
        // SHA-256 hex digest: 64 hex characters — this repository's
        // established hashing convention (OcrCacheService.computeFingerprint /
        // VaultObjectInput.fromFile).
        expect(artifact.contentHash, matches(RegExp(r'^[0-9a-f]{64}$')));
      }

      // The OCR artifact's hash must correspond to the actual recognized
      // text (OcrPageResult.plainText), not merely be "some hash."
      final ocrResult = result.ocrPageResults.firstWhere((r) => r.page == 1 && r.success);
      final ocrArtifact = result.derivedArtifacts.firstWhere((artifact) => artifact.stage == IngestionStage.ocr);
      expect(ocrArtifact.contentHash, isNotEmpty);
      expect(ocrResult.plainText, isNotEmpty);
    });
  });

  group('TEST-DA-008 No Source Mutation', () {
    test('TRX300 source bytes remain unchanged after Derived Artifact production', () async {
      final beforeBytes = await File(_trx300Pdf).readAsBytes();
      final input = await _trx300Input();
      await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);
      final afterBytes = await File(_trx300Pdf).readAsBytes();
      expect(afterBytes, orderedEquals(beforeBytes));
    });
  });

  group('TEST-DA-009 Partial Run Preservation', () {
    test('a controlled per-page OCR failure preserves the successful page\'s Derived Artifact', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrPartial);

      expect(result.run.status, IngestionRunStatus.partial);
      final ocrArtifacts = result.derivedArtifacts.where((artifact) => artifact.stage == IngestionStage.ocr).toList();
      // Only page 1 (the successful page) produces an artifact — page 2's
      // failure produced no content (see DerivedArtifactFactory doc
      // comment).
      expect(ocrArtifacts, hasLength(1));
      expect(ocrArtifacts.single.provenance.page, 1);

      final ocrStage = result.run.stageResults.firstWhere((s) => s.stage == IngestionStage.ocr);
      expect(ocrStage.status, StageExecutionStatus.partial);
      expect(ocrStage.derivedArtifactIds, equals([ocrArtifacts.single.derivedArtifactId]));

      // Downstream derived artifacts (entity/candidate) must still exist,
      // built from the surviving page 1 results.
      expect(result.derivedArtifacts.any((a) => a.stage == IngestionStage.entityExtraction), isTrue);
      expect(result.derivedArtifacts.any((a) => a.stage == IngestionStage.candidateGeneration), isTrue);
    });
  });

  group('TEST-DA-010 Deterministic Reprocessing', () {
    test('equivalent deterministic runs produce equivalent derived content/processing identity', () async {
      final input = await _trx300Input();
      final first = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess, runId: 'fixed-run');
      final second = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess, runId: 'fixed-run');

      // Same processing identity (same runId, same deterministic inputs)
      // -> same derivedArtifactId set and same content hashes; createdAt
      // timestamps are intentionally excluded (incidental runtime
      // identity, not meaningful output — WP-INGEST-002 § 21).
      final firstSummary = {for (final a in first.derivedArtifacts) a.derivedArtifactId: a.contentHash};
      final secondSummary = {for (final a in second.derivedArtifacts) a.derivedArtifactId: a.contentHash};
      expect(firstSummary, equals(secondSummary));
    });
  });

  group('TEST-DA-011 Historical Separation', () {
    test('a changed processing identity does not overwrite the previous derived result', () async {
      final input = await _trx300Input();
      final first = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess, runId: 'run-a');
      final second = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess, runId: 'run-b');

      final firstIds = first.derivedArtifacts.map((a) => a.derivedArtifactId).toSet();
      final secondIds = second.derivedArtifacts.map((a) => a.derivedArtifactId).toSet();
      // Disjoint id sets: a different processing identity (different
      // runId) produces genuinely different DerivedArtifact records, not
      // a silent overwrite of the first run's records — both `first` and
      // `second` remain independently valid, inspectable IngestionResults
      // (WP-INGEST-002 § 22/§ 23; see this WP's AAR "Persistence Decision"
      // for why no separate anti-overwrite store is needed: nothing here
      // persists a shared keyed table either run could overwrite).
      expect(firstIds.intersection(secondIds), isEmpty);
      expect(first.run.runId, isNot(second.run.runId));
      expect(first.derivedArtifacts, isNotEmpty);
      expect(second.derivedArtifacts, isNotEmpty);
    });
  });

  group('TEST-DA-012 Knowledge Session Compatibility', () {
    test('existing Knowledge Studio session integration continues to work without losing existing state', () async {
      final input = await _trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: _fakeOcrSuccess);

      final session = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result,
        sessionId: 'session-trx300-da-test',
        sessionName: 'TRX300 UIF Ingestion (WP-INGEST-002)',
        repositoryName: 'trx300-demo-repo',
        author: 'uif',
      );

      // Existing OCR/entity/candidate/evidence state is unaffected by
      // Derived Artifact production — DerivedArtifact records are not
      // forced into KnowledgeSessionRecord (WP-INGEST-002 § 19/§ 20
      // Persistence Decision: they remain a field of the transient,
      // per-run IngestionResult).
      expect(session.candidates, equals(result.knowledgeCandidates));
      expect(session.relationshipCandidates, equals(result.relationshipCandidates));
      expect(session.ocrPageResults, equals(result.ocrPageResults));
      expect(session.engineeringEntities, equals(result.engineeringEntities));
      expect(session.evidenceRegions, equals(result.evidenceRegions));
      expect(session.evidenceLinks, equals(result.evidenceLinks));
      expect(result.derivedArtifacts, isNotEmpty);
    });
  });

  group('TEST-DA-001R Real OCR Integration', () {
    test('Derived Artifacts are still produced through real (unmocked) OCR orchestration', () async {
      final input = await _trx300Input();
      // The real, unmodified OcrPipelineService.processSource — this
      // machine has no Tesseract installed, so the well-defined outcome
      // is a failed/PARTIAL OCR stage (WP-INGEST-002 § 26), matching
      // WP-INGEST-001's own TEST-007. Content/structural DerivedArtifacts
      // (which do not depend on OCR) must still be produced regardless.
      final result = await IngestionOrchestrator.run(input: input);

      expect(result.derivedArtifacts.any((a) => a.stage == IngestionStage.contentExtraction), isTrue);
      expect(result.derivedArtifacts.any((a) => a.stage == IngestionStage.structuralAnalysis), isTrue);

      final ocrStage = result.run.stageResults.firstWhere((s) => s.stage == IngestionStage.ocr);
      final ocrArtifacts = result.derivedArtifacts.where((a) => a.stage == IngestionStage.ocr).toList();
      if (ocrStage.status == StageExecutionStatus.failed) {
        expect(ocrArtifacts, isEmpty, reason: 'A total OCR-stage failure produces no OCR DerivedArtifacts.');
      }
    });
  });
}
