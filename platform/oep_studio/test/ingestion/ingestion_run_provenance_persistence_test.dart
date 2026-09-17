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
import 'package:oep_studio/ingestion/models/ingestion_stage.dart';
import 'package:oep_studio/ingestion/models/stage_execution_status.dart';
import 'package:oep_studio/ingestion/models/vault_object_input.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-006 § 19 acceptance tests (TEST-006-001 through TEST-006-016)
/// for durable Ingestion Run / processing provenance within the existing
/// Knowledge Session persistence domain, run against the real TRX300
/// reference dataset (`reference/ingestion/trx300/source/`) — never
/// modified by any test here.
///
/// Structured like `reference_vault_ingestion_workflow_test.dart`
/// (WP-INGEST-004) / `reference_vault_source_persistence_test.dart`
/// (WP-INGEST-005): only `AcquisitionApiClient`'s HTTP transport is faked;
/// the real `ReferenceVaultAdapter`, `IngestionOrchestrator`, and
/// `IngestionKnowledgeSessionBridge` all run unmodified. OCR is faked
/// through the existing `OcrRunner` injection seam (this build/test
/// machine has no `tesseract` executable) using the same deterministic
/// per-page-failure fake WP-INGEST-001's TEST-012 established.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  const vaultId = 'wp-ingest-006-vault-entry-0001';

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

  Future<VaultObjectInput> trx300Input({List<String> acquisitionRecordIds = const []}) => VaultObjectInput.fromFile(
    vaultObjectId: 'trx300-factory-wiring-diagram',
    acquisitionRecordIds: acquisitionRecordIds,
    artifactType: ArtifactType.pdf,
    mimeType: 'application/pdf',
    filePath: trx300Path,
    immutableMetadataSnapshot: const {
      'sourceDocumentIdentity': '1988 Honda TRX300 FourTrax Factory Service Manual, Section 21',
    },
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
          OcrWord(
            text: '24',
            confidence: 0.9,
            boundingBox: const OcrBoundingBox(x: 0.2, y: 0, width: 0.05, height: 0.03),
            readingOrder: 1,
            lineIndex: 0,
          ),
          OcrWord(
            text: 'Nm',
            confidence: 0.9,
            boundingBox: const OcrBoundingBox(x: 0.3, y: 0, width: 0.05, height: 0.03),
            readingOrder: 2,
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

  // The exact deterministic per-page-failure fake WP-INGEST-001's
  // TEST-012 / WP-INGEST-004's TEST-004-008 / WP-INGEST-005's TEST-005-011
  // already use -- page 1 succeeds, page 2 fails outright.
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
          OcrWord(
            text: '24',
            confidence: 0.9,
            boundingBox: const OcrBoundingBox(x: 0.2, y: 0, width: 0.05, height: 0.03),
            readingOrder: 1,
            lineIndex: 0,
          ),
          OcrWord(
            text: 'Nm',
            confidence: 0.9,
            boundingBox: const OcrBoundingBox(x: 0.3, y: 0, width: 0.05, height: 0.03),
            readingOrder: 2,
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

  AcquisitionApiClient buildClient({
    required List<int> bytes,
    required String checksum,
    String mimeType = 'application/pdf',
    String? entrySha256Override,
    List<Map<String, Object?>> acquisitionRecords = const [
      {'id': 'acq-record-1', 'download_session_id': 'download-1', 'status': 'Published'},
    ],
  }) {
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
              'sha256_hash': entrySha256Override ?? checksum,
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
          return http.Response(jsonEncode(acquisitionRecords), 200);
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

  group('TEST-006-001 Ingestion Run persisted', () {
    test('a successful ingestion\'s Knowledge Session carries its IngestionRun', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-001',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);

      expect(record.ingestionRuns, hasLength(1));
      expect(record.ingestionRuns.single.runId, outcome.ingestionResult!.run.runId);
      expect(record.ingestionRuns.single.vaultObjectId, vaultId);
    });
  });

  group('TEST-006-002 Processing identity exists', () {
    test('a completed run has a non-empty deterministic processing identity', () async {
      final input = await trx300Input();
      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess);

      expect(result.run.processingIdentity, isNotEmpty);
      // A SHA-256 hex digest -- the repository's existing hashing
      // convention, not an invented scheme.
      expect(result.run.processingIdentity, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('TEST-006-003 Processing identity deterministic', () {
    test('identical Vault identity/content/pipeline/parser/processor/configuration => identical identity', () {
      final now = DateTime.now();
      IngestionRun buildRun({required String runId, required DateTime startedAt}) => IngestionRun(
        runId: runId,
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: startedAt,
        completedAt: startedAt.add(const Duration(seconds: 5)),
        status: IngestionRunStatus.completed,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: const {'ocr': 'Tesseract 5.4.0', 'entityExtraction': 'engineering_pattern_library-1'},
        processingConfiguration: const {'ocrDpi': 300},
        stageResults: const [],
      );

      final first = buildRun(runId: 'run-a', startedAt: now);
      // Different runId and different timestamps -- same processing
      // definition/input.
      final second = buildRun(runId: 'run-b', startedAt: now.add(const Duration(days: 1)));

      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-006-004 Processing identity changes with definition', () {
    test('a changed processor version changes the identity', () {
      final now = DateTime.now();
      IngestionRun buildRun({required Map<String, String> processorVersions}) => IngestionRun(
        runId: 'run-a',
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: now,
        completedAt: now,
        status: IngestionRunStatus.completed,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: processorVersions,
        processingConfiguration: const {},
        stageResults: const [],
      );

      final baseline = buildRun(processorVersions: const {'ocr': 'Tesseract 5.4.0'});
      final changedProcessor = buildRun(processorVersions: const {'ocr': 'Tesseract 5.5.0'});
      expect(baseline.processingIdentity, isNot(changedProcessor.processingIdentity));
    });

    test('a changed pipeline version changes the identity', () {
      final now = DateTime.now();
      IngestionRun buildRun({required String pipelineVersion}) => IngestionRun(
        runId: 'run-a',
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: now,
        completedAt: now,
        status: IngestionRunStatus.completed,
        pipelineVersion: pipelineVersion,
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: const [],
      );

      final baseline = buildRun(pipelineVersion: 'uif-pipeline-1.0.0');
      final changedPipeline = buildRun(pipelineVersion: 'uif-pipeline-2.0.0');
      expect(baseline.processingIdentity, isNot(changedPipeline.processingIdentity));
    });

    test('a changed processing configuration changes the identity', () {
      final now = DateTime.now();
      IngestionRun buildRun({required Map<String, dynamic> config}) => IngestionRun(
        runId: 'run-a',
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: now,
        completedAt: now,
        status: IngestionRunStatus.completed,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: const {},
        processingConfiguration: config,
        stageResults: const [],
      );

      final baseline = buildRun(config: const {'ocrDpi': 300});
      final changedConfig = buildRun(config: const {'ocrDpi': 600});
      expect(baseline.processingIdentity, isNot(changedConfig.processingIdentity));
    });
  });

  group('TEST-006-005 Timestamp independence', () {
    test('changing run timestamps alone does not change processing identity', () {
      IngestionRun buildRun({required DateTime startedAt, required DateTime? completedAt}) => IngestionRun(
        runId: 'run-a',
        vaultObjectId: 'vault-object-1',
        contentHash: 'content-hash-abc',
        startedAt: startedAt,
        completedAt: completedAt,
        status: IngestionRunStatus.completed,
        pipelineVersion: 'uif-pipeline-1.0.0',
        parserId: 'pdf',
        parserVersion: '1.0.0',
        processorVersions: const {},
        processingConfiguration: const {},
        stageResults: const [],
      );

      final first = buildRun(startedAt: DateTime(2020, 1, 1), completedAt: DateTime(2020, 1, 1, 0, 0, 5));
      final second = buildRun(startedAt: DateTime(2026, 6, 6), completedAt: null);
      expect(first.processingIdentity, second.processingIdentity);
    });
  });

  group('TEST-006-006/007 Stage history and status preserved', () {
    test('executed stages and their SUCCESS/PARTIAL/FAILED/SKIPPED statuses survive session persistence/reload',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-006',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrPartial,
      );

      expect(outcome.isPartial, isTrue);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);

      await KnowledgeSessionStorage.save(record);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);

      final originalRun = record.ingestionRuns.single;
      final reloadedRun = reloaded.ingestionRuns.single;

      expect(reloadedRun.stageResults, hasLength(originalRun.stageResults.length));
      for (var i = 0; i < originalRun.stageResults.length; i++) {
        expect(reloadedRun.stageResults[i].stage, originalRun.stageResults[i].stage);
        expect(reloadedRun.stageResults[i].status, originalRun.stageResults[i].status);
      }

      // The OCR stage of a partial run must remain PARTIAL after reload,
      // never silently upgraded to SUCCESS.
      final ocrStage = reloadedRun.stageResults.singleWhere((stage) => stage.stage == IngestionStage.ocr);
      expect(ocrStage.status, StageExecutionStatus.partial);
      expect(reloadedRun.status, IngestionRunStatus.partial);
    });
  });

  group('TEST-006-008 Diagnostics preserved', () {
    test('meaningful stage diagnostics survive session reload', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-008',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrPartial,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      await KnowledgeSessionStorage.save(record);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);

      final ocrStage =
          reloaded.ingestionRuns.single.stageResults.singleWhere((stage) => stage.stage == IngestionStage.ocr);
      expect(ocrStage.diagnostics, isNotEmpty);
      expect(ocrStage.diagnostics.any((line) => line.contains('Page 2')), isTrue);
    });
  });

  group('TEST-006-009 Partial run provenance', () {
    test('a forced partial OCR condition yields run=PARTIAL with successful and failed stage information available',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-009',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrPartial,
      );

      expect(outcome.isPartial, isTrue);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final run = record.ingestionRuns.single;

      expect(run.status, IngestionRunStatus.partial);
      final structuralStage =
          run.stageResults.singleWhere((stage) => stage.stage == IngestionStage.structuralAnalysis);
      expect(structuralStage.status, StageExecutionStatus.succeeded);
      final ocrStage = run.stageResults.singleWhere((stage) => stage.stage == IngestionStage.ocr);
      expect(ocrStage.status, StageExecutionStatus.partial);
      // Successful OCR page / entities / candidates are not discarded.
      expect(record.ocrPageResults.any((page) => page.success), isTrue);
      expect(record.engineeringEntities, isNotEmpty);
    });
  });

  group('TEST-006-010 Source/run association', () {
    test('the persisted run remains associated with the correct Vault-derived source', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-010',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final run = record.ingestionRuns.single;

      expect(run.vaultObjectId, vaultId);
      expect(run.contentHash, checksum);
      // Every OCR page result belonging to this run's source shares the
      // same sourceId as the session's single managed source.
      final sourceId = record.sources.single.id;
      for (final page in record.ocrPageResults) {
        expect(page.sourceId, sourceId);
      }
    });
  });

  group('TEST-006-011 Candidate provenance survives', () {
    test('ingestion candidates remain associated with the session and their provenance remains intact', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum, acquisitionRecords: const [
        {'id': 'acq-record-1', 'download_session_id': 'download-1', 'status': 'Published'},
      ]);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-011',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final result = outcome.ingestionResult!;

      expect(record.candidates, equals(result.knowledgeCandidates));
      expect(result.candidateProvenance, isNotEmpty);
      for (final provenance in result.candidateProvenance.values) {
        expect(provenance.runId, record.ingestionRuns.single.runId);
        expect(provenance.vaultObjectId, vaultId);
      }
    });
  });

  group('TEST-006-012 Derived artifact provenance', () {
    test('every persisted derived-artifact reference retains runId/stage/vaultObjectId/contentHash/processor',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-012',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final run = record.ingestionRuns.single;

      expect(record.derivedArtifacts, isNotEmpty);
      for (final artifact in record.derivedArtifacts) {
        expect(artifact.runId, run.runId);
        expect(artifact.vaultObjectId, vaultId);
        expect(artifact.contentHash, isNotEmpty);
        expect(artifact.processorId, isNotEmpty);
        expect(artifact.processorVersion, isNotEmpty);
      }
      // Every StageResult.derivedArtifactIds entry actually resolves to a
      // persisted DerivedArtifact -- no dangling references.
      final artifactIds = record.derivedArtifacts.map((artifact) => artifact.derivedArtifactId).toSet();
      for (final stage in run.stageResults) {
        for (final id in stage.derivedArtifactIds) {
          expect(artifactIds.contains(id), isTrue, reason: 'dangling derivedArtifactId $id on stage ${stage.stage}');
        }
      }
    });
  });

  group('TEST-006-013 Session reload', () {
    test('ingestion metadata remains available after persisting and reconstructing the session', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-006-013',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);

      await KnowledgeSessionStorage.save(record);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);

      expect(reloaded.ingestionRuns, hasLength(1));
      expect(reloaded.ingestionRuns.single.runId, record.ingestionRuns.single.runId);
      expect(reloaded.ingestionRuns.single.processingIdentity, record.ingestionRuns.single.processingIdentity);
      expect(reloaded.derivedArtifacts, hasLength(record.derivedArtifacts.length));
      expect(
        reloaded.derivedArtifacts.map((artifact) => artifact.derivedArtifactId).toSet(),
        record.derivedArtifacts.map((artifact) => artifact.derivedArtifactId).toSet(),
      );
    });
  });

  group('TEST-006-014 No repository write', () {
    test('ingestion never invokes repository commit infrastructure', () async {
      for (final path in [
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}acquisition'
            '${Platform.pathSeparator}services${Platform.pathSeparator}reference_vault_ingestion_workflow.dart',
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}ingestion'
            '${Platform.pathSeparator}services${Platform.pathSeparator}knowledge_session_bridge.dart',
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}knowledge'
            '${Platform.pathSeparator}models${Platform.pathSeparator}knowledge_session_record.dart',
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
        sessionName: 'TEST-006-014',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      expect(record.commitReports, isEmpty);
    });
  });

  group('TEST-006-015 Reference Vault remains immutable', () {
    test('the ingestion path performs no Vault mutation', () async {
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
        sessionName: 'TEST-006-015',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      createdSessionIds.add(outcome.sessionRecord!.session.id);
      expect(mutationAttempted, isFalse, reason: 'no PUT/PATCH/DELETE (or any non-GET) request was ever issued');
    });
  });

  group('TEST-006-016 Failed processing history', () {
    test('a parser failure records FAILED accurately, never falsely reporting COMPLETED', () async {
      // A byte sequence PdfIngestionParser cannot parse, so the
      // orchestrator's parser stage fails and the run status becomes
      // FAILED -- the same trigger WP-INGEST-004's TEST-004-009 uses.
      final input = await VaultObjectInput.fromFile(
        vaultObjectId: 'wp-006-failed-run',
        acquisitionRecordIds: const [],
        artifactType: ArtifactType.pdf,
        mimeType: 'application/pdf',
        filePath: trx300Path,
        immutableMetadataSnapshot: const {},
      );
      // Corrupt input in-memory by constructing a run through the real
      // orchestrator against genuinely unparsable bytes on disk instead --
      // reuse the existing pattern of writing an invalid temp file so the
      // parser stage itself fails.
      final tempDir = await Directory.systemTemp.createTemp('wp006-failed');
      final badFile = File('${tempDir.path}${Platform.pathSeparator}not_a_pdf.pdf');
      await badFile.writeAsBytes(utf8.encode('not a real pdf at all'));
      final badInput = await VaultObjectInput.fromFile(
        vaultObjectId: input.vaultObjectId,
        acquisitionRecordIds: const [],
        artifactType: ArtifactType.pdf,
        mimeType: 'application/pdf',
        filePath: badFile.path,
        immutableMetadataSnapshot: const {},
      );

      final result = await IngestionOrchestrator.run(input: badInput, ocrRunner: fakeOcrSuccess);

      expect(result.run.status, IngestionRunStatus.failed);
      expect(result.run.status, isNot(IngestionRunStatus.completed));
      final failedStages = result.run.stageResults.where((stage) => stage.status == StageExecutionStatus.failed);
      expect(failedStages, isNotEmpty);
      for (final stage in failedStages) {
        expect(stage.diagnostics, isNotEmpty);
      }

      await tempDir.delete(recursive: true);
    });
  });
}
