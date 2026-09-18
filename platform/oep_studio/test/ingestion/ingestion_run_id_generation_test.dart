import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';
import 'package:oep_studio/ingestion/models/vault_object_input.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/ingestion/services/knowledge_session_bridge.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// INGEST-FOLLOWUP-004 acceptance tests (TEST-RUNID-001 through
/// TEST-RUNID-007): fixes the defect where `IngestionOrchestrator.run`
/// defaulted an omitted `runId` to `'run-${contentHash.substring(0, 16)}'`
/// -- meaning two separate executions of identical evidence collided on
/// the same execution id. `runId` (execution-attempt identity) and
/// `IngestionRun.processingIdentity` (evidence + processing-definition
/// identity, frozen by INGEST-FOLLOWUP-003) must stay fully independent:
/// identical evidence may be executed repeatedly, and every execution
/// attempt must receive its own unique `runId`, while `processingIdentity`
/// legitimately stays identical across those attempts.
///
/// Structured like `ingestion_execution_lifecycle_test.dart`
/// (WP-INGEST-007): only the `OcrRunner` injection seam is faked; the real
/// `IngestionOrchestrator` and `IngestionKnowledgeSessionBridge` both run
/// unmodified.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  final createdSessionIds = <String>[];

  tearDown(() async {
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
    createdSessionIds.clear();
  });

  Future<VaultObjectInput> trx300Input({String vaultObjectId = 'trx300-runid'}) => VaultObjectInput.fromFile(
    vaultObjectId: vaultObjectId,
    acquisitionRecordIds: const [],
    artifactType: ArtifactType.pdf,
    mimeType: 'application/pdf',
    filePath: trx300Path,
    immutableMetadataSnapshot: const {},
  );

  Future<List<OcrPageResult>> fakeOcrSuccess({
    required SourceMaterial source,
    required List<OcrPageResult> existingResults,
  }) async {
    return [
      OcrPageResult(
        sourceId: source.id,
        page: 1,
        words: [
          OcrWord(
            text: 'Torque',
            confidence: 0.9,
            boundingBox: const OcrBoundingBox(x: 0, y: 0, width: 0.05, height: 0.03),
            readingOrder: 0,
            lineIndex: 0,
          ),
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

  group('TEST-RUNID-001 Explicit runId preserved exactly', () {
    test('an explicit runId passed to run() is unchanged in the resulting IngestionRun.runId', () async {
      final input = await trx300Input(vaultObjectId: 'wp-runid-001');
      const explicitRunId = 'explicit-runid-001-exact';

      final result = await IngestionOrchestrator.run(input: input, runId: explicitRunId, ocrRunner: fakeOcrSuccess);

      expect(result.run.runId, explicitRunId);
    });
  });

  group('TEST-RUNID-002/003 Automatically-generated runIds are unique and non-empty', () {
    test('two run() calls with identical evidence and no explicit runId get different runIds', () async {
      final inputA = await trx300Input(vaultObjectId: 'wp-runid-002');
      final inputB = await trx300Input(vaultObjectId: 'wp-runid-002');

      final runA = await IngestionOrchestrator.run(input: inputA, ocrRunner: fakeOcrSuccess);
      final runB = await IngestionOrchestrator.run(input: inputB, ocrRunner: fakeOcrSuccess);

      // TEST-RUNID-002.
      expect(runA.run.runId, isNot(runB.run.runId));
      // TEST-RUNID-003: both are non-empty, real ids -- not a defaulted
      // empty string.
      expect(runA.run.runId, isNotEmpty);
      expect(runB.run.runId, isNotEmpty);
      // The specific bug being fixed: the default must not be derived
      // from contentHash.
      expect(runA.run.runId, isNot(contains(inputA.contentHash.substring(0, 16))));
      expect(runB.run.runId, isNot(contains(inputB.contentHash.substring(0, 16))));
    });
  });

  group('TEST-RUNID-004/005 processingIdentity independent of runId', () {
    test('two runs with different auto-generated runIds share the same processingIdentity', () async {
      final inputA = await trx300Input(vaultObjectId: 'wp-runid-004');
      final inputB = await trx300Input(vaultObjectId: 'wp-runid-004');

      final runA = await IngestionOrchestrator.run(input: inputA, ocrRunner: fakeOcrSuccess);
      final runB = await IngestionOrchestrator.run(input: inputB, ocrRunner: fakeOcrSuccess);

      expect(runA.run.runId, isNot(runB.run.runId));
      expect(runA.run.processingIdentity, runB.run.processingIdentity);
    });

    test('different explicit runIds for otherwise-identical inputs do not change processingIdentity', () async {
      final inputA = await trx300Input(vaultObjectId: 'wp-runid-005');
      final inputB = await trx300Input(vaultObjectId: 'wp-runid-005');

      final runA = await IngestionOrchestrator.run(
        input: inputA,
        runId: 'explicit-runid-005-a',
        ocrRunner: fakeOcrSuccess,
      );
      final runB = await IngestionOrchestrator.run(
        input: inputB,
        runId: 'explicit-runid-005-b',
        ocrRunner: fakeOcrSuccess,
      );

      expect(runA.run.runId, isNot(runB.run.runId));
      expect(runA.run.processingIdentity, runB.run.processingIdentity);
    });
  });

  group('TEST-RUNID-006/007 Retries remain distinct historical executions', () {
    test('two auto-generated-runId executions of identical evidence both appear in ingestionRuns, in-memory merge', () async {
      final inputA = await trx300Input(vaultObjectId: 'wp-runid-006');
      final inputB = await trx300Input(vaultObjectId: 'wp-runid-006');

      final runA = await IngestionOrchestrator.run(input: inputA, ocrRunner: fakeOcrSuccess);
      final runB = await IngestionOrchestrator.run(input: inputB, ocrRunner: fakeOcrSuccess);
      expect(runA.run.runId, isNot(runB.run.runId));

      final sessionId = KnowledgeSessionService.generateId('session');
      createdSessionIds.add(sessionId);
      var record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: runA,
        sessionId: sessionId,
        sessionName: 'TEST-RUNID-006',
        repositoryName: 'repo',
        author: 'author',
      );
      record = IngestionKnowledgeSessionBridge.mergeInto(record, runB);

      // TEST-RUNID-006: both executions are distinct, separate historical
      // entries -- neither overwrote the other.
      expect(record.ingestionRuns, hasLength(2));
      expect(record.ingestionRuns.map((run) => run.runId).toSet(), {runA.run.runId, runB.run.runId});
    });

    test('two auto-generated-runId executions survive a real persist+reload round-trip as separate records', () async {
      final inputA = await trx300Input(vaultObjectId: 'wp-runid-007');
      final inputB = await trx300Input(vaultObjectId: 'wp-runid-007');

      final runA = await IngestionOrchestrator.run(input: inputA, ocrRunner: fakeOcrSuccess);
      final runB = await IngestionOrchestrator.run(input: inputB, ocrRunner: fakeOcrSuccess);
      expect(runA.run.runId, isNot(runB.run.runId));

      final sessionId = KnowledgeSessionService.generateId('session');
      createdSessionIds.add(sessionId);
      var record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: runA,
        sessionId: sessionId,
        sessionName: 'TEST-RUNID-007',
        repositoryName: 'repo',
        author: 'author',
      );
      record = IngestionKnowledgeSessionBridge.mergeInto(record, runB);
      await KnowledgeSessionStorage.save(record);

      final reloaded = await KnowledgeSessionStorage.load(sessionId);

      // TEST-RUNID-007: the real persist+reload path -- not one run
      // replacing the other because of an id collision.
      expect(reloaded.ingestionRuns, hasLength(2));
      expect(reloaded.ingestionRuns.map((run) => run.runId).toSet(), {runA.run.runId, runB.run.runId});
    });
  });
}
