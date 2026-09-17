import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_client.dart';
import 'package:oep_studio/acquisition/services/reference_vault_ingestion_workflow.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/knowledge/models/knowledge_candidate_status.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

/// WP-INGEST-004 § 15 TEST-004-001 through TEST-004-014 — the Reference
/// Vault ingestion workflow (`ReferenceVaultIngestionWorkflow.ingest`),
/// the new application-level coordinator this work package introduces.
///
/// Mocked/isolated exactly like `production_reference_vault_vertical_slice_test.dart`
/// (WP-INGEST-003): only `AcquisitionApiClient`'s HTTP transport is
/// faked (`package:http/testing.dart`'s `MockClient`); every other
/// component in the chain — `ReferenceVaultAdapter`, the real
/// `IngestionOrchestrator`, `IngestionKnowledgeSessionBridge` — runs
/// unmodified, per WP-INGEST-004 § 14's explicit instruction not to mock
/// the UIF itself. OCR is faked through `IngestionOrchestrator`'s own
/// existing `OcrRunner` injection seam (forwarded by
/// `ReferenceVaultIngestionWorkflow.ingest`'s own `ocrRunner` parameter)
/// because this build/test machine has no `tesseract` executable —
/// the same reason WP-INGEST-001/002/003's own tests fake it.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  const vaultId = 'wp-ingest-004-vault-entry-0001';

  // WP-INGEST-005: a successful/partial `ingest` call now copies the
  // source into a real `KnowledgeSessionStorage.sourcesDirectory` (see
  // `reference_vault_source_persistence_test.dart`), so every session id
  // this suite's outcomes produce is tracked here and deleted in
  // `tearDown`, matching `knowledge_session_storage_test.dart`'s own
  // established convention -- this suite must not leave files behind.
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
  // `ingestion_pipeline_test.dart`'s own TEST-012 (Partial Processing)
  // uses -- page 1 succeeds, page 2 fails outright (AP-INGEST-001 § 6.1's
  // own worked PARTIAL example).
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

  group('TEST-004-001/002/003 accepts a Vault Object ID and drives the real chain', () {
    test('invokes the Reference Vault adapter and the resulting VaultObjectInput reaches the real orchestrator',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TRX300 Ingestion',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      if (outcome.sessionRecord != null) createdSessionIds.add(outcome.sessionRecord!.session.id);
      expect(outcome.ingestionResult, isNotNull);
      // TEST-004-001: the vault object id given to `ingest` is exactly
      // what reached the orchestrator's own `IngestionRun`.
      expect(outcome.ingestionResult!.run.vaultObjectId, vaultId);
      // TEST-004-003: content identity round-trips through the adapter
      // into the orchestrator's structural output.
      expect(outcome.ingestionResult!.structuralData.metadata.contentHash, checksum);
    });
  });

  group('TEST-004-004/005/012 IngestionResult reaches the existing Knowledge Session bridge', () {
    test('the resulting KnowledgeSessionRecord carries candidates/source/evidence Knowledge Studio already expects',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'TRX300 Ingestion',
        repositoryName: 'trx300-repo',
        author: 'test-author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      final record = outcome.sessionRecord;
      expect(record, isNotNull);
      createdSessionIds.add(record!.session.id);
      // TEST-004-012: the exact same model type every existing
      // Knowledge Studio surface (Candidate List, Evidence Browser,
      // Provenance Explorer, Commit Preview) already renders.
      expect(record.session.name, 'TRX300 Ingestion');
      expect(record.sources, hasLength(1));
      expect(record.sources.single.id, outcome.ingestionResult!.source.id);
      expect(record.engineeringEntities, isNotEmpty);
      expect(record.candidates, equals(outcome.ingestionResult!.knowledgeCandidates));
      expect(record.evidenceRegions, equals(outcome.ingestionResult!.evidenceRegions));
      expect(record.evidenceLinks, equals(outcome.ingestionResult!.evidenceLinks));
      // Candidates stay pending review -- ingestion is not approval
      // (WP-INGEST-004 § 12).
      for (final candidate in record.candidates) {
        expect(candidate.status, KnowledgeCandidateStatus.pending);
      }
    });
  });

  group('TEST-004-006 Reference Vault integrity failure prevents ingestion', () {
    test('a Vault Entry sha256_hash that disagrees with the verified artifact checksum fails at the Vault stage',
        () async {
      final bytes = utf8.encode('%PDF-1.4 fake bytes');
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum, entrySha256Override: 'deliberately-wrong-hash');

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'Should Not Ingest',
        repositoryName: 'repo',
        author: 'author',
      );

      expect(outcome.isFailed, isTrue);
      expect(outcome.failureStage, ReferenceVaultIngestionStage.referenceVault);
      expect(outcome.sessionRecord, isNull);
      expect(outcome.ingestionResult, isNull, reason: 'the orchestrator must never be invoked');
    });
  });

  group('TEST-004-007 Unsupported artifact type prevents ingestion', () {
    test('a Vault Entry MIME type with no UIF ArtifactType mapping fails before the orchestrator runs', () async {
      final bytes = utf8.encode('binary blob');
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum, mimeType: 'application/octet-stream');

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'Should Not Ingest',
        repositoryName: 'repo',
        author: 'author',
      );

      expect(outcome.isFailed, isTrue);
      expect(outcome.failureStage, ReferenceVaultIngestionStage.unsupportedArtifact);
      expect(outcome.sessionRecord, isNull);
      expect(outcome.ingestionResult, isNull);
    });
  });

  group('TEST-004-008 PARTIAL ingestion remains PARTIAL', () {
    test('a per-page OCR failure still yields a PARTIAL outcome carrying every successful stage', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      // The exact deterministic per-page-failure fake
      // `ingestion_pipeline_test.dart`'s own TEST-012 (Partial
      // Processing) uses -- page 1 succeeds, page 2 fails outright
      // (AP-INGEST-001 § 6.1's own worked PARTIAL example). Deliberately
      // not left to the real `OcrPipelineService`'s environment-dependent
      // outcome (whether `tesseract` happens to be installed on the
      // machine running this suite) -- `ingestion_pipeline_test.dart`'s
      // own TEST-007 documents that as `anyOf(succeeded, partial, failed)`,
      // which is not a reliable way to prove PARTIAL is preserved.
      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        ocrRunner: fakeOcrPartial,
        sessionName: 'Partial Ingestion',
        repositoryName: 'repo',
        author: 'author',
      );

      expect(outcome.isPartial, isTrue);
      expect(outcome.isCompleted, isFalse);
      expect(outcome.isFailed, isFalse);
      expect(outcome.ingestionResult!.run.status, IngestionRunStatus.partial);
      // Preceding stages' successful intermediate results (parsed
      // structural data) are preserved, not discarded.
      expect(outcome.ingestionResult!.structuralData.pages, isNotEmpty);
      // A session is still produced -- PARTIAL is reviewable, not
      // discarded (WP-INGEST-004 § 6/§ 9).
      expect(outcome.sessionRecord, isNotNull);
      createdSessionIds.add(outcome.sessionRecord!.session.id);
    });
  });

  group('TEST-004-009/010 temporary materialization cleanup', () {
    test('cleaned up after a successful ingestion', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'Cleanup On Success',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(outcome.isFailed, isFalse);
      createdSessionIds.add(outcome.sessionRecord!.session.id);
      // `SourceMaterial.localPath` is set from `VaultObjectInput.storageReference`
      // (`PdfIngestionParser.parse`) -- the exact temp file
      // `ReferenceVaultAdapter.materialize` created and
      // `ReferenceVaultIngestionWorkflow.ingest`'s try/finally must have
      // cleaned up by the time this returns.
      final materializedPath = outcome.ingestionResult!.source.localPath;
      expect(materializedPath, startsWith(Directory.systemTemp.path));
      expect(await File(materializedPath).exists(), isFalse);
      expect(await Directory(materializedPath).parent.exists(), isFalse);
    });

    test('cleaned up even when the ingestion run itself fails', () async {
      // A byte sequence `PdfIngestionParser` cannot parse, so the
      // orchestrator's PARSER_SELECTION/parse stage fails and the run
      // status becomes FAILED -- but materialization still happened, so
      // cleanup must still run.
      final bytes = utf8.encode('not a real pdf at all');
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'Cleanup On Failure',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );

      // The parser must have failed -- confirming this test actually
      // exercises the failure path it claims to.
      expect(outcome.isFailed, isTrue);
      expect(outcome.failureStage, ReferenceVaultIngestionStage.ingestion);
      // `IngestionOrchestrator`'s terminal-result builder sets both
      // `structuralData.metadata.sourceFileName` and `source.localPath`
      // to `input.storageReference` -- the materialized temp file must
      // no longer exist.
      final materializedPath = outcome.ingestionResult!.structuralData.metadata.sourceFileName;
      expect(materializedPath, startsWith(Directory.systemTemp.path));
      expect(await File(materializedPath).exists(), isFalse);

      // WP-INGEST-007 § 7/§ 18/§ 23: unlike before that work package, a
      // FAILED run is now durably persisted as historical Knowledge
      // Session state (never exposed as `outcome.sessionRecord`, which
      // stays null exactly as before) -- clean up the directory this
      // test itself caused to be written, so nothing is left behind.
      final runId = outcome.ingestionResult!.run.runId;
      final matchingSessionDirs = KnowledgeSessionStorage.root().existsSync()
          ? KnowledgeSessionStorage.root().listSync().whereType<Directory>().where((dir) {
              final file = File('${dir.path}${Platform.pathSeparator}session.json');
              return file.existsSync() && file.readAsStringSync().contains(runId);
            })
          : const Iterable<Directory>.empty();
      for (final dir in matchingSessionDirs) {
        createdSessionIds.add(dir.uri.pathSegments.where((segment) => segment.isNotEmpty).last);
      }
    });
  });

  group('TEST-004-011 No repository commit occurs during ingestion', () {
    test('the workflow never imports the repository commit path', () async {
      // Checks actual `import` statements only, not doc-comment prose --
      // this file's own doc comments *name* `CommitTransactionService`/
      // `CommitPlanService`/`FoundationBridge` to explain why the
      // workflow must never depend on them, which would make a bare
      // substring search over the whole file self-defeating.
      final source = await File(
        '${Directory.current.path}${Platform.pathSeparator}lib${Platform.pathSeparator}acquisition'
        '${Platform.pathSeparator}services${Platform.pathSeparator}reference_vault_ingestion_workflow.dart',
      ).readAsString();
      final importLines = source.split('\n').where((line) => line.trim().startsWith('import '));
      for (final line in importLines) {
        expect(line, isNot(contains('commit_transaction_service')));
        expect(line, isNot(contains('commit_plan_service')));
        expect(line, isNot(contains('foundation_bridge')));
      }
    });

    test('every resulting candidate stays pending, never accepted/committed', () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final outcome = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'No Commit',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );

      createdSessionIds.add(outcome.sessionRecord!.session.id);
      for (final candidate in outcome.sessionRecord!.candidates) {
        expect(candidate.status, KnowledgeCandidateStatus.pending);
        expect(candidate.committedObjectId, isNull);
      }
      expect(outcome.sessionRecord!.commitReports, isEmpty);
    });
  });

  group('TEST-004-013 TRX300 end-to-end production workflow', () {
    test(
      'EAM (mocked transport) -> AcquisitionApiClient -> ReferenceVaultAdapter -> real IngestionOrchestrator -> '
      'IngestionKnowledgeSessionBridge',
      () async {
        final bytes = await File(trx300Path).readAsBytes();
        final checksum = sha256.convert(bytes).toString();
        final client = buildClient(bytes: bytes, checksum: checksum);

        final outcome = await ReferenceVaultIngestionWorkflow.ingest(
          client: client,
          vaultObjectId: vaultId,
          sessionName: 'TRX300 Production Workflow',
          repositoryName: 'trx300-repo',
          author: 'engineer',
          ocrRunner: fakeOcrSuccess,
        );

        expect(outcome.isFailed, isFalse);
        expect(outcome.ingestionResult!.run.status, anyOf(IngestionRunStatus.completed, IngestionRunStatus.partial));
        expect(outcome.sessionRecord, isNotNull);
        createdSessionIds.add(outcome.sessionRecord!.session.id);
        expect(outcome.sessionRecord!.engineeringEntities, isNotEmpty);
        for (final candidate in outcome.sessionRecord!.candidates) {
          expect(candidate.status, KnowledgeCandidateStatus.pending);
        }

        final afterBytes = await File(trx300Path).readAsBytes();
        expect(afterBytes, orderedEquals(bytes));
      },
    );
  });

  group('TEST-004-014 Repeated ingestion does not mutate the Reference Vault artifact', () {
    test('two ingestions of the same Vault Object produce independent results without touching the source file',
        () async {
      final bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      final client = buildClient(bytes: bytes, checksum: checksum);

      final first = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'First Ingestion',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );
      final second = await ReferenceVaultIngestionWorkflow.ingest(
        client: client,
        vaultObjectId: vaultId,
        sessionName: 'Second Ingestion',
        repositoryName: 'repo',
        author: 'author',
        ocrRunner: fakeOcrSuccess,
      );

      expect(first.isFailed, isFalse);
      expect(second.isFailed, isFalse);
      createdSessionIds.add(first.sessionRecord!.session.id);
      createdSessionIds.add(second.sessionRecord!.session.id);
      expect(first.sessionRecord!.session.id, isNot(second.sessionRecord!.session.id));

      final afterBytes = await File(trx300Path).readAsBytes();
      expect(afterBytes, orderedEquals(bytes));
      expect(sha256.convert(afterBytes).toString(), checksum);
    });
  });
}
