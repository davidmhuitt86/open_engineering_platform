import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_client.dart';
import 'package:oep_studio/acquisition/services/reference_vault_ingestion_workflow.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';
import 'package:oep_studio/ingestion/models/ingestion_run.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/ingestion/models/vault_object_input.dart';
import 'package:oep_studio/ingestion/services/ingestion_cancellation_token.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/ingestion/services/knowledge_session_bridge.dart';
import 'package:oep_studio/knowledge/models/document_orientation.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_service.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-007 § 30-37 acceptance tests (TEST-007-001 through
/// TEST-007-020, plus the § 31 cancellation tests) for the ingestion
/// execution lifecycle: a run must exist, persisted, before meaningful
/// execution begins; it must progress QUEUED -> RUNNING -> a terminal
/// status; interrupted RUNNING executions must reconcile to FAILED on
/// reload with an explicit diagnostic; retries must never erase history;
/// and none of this may touch Reference Vault or Engineering Repository
/// infrastructure.
///
/// Structured like `ingestion_run_provenance_persistence_test.dart`
/// (WP-INGEST-006): only `AcquisitionApiClient`'s HTTP transport is
/// faked; the real `ReferenceVaultAdapter`, `IngestionOrchestrator`, and
/// `IngestionKnowledgeSessionBridge` all run unmodified. OCR is faked
/// through the existing `OcrRunner` injection seam (this build/test
/// machine has no `tesseract` executable).
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  const vaultId = 'wp-ingest-007-vault-entry-0001';

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

  Future<VaultObjectInput> trx300Input({String vaultObjectId = 'trx300-lifecycle'}) => VaultObjectInput.fromFile(
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

  // Same deterministic per-page-failure fake every prior WP-INGEST test
  // suite already uses -- page 1 succeeds, page 2 fails outright.
  Future<List<OcrPageResult>> fakeOcrPartial({
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

  AcquisitionApiClient buildClient({required List<int> bytes, required String checksum, String mimeType = 'application/pdf'}) {
    return AcquisitionApiClient(
      baseUrl: 'http://fake-eam/api',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/vault/$vaultId/artifact')) {
          return http.Response.bytes(bytes, 200, headers: {'x-checksum-sha256': checksum, 'content-type': mimeType});
        }
        if (path.endsWith('/vault/$vaultId')) {
          return http.Response(
            jsonEncode({
              'id': vaultId,
              'metadata_id': 'metadata-1',
              'verification_id': 'verification-1',
              'download_session_id': 'download-1',
              'source_id': 'source-1',
              'sha256_hash': checksum,
              'mime_type': mimeType,
              'file_size_bytes': bytes.length,
              'status': 'Published',
              'published_at': '2026-01-01T00:00:00Z',
              'created_at': '2026-01-01T00:00:00Z',
            }),
            200,
          );
        }
        if (path.endsWith('/acquisition-records')) {
          return http.Response(
            jsonEncode([
              {'id': 'acq-record-1', 'download_session_id': 'download-1', 'status': 'Published'},
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
      tokenReader: () async => 'test-token',
    );
  }

  setUpAll(() {
    expect(
      File(trx300Path).existsSync(),
      isTrue,
      reason: 'reference/ingestion/trx300/source/trx300_factory_wiring_diagram.pdf must exist and be unmodified.',
    );
  });

  group('TEST-007-001/002 Run exists and transitions before execution completes', () {
    test('the run is persisted QUEUED, reloadable from disk, before any stage executes, then transitions to RUNNING',
        () async {
      final input = await trx300Input();
      final sessionId = KnowledgeSessionService.generateId('session');
      createdSessionIds.add(sessionId);
      final capturedStatuses = <IngestionRunStatus>[];
      KnowledgeSessionRecord? record;

      Future<void> lifecycle(IngestionRun run) async {
        capturedStatuses.add(run.status);
        record = record == null
            ? IngestionKnowledgeSessionBridge.createQueuedSessionRecord(
                sessionId: sessionId,
                sessionName: 'lifecycle-test',
                repositoryName: 'repo',
                author: 'author',
                queuedRun: run,
              )
            : IngestionKnowledgeSessionBridge.withUpdatedRun(record!, run);
        await KnowledgeSessionStorage.save(record!);
        if (run.status == IngestionRunStatus.queued) {
          // TEST-007-001: the QUEUED run is durably on disk before
          // `IngestionOrchestrator.run` proceeds any further -- read the
          // raw file directly rather than through
          // `KnowledgeSessionStorage.load`, since *that* real load path
          // is deliberately the point at which a non-terminal run is
          // reconciled to FAILED (WP-INGEST-007 § 14/§ 35) on the
          // assumption that a fresh load of a QUEUED/RUNNING run means
          // the process that owned it is gone -- not true here, where
          // this very process is still actively running it.
          final raw = jsonDecode(
            await File(
              '${KnowledgeSessionStorage.sessionDirectory(sessionId).path}${Platform.pathSeparator}session.json',
            ).readAsString(),
          ) as Map<String, dynamic>;
          final persistedRuns = raw['ingestionRuns'] as List;
          expect(persistedRuns, hasLength(1));
          expect((persistedRuns.single as Map)['status'], 'queued');
        }
      }

      final result = await IngestionOrchestrator.run(
        input: input,
        ocrRunner: fakeOcrSuccess,
        onLifecycleUpdate: lifecycle,
      );

      // TEST-007-002: QUEUED -> RUNNING was observed, in order, before
      // the terminal status.
      expect(capturedStatuses, [IngestionRunStatus.queued, IngestionRunStatus.running]);
      expect(result.run.status.isTerminal, isTrue);
    });
  });

  group('TEST-007-003 COMPLETED persists', () {
    test('a successful ingestion persists COMPLETED', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-003',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isCompleted, isTrue);
      createdSessionIds.add(outcome.sessionRecord!.session.id);
      final reloaded = await KnowledgeSessionStorage.load(outcome.sessionRecord!.session.id);
      expect(reloaded.ingestionRuns.single.status, IngestionRunStatus.completed);
    });
  });

  group('TEST-007-004 PARTIAL persists', () {
    test('a partially-successful ingestion persists PARTIAL', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-004',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrPartial,
      );

      expect(outcome.isPartial, isTrue);
      createdSessionIds.add(outcome.sessionRecord!.session.id);
      final reloaded = await KnowledgeSessionStorage.load(outcome.sessionRecord!.session.id);
      expect(reloaded.ingestionRuns.single.status, IngestionRunStatus.partial);
    });
  });

  group('TEST-007-005 FAILED persists', () {
    test('a parser failure persists FAILED as durable history', () async {
      final bytes = utf8.encode('not a real pdf at all');
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-005',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isTrue);
      expect(outcome.sessionRecord, isNull, reason: 'a failed ingestion is never presented as reviewable');

      final runId = outcome.ingestionResult!.run.runId;
      final matches = KnowledgeSessionStorage.root().listSync().whereType<Directory>().where((dir) {
        final file = File('${dir.path}${Platform.pathSeparator}session.json');
        return file.existsSync() && file.readAsStringSync().contains(runId);
      });
      expect(matches, isNotEmpty);
      for (final dir in matches) {
        createdSessionIds.add(dir.uri.pathSegments.where((segment) => segment.isNotEmpty).last);
      }
      final sessionId = matches.first.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      final reloaded = await KnowledgeSessionStorage.load(sessionId);
      expect(reloaded.ingestionRuns.single.status, IngestionRunStatus.failed);
    });
  });

  group('TEST-007-006 CANCELLED persists', () {
    test('an explicit cancellation requested before execution persists CANCELLED, not FAILED', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);
      final token = IngestionCancellationToken()..cancel();

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-006',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
        cancellationToken: token,
      );

      expect(outcome.isCancelled, isTrue);
      expect(outcome.isFailed, isFalse, reason: 'cancellation must never be conflated with failure');
      expect(outcome.sessionRecord, isNull);

      final runId = outcome.ingestionResult!.run.runId;
      final matches = KnowledgeSessionStorage.root().listSync().whereType<Directory>().where((dir) {
        final file = File('${dir.path}${Platform.pathSeparator}session.json');
        return file.existsSync() && file.readAsStringSync().contains(runId);
      });
      expect(matches, isNotEmpty);
      for (final dir in matches) {
        createdSessionIds.add(dir.uri.pathSegments.where((segment) => segment.isNotEmpty).last);
      }
      final sessionId = matches.first.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      final reloaded = await KnowledgeSessionStorage.load(sessionId);
      expect(reloaded.ingestionRuns.single.status, IngestionRunStatus.cancelled);
      // Cancellation does not become FAILED, and carries no interruption
      // diagnostic (that diagnostic is reserved for
      // `reconciledIfInterrupted`, never for intentional cancellation).
      expect(reloaded.ingestionRuns.single.diagnostics, isNot(contains(IngestionRun.interruptionDiagnostic)));
    });
  });

  group('TEST-007-006b Cancellation during execution', () {
    test('a cancellation requested mid-execution stops at the next safe point, preserving completed stage results',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);
      final token = IngestionCancellationToken();

      // Cancel from inside the OCR fake itself -- by the time this runs,
      // IDENTIFY/PARSER_SELECTION/METADATA/CONTENT/STRUCTURAL have
      // already completed, so the checkpoint right after OCR is the
      // "next safe point" that actually observes the cancellation.
      Future<List<OcrPageResult>> cancellingOcr({
        required SourceMaterial source,
        required List<OcrPageResult> existingResults,
      }) async {
        token.cancel();
        return fakeOcrSuccess(source: source, existingResults: existingResults);
      }

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-006b',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: cancellingOcr,
        cancellationToken: token,
      );

      expect(outcome.isCancelled, isTrue);
      final run = outcome.ingestionResult!.run;
      expect(run.status, IngestionRunStatus.cancelled);
      // Stages that already completed (through OCR) are preserved, not
      // discarded or rolled back.
      expect(run.stageResults, isNotEmpty);
      expect(outcome.ingestionResult!.structuralData.pages, isNotEmpty);
      expect(outcome.ingestionResult!.ocrPageResults, isNotEmpty);

      final matches = KnowledgeSessionStorage.root().listSync().whereType<Directory>().where((dir) {
        final file = File('${dir.path}${Platform.pathSeparator}session.json');
        return file.existsSync() && file.readAsStringSync().contains(run.runId);
      });
      for (final dir in matches) {
        createdSessionIds.add(dir.uri.pathSegments.where((segment) => segment.isNotEmpty).last);
      }
    });
  });

  group('TEST-007-007/008 Run and stage history survive reload', () {
    test('a persisted run and its full stage history survive a KnowledgeSessionStorage reload', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-007',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrPartial,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);

      final original = record.ingestionRuns.single;
      final persisted = reloaded.ingestionRuns.single;
      expect(persisted.runId, original.runId);
      expect(persisted.status, original.status);
      expect(persisted.stageResults, hasLength(original.stageResults.length));
      for (var i = 0; i < original.stageResults.length; i++) {
        expect(persisted.stageResults[i].stage, original.stageResults[i].stage);
        expect(persisted.stageResults[i].status, original.stageResults[i].status);
        expect(persisted.stageResults[i].diagnostics, original.stageResults[i].diagnostics);
      }
    });
  });

  group('TEST-007-009/010 Interrupted RUNNING execution reconciles to FAILED with a diagnostic', () {
    test('a run persisted only as far as RUNNING is reconciled to FAILED, with an interruption diagnostic, on reload',
        () async {
      final input = await trx300Input(vaultObjectId: 'trx300-interrupted');
      final sessionId = KnowledgeSessionService.generateId('session');
      createdSessionIds.add(sessionId);

      // Simulate the application terminating mid-ingestion: persist
      // QUEUED, persist RUNNING, and then simply never persist anything
      // else again -- exactly what `IngestionOrchestrator.run`'s two
      // `onLifecycleUpdate` calls produce if the process disappears
      // before returning. Never directly construct/persist a FAILED
      // status -- the whole point is to exercise reconciliation through
      // the real `KnowledgeSessionStorage.load` path (WP-INGEST-007
      // § 35).
      final queuedRun = IngestionRun(
        runId: 'interrupted-run-1',
        vaultObjectId: input.vaultObjectId,
        contentHash: input.contentHash,
        startedAt: DateTime.now(),
        status: IngestionRunStatus.queued,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'none',
        parserVersion: 'none',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: const [],
      );
      var record = IngestionKnowledgeSessionBridge.createQueuedSessionRecord(
        sessionId: sessionId,
        sessionName: 'TEST-007-009',
        repositoryName: 'repo',
        author: 'author',
        queuedRun: queuedRun,
      );
      await KnowledgeSessionStorage.save(record);

      final runningRun = queuedRun.transitionTo(IngestionRunStatus.running);
      record = IngestionKnowledgeSessionBridge.withUpdatedRun(record, runningRun);
      await KnowledgeSessionStorage.save(record);

      // "Application terminates" -- nothing else is ever persisted.
      // The next thing that happens is a fresh load, exactly like the
      // application restarting.
      final reloaded = await KnowledgeSessionStorage.load(sessionId);

      expect(reloaded.ingestionRuns, hasLength(1));
      final reconciled = reloaded.ingestionRuns.single;
      // TEST-007-009: reconciled to FAILED, never left RUNNING.
      expect(reconciled.status, IngestionRunStatus.failed);
      // TEST-007-010: an explicit interruption diagnostic, distinct from
      // an ordinary stage failure.
      expect(reconciled.diagnostics, contains(IngestionRun.interruptionDiagnostic));
      // Never fabricates a successful completion -- completedAt is
      // populated (recording when the interruption was *discovered*),
      // but the run is unambiguously FAILED, never COMPLETED/PARTIAL.
      expect(reconciled.completedAt, isNotNull);
      expect(reconciled.runId, queuedRun.runId);

      // Idempotent: reconciling an already-reconciled (terminal) run
      // again does nothing further.
      await KnowledgeSessionStorage.save(reloaded);
      final reloadedAgain = await KnowledgeSessionStorage.load(sessionId);
      expect(reloadedAgain.ingestionRuns.single.status, IngestionRunStatus.failed);
      expect(reloadedAgain.ingestionRuns.single.diagnostics, [IngestionRun.interruptionDiagnostic]);
    });
  });

  group('TEST-007-011/012 Retry semantics', () {
    test('a retry receives a new runId, and the original FAILED run remains in session history', () async {
      final tempDir = await Directory.systemTemp.createTemp('wp007-retry');
      final badFile = File('${tempDir.path}${Platform.pathSeparator}not_a_pdf.pdf');
      await badFile.writeAsBytes(utf8.encode('not a real pdf at all'));
      final badInput = await VaultObjectInput.fromFile(
        vaultObjectId: 'wp-007-retry',
        acquisitionRecordIds: const [],
        artifactType: ArtifactType.pdf,
        mimeType: 'application/pdf',
        filePath: badFile.path,
        immutableMetadataSnapshot: const {},
      );

      final runA = await IngestionOrchestrator.run(input: badInput, runId: 'run-a', ocrRunner: fakeOcrSuccess);
      expect(runA.run.status, IngestionRunStatus.failed);

      final goodInput = await trx300Input(vaultObjectId: 'wp-007-retry-good');
      final runB = await IngestionOrchestrator.run(input: goodInput, runId: 'run-b', ocrRunner: fakeOcrSuccess);
      expect(runB.run.status.isTerminal, isTrue);

      expect(runA.run.runId, isNot(runB.run.runId));

      final sessionId = KnowledgeSessionService.generateId('session');
      createdSessionIds.add(sessionId);
      var record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: runA,
        sessionId: sessionId,
        sessionName: 'TEST-007-011',
        repositoryName: 'repo',
        author: 'author',
      );
      record = IngestionKnowledgeSessionBridge.mergeInto(record, runB);
      await KnowledgeSessionStorage.save(record);
      final reloaded = await KnowledgeSessionStorage.load(sessionId);

      expect(reloaded.ingestionRuns, hasLength(2));
      expect(reloaded.ingestionRuns.map((run) => run.runId), containsAll([runA.run.runId, runB.run.runId]));
      final reloadedA = reloaded.ingestionRuns.singleWhere((run) => run.runId == runA.run.runId);
      expect(reloadedA.status, IngestionRunStatus.failed, reason: 'the original failed run must not be overwritten');

      await tempDir.delete(recursive: true);
    });
  });

  group('TEST-007-013/014/015 Processing identity relationship to execution identity', () {
    test('same evidence + same processing definition => same processingIdentity across separate runIds', () {
      final now = DateTime.now();
      IngestionRun buildRun({required String runId, required DateTime startedAt}) => IngestionRun(
        runId: runId,
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: startedAt,
        status: IngestionRunStatus.completed,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: const {'ocr': 'Tesseract 5.4.0'},
        processingConfiguration: const {},
        stageResults: const [],
      );

      final runA = buildRun(runId: 'run-a', startedAt: now);
      final runB = buildRun(runId: 'run-b', startedAt: now.add(const Duration(hours: 1)));
      // TEST-007-013.
      expect(runA.processingIdentity, runB.processingIdentity);
      // TEST-007-014: changing runId alone never changes identity.
      expect(runA.runId, isNot(runB.runId));
    });

    test('changing the processing definition changes processingIdentity', () {
      IngestionRun buildRun({required String parserVersion}) => IngestionRun(
        runId: 'run-a',
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: DateTime.now(),
        status: IngestionRunStatus.completed,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'pdf',
        parserVersion: parserVersion,
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: const [],
      );

      final baseline = buildRun(parserVersion: '1.0.0');
      final changed = buildRun(parserVersion: '2.0.0');
      // TEST-007-015.
      expect(baseline.processingIdentity, isNot(changed.processingIdentity));
    });
  });

  group('TEST-007-016 Terminal states cannot transition back to active states', () {
    test('COMPLETED/PARTIAL/FAILED/CANCELLED all reject a transition back to RUNNING', () {
      IngestionRun buildRun(IngestionRunStatus status) => IngestionRun(
        runId: 'run-a',
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        status: status,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: const [],
      );

      for (final status in [
        IngestionRunStatus.completed,
        IngestionRunStatus.partial,
        IngestionRunStatus.failed,
        IngestionRunStatus.cancelled,
      ]) {
        final run = buildRun(status);
        expect(run.status.isTerminal, isTrue);
        expect(
          () => run.transitionTo(IngestionRunStatus.running),
          throwsA(isA<StateError>()),
          reason: '$status -> running must be illegal',
        );
      }

      // Legal transitions still succeed.
      final queued = buildRun(IngestionRunStatus.queued);
      expect(queued.transitionTo(IngestionRunStatus.running).status, IngestionRunStatus.running);
    });
  });

  group('TEST-007-017 No Reference Vault mutation', () {
    test('the full lifecycle (QUEUED -> RUNNING -> terminal) never issues a non-GET Reference Vault request',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      var mutationAttempted = false;
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake-eam/api',
        client: MockClient((request) async {
          if (request.method != 'GET') {
            mutationAttempted = true;
            return http.Response('should not be called', 500);
          }
          final path = request.url.path;
          if (path.endsWith('/vault/$vaultId/artifact')) {
            return http.Response.bytes(
              bytes,
              200,
              headers: {'x-checksum-sha256': checksum, 'content-type': 'application/pdf'},
            );
          }
          if (path.endsWith('/vault/$vaultId')) {
            return http.Response(
              jsonEncode({
                'id': vaultId,
                'metadata_id': 'metadata-1',
                'verification_id': 'verification-1',
                'download_session_id': 'download-1',
                'source_id': 'source-1',
                'sha256_hash': checksum,
                'mime_type': 'application/pdf',
                'file_size_bytes': bytes.length,
                'status': 'Published',
                'published_at': '2026-01-01T00:00:00Z',
                'created_at': '2026-01-01T00:00:00Z',
              }),
              200,
            );
          }
          if (path.endsWith('/acquisition-records')) {
            return http.Response(
              jsonEncode([
                {'id': 'acq-record-1', 'download_session_id': 'download-1', 'status': 'Published'},
              ]),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        tokenReader: () async => 'test-token',
      );

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-017',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      createdSessionIds.add(outcome.sessionRecord!.session.id);
      expect(mutationAttempted, isFalse, reason: 'no PUT/PATCH/DELETE (or any non-GET) request was ever issued');
    });
  });

  group('TEST-007-018 No Engineering Repository write', () {
    test('the lifecycle implementation never imports/invokes repository commit infrastructure', () async {
      for (final path in [
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}acquisition'
            '${Platform.pathSeparator}services${Platform.pathSeparator}reference_vault_ingestion_workflow.dart',
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}ingestion'
            '${Platform.pathSeparator}services${Platform.pathSeparator}knowledge_session_bridge.dart',
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}ingestion'
            '${Platform.pathSeparator}services${Platform.pathSeparator}ingestion_orchestrator.dart',
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}ingestion'
            '${Platform.pathSeparator}services${Platform.pathSeparator}ingestion_cancellation_token.dart',
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}knowledge'
            '${Platform.pathSeparator}services${Platform.pathSeparator}knowledge_session_storage.dart',
      ]) {
        final source = await File(path).readAsString();
        final importLines = source.split('\n').where((line) => line.trim().startsWith('import '));
        for (final line in importLines) {
          expect(line, isNot(contains('commit_transaction_service')));
          expect(line, isNot(contains('commit_plan_service')));
          expect(line, isNot(contains('foundation_bridge')));
        }
      }

      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);
      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-018',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );
      createdSessionIds.add(outcome.sessionRecord!.session.id);
      expect(outcome.sessionRecord!.commitReports, isEmpty);
    });
  });

  group('TEST-007-019 Full JSON round trip preserves execution history', () {
    test('every field of the persisted run/stage history survives a save/load round trip', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-007-019',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrPartial,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);

      final original = record.ingestionRuns.single;
      final persisted = reloaded.ingestionRuns.single;
      expect(persisted.runId, original.runId);
      expect(persisted.vaultObjectId, original.vaultObjectId);
      expect(persisted.contentHash, original.contentHash);
      expect(persisted.status, original.status);
      expect(persisted.pipelineVersion, original.pipelineVersion);
      expect(persisted.parserId, original.parserId);
      expect(persisted.parserVersion, original.parserVersion);
      expect(persisted.processorVersions, original.processorVersions);
      expect(persisted.processingIdentity, original.processingIdentity);
      expect(persisted.stageResults.length, original.stageResults.length);
      expect(reloaded.derivedArtifacts.length, record.derivedArtifacts.length);
    });
  });

  group('TEST-007-020 Retry preserves all previous historical runs', () {
    test('appending a second, third execution attempt never drops earlier ones', () async {
      final sessionId = KnowledgeSessionService.generateId('session');
      createdSessionIds.add(sessionId);

      final input1 = await trx300Input(vaultObjectId: 'wp-007-020-a');
      final result1 = await IngestionOrchestrator.run(input: input1, runId: 'run-020-a', ocrRunner: fakeOcrSuccess);
      var record = IngestionKnowledgeSessionBridge.toNewSessionRecord(
        result: result1,
        sessionId: sessionId,
        sessionName: 'TEST-007-020',
        repositoryName: 'repo',
        author: 'author',
      );
      await KnowledgeSessionStorage.save(record);

      final input2 = await trx300Input(vaultObjectId: 'wp-007-020-b');
      final result2 = await IngestionOrchestrator.run(input: input2, runId: 'run-020-b', ocrRunner: fakeOcrSuccess);
      record = IngestionKnowledgeSessionBridge.mergeInto(record, result2);
      await KnowledgeSessionStorage.save(record);

      final input3 = await trx300Input(vaultObjectId: 'wp-007-020-c');
      final result3 = await IngestionOrchestrator.run(input: input3, runId: 'run-020-c', ocrRunner: fakeOcrSuccess);
      record = IngestionKnowledgeSessionBridge.mergeInto(record, result3);
      await KnowledgeSessionStorage.save(record);

      final reloaded = await KnowledgeSessionStorage.load(sessionId);
      expect(reloaded.ingestionRuns, hasLength(3));
      expect(
        reloaded.ingestionRuns.map((run) => run.runId).toSet(),
        {'run-020-a', 'run-020-b', 'run-020-c'},
      );
    });
  });

  group('WP-INGEST-014 orientation survives the real ingestion workflow', () {
    test('the session-owned source copy keeps the chosen orientation across reload and duplication', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'orientation-persist',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
        orientation: DocumentOrientation.deg90,
      );

      expect(outcome.isCompleted, isTrue);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      expect(record.sources.single.extractionOrientation, DocumentOrientation.deg90);
      expect(record.ingestionRuns.single.processingConfiguration['extractionOrientationDegrees'], 90);

      final reloaded = await KnowledgeSessionStorage.load(record.session.id);
      expect(reloaded.sources.single.extractionOrientation, DocumentOrientation.deg90);

      final copy = KnowledgeSessionService.buildDuplicate(reloaded, author: 'author');
      expect(copy.sources.single.extractionOrientation, DocumentOrientation.deg90);
    });
  });
}

