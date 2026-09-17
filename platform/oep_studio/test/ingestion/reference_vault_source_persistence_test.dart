import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_client.dart';
import 'package:oep_studio/acquisition/services/reference_vault_ingestion_workflow.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';
import 'package:oep_studio/knowledge/services/source_material_service.dart';

/// WP-INGEST-005 TEST-005-001 through TEST-005-012 -- the fix for the bug
/// WP-INGEST-004 (`ReferenceVaultIngestionWorkflow`) left behind: a
/// successful/partial Reference Vault ingestion's `KnowledgeSessionRecord`
/// carried a `SourceMaterial.localPath` pointing at
/// `ReferenceVaultAdapter`'s *temporary* materialization, which the
/// workflow's own `finally` block then deleted -- leaving the Source
/// Viewer unable to reopen the ingested source.
///
/// Structured, mocked, and fixture-sourced exactly like
/// `reference_vault_ingestion_workflow_test.dart` (WP-INGEST-004): only
/// `AcquisitionApiClient`'s HTTP transport is faked
/// (`package:http/testing.dart`'s `MockClient`); the real
/// `ReferenceVaultAdapter`, `IngestionOrchestrator`, and
/// `IngestionKnowledgeSessionBridge` all run unmodified. OCR is faked
/// through `IngestionOrchestrator`'s existing `OcrRunner` injection seam
/// (this build/test machine has no `tesseract` executable) -- the exact
/// same `fakeOcrSuccess`/`fakeOcrPartial` fakes WP-INGEST-001's TEST-012
/// and WP-INGEST-004's TEST-004-008 already established, duplicated here
/// rather than shared, matching this suite's existing per-file convention.
///
/// Every session this suite creates uses a real
/// `KnowledgeSessionStorage.sourcesDirectory` write (there is no injected
/// directory override -- see `knowledge_session_storage_test.dart`'s own
/// doc comment for why) and is deleted in `tearDown`, so nothing is left
/// behind on the machine running the suite.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  const vaultId = 'wp-ingest-005-vault-entry-0001';

  final createdSessionIds = <String>[];

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

  // The exact deterministic per-page-failure fake
  // `ingestion_pipeline_test.dart`'s own TEST-012 (Partial Processing) /
  // WP-INGEST-004's TEST-004-008 use -- page 1 succeeds, page 2 fails
  // outright (AP-INGEST-001 § 6.1's own worked PARTIAL example).
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

  tearDown(() async {
    for (final id in createdSessionIds) {
      final directory = KnowledgeSessionStorage.sessionDirectory(id);
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
    createdSessionIds.clear();
  });

  group('TEST-005-001 Source becomes session-owned', () {
    test('SourceMaterial.localPath is inside KnowledgeSessionStorage, not the temporary adapter path', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-001',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final source = record.sources.single;

      final managedDir = KnowledgeSessionStorage.sourcesDirectory(record.session.id).path;
      expect(source.localPath, startsWith(managedDir));
      expect(source.localPath, isNot(startsWith(Directory.systemTemp.path)));
    });
  });

  group('TEST-005-002 Managed source exists', () {
    test('the managed file exists and its bytes match the Reference Vault artifact', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-002',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final source = record.sources.single;

      final managedFile = File(source.localPath);
      expect(await managedFile.exists(), isTrue);
      final managedBytes = await managedFile.readAsBytes();
      expect(managedBytes, orderedEquals(bytes));
    });
  });

  group('TEST-005-003 Temporary file cleaned', () {
    test('the temporary ingestion artifact is gone while the managed source survives', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-003',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);

      // `outcome.ingestionResult!.source` is UIF's own, untouched output
      // (`PdfIngestionParser.parse` sets `localPath` to
      // `VaultObjectInput.storageReference`, the temp file
      // `ReferenceVaultAdapter.materialize` created) -- the workflow's
      // `finally` block must have deleted it by the time `ingest` returns.
      final temporaryPath = outcome.ingestionResult!.source.localPath;
      expect(temporaryPath, startsWith(Directory.systemTemp.path));
      expect(await File(temporaryPath).exists(), isFalse);

      // The session-managed copy -- a different path -- must still exist.
      final managedSource = record.sources.single;
      expect(managedSource.localPath, isNot(equals(temporaryPath)));
      expect(await File(managedSource.localPath).exists(), isTrue);
    });
  });

  group('TEST-005-004 Source Viewer compatibility', () {
    test('SourceMaterialService.exists resolves the managed source', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-004',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);
      final source = record.sources.single;

      // The exact contract `SourceViewerPanel`/`PdfSourceViewer` rely on
      // (`File(source.localPath)`), exercised through the same service
      // Work Package 008's Source Viewer already uses to check
      // availability before opening a source.
      expect(SourceMaterialService.exists(source), isTrue);
    });
  });

  group('TEST-005-005/006 Session reload', () {
    test('the session, its source, and the source file all survive a persist/reload round trip', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-005',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);

      await KnowledgeSessionStorage.save(record);
      final reloaded = await KnowledgeSessionStorage.load(record.session.id);

      expect(reloaded.session.id, record.session.id);
      final reloadedSource = reloaded.sources.single;
      expect(reloadedSource.localPath, record.sources.single.localPath);
      expect(await File(reloadedSource.localPath).exists(), isTrue);

      // TEST-005-006: reloaded source content is byte-identical to the
      // original Reference Vault artifact.
      final reloadedBytes = await File(reloadedSource.localPath).readAsBytes();
      expect(sha256.convert(reloadedBytes).toString(), checksum);
    });
  });

  group('TEST-005-007/008 Candidate/evidence/provenance survives', () {
    test('candidates, evidence, and processing-chain provenance remain intact after source persistence', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-007',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final result = outcome.ingestionResult!;
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);

      // TEST-005-007: candidates/evidence are exactly what the bridge
      // already carried through -- the source-persistence fix only
      // replaces `sources`, nothing else.
      expect(record.candidates, equals(result.knowledgeCandidates));
      expect(record.evidenceRegions, equals(result.evidenceRegions));
      expect(record.evidenceLinks, equals(result.evidenceLinks));
      expect(record.engineeringEntities, isNotEmpty);

      // TEST-005-008: Vault Object -> Acquisition Record -> Ingestion Run
      // -> derived/evidence data (AP-INGEST-001 § 16) is unbroken.
      expect(result.run.vaultObjectId, vaultId);
      expect(result.candidateProvenance, isNotEmpty);
      for (final provenance in result.candidateProvenance.values) {
        expect(provenance.vaultObjectId, vaultId);
        expect(provenance.runId, result.run.runId);
        expect(provenance.acquisitionRecordIds, contains('acq-record-1'));
      }
      // The managed source's id still matches every `sourceId` reference
      // (`OcrPageResult`/`EngineeringEntity`/`EvidenceRegion`) UIF produced
      // -- proof the id was preserved, not regenerated, when the file was
      // copied into session storage.
      final sourceId = record.sources.single.id;
      expect(record.ocrPageResults, isNotEmpty);
      for (final page in record.ocrPageResults) {
        expect(page.sourceId, sourceId);
      }
    });
  });

  group('TEST-005-009 Reference Vault immutability', () {
    test('the workflow never mutates the Reference Vault artifact', () async {
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
        sessionName: 'TEST-005-009',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      createdSessionIds.add(outcome.sessionRecord!.session.id);
      expect(mutationAttempted, isFalse, reason: 'no PUT/PATCH/DELETE (or any non-GET) request was ever issued');

      final afterBytes = await File(trx300Path).readAsBytes();
      expect(afterBytes, orderedEquals(bytes));
      expect(sha256.convert(afterBytes).toString(), checksum);
    });
  });

  group('TEST-005-010 No repository write', () {
    test('ingestion never commits -- candidates stay pending and no commit report is produced', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-010',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord!;
      createdSessionIds.add(record.session.id);

      expect(record.commitReports, isEmpty);
      for (final candidate in record.candidates) {
        expect(candidate.committedObjectId, isNull);
      }

      final workflowSource = await File(
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}acquisition'
        '${Platform.pathSeparator}services${Platform.pathSeparator}reference_vault_ingestion_workflow.dart',
      ).readAsString();
      final importLines = workflowSource.split('\n').where((line) => line.trim().startsWith('import '));
      for (final line in importLines) {
        expect(line, isNot(contains('commit_transaction_service')));
        expect(line, isNot(contains('commit_plan_service')));
        expect(line, isNot(contains('foundation_bridge')));
      }
    });
  });

  group('TEST-005-011 PARTIAL ingestion', () {
    test('a PARTIAL run still gets a persisted, viewable, inspectable managed source', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-011',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrPartial,
      );

      expect(outcome.isPartial, isTrue);
      expect(outcome.ingestionResult!.run.status, IngestionRunStatus.partial);
      final record = outcome.sessionRecord;
      expect(record, isNotNull);
      createdSessionIds.add(record!.session.id);

      final source = record.sources.single;
      final managedDir = KnowledgeSessionStorage.sourcesDirectory(record.session.id).path;
      expect(source.localPath, startsWith(managedDir));
      expect(await File(source.localPath).exists(), isTrue);
      expect(SourceMaterialService.exists(source), isTrue);

      // Successfully-generated candidates/evidence from before the
      // per-page OCR failure remain present and inspectable.
      expect(record.ocrPageResults, isNotEmpty);
      expect(record.ocrPageResults.any((page) => page.success), isTrue);

      // Temporary artifact still cleaned even on PARTIAL.
      final temporaryPath = outcome.ingestionResult!.source.localPath;
      expect(await File(temporaryPath).exists(), isFalse);
    });
  });

  group('TEST-005-012 FAILED ingestion cleanup', () {
    test('a FAILED run leaves no orphaned managed source, cleans the temp file, and writes nothing to the repository',
        () async {
      // A byte sequence `PdfIngestionParser` cannot parse, so the
      // orchestrator's parser stage fails and the run status becomes
      // FAILED before any Knowledge Session is ever built -- the same
      // failure trigger WP-INGEST-004's TEST-004-009 uses.
      final bytes = utf8.encode('not a real pdf at all');
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final before = KnowledgeSessionStorage.root().existsSync()
          ? KnowledgeSessionStorage.root().listSync().map((entry) => entry.path).toSet()
          : <String>{};

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TEST-005-012',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isTrue);
      expect(outcome.failureStage, ReferenceVaultIngestionStage.ingestion);
      expect(outcome.sessionRecord, isNull, reason: 'no repository/session write can have occurred');

      // No orphaned session-owned source: no new directory appeared under
      // `KnowledgeSessionStorage.root()`.
      final after = KnowledgeSessionStorage.root().existsSync()
          ? KnowledgeSessionStorage.root().listSync().map((entry) => entry.path).toSet()
          : <String>{};
      expect(after.difference(before), isEmpty);

      // Temporary artifact still cleaned on FAILED.
      final temporaryPath = outcome.ingestionResult!.structuralData.metadata.sourceFileName;
      expect(temporaryPath, startsWith(Directory.systemTemp.path));
      expect(await File(temporaryPath).exists(), isFalse);
    });
  });
}
