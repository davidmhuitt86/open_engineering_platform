import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_client.dart';
import 'package:oep_studio/acquisition/services/reference_vault_adapter.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';
import 'package:oep_studio/ingestion/models/ingestion_run_status.dart';
import 'package:oep_studio/ingestion/services/ingestion_orchestrator.dart';
import 'package:oep_studio/knowledge/models/ocr_bounding_box.dart';
import 'package:oep_studio/knowledge/models/ocr_page_result.dart';
import 'package:oep_studio/knowledge/models/ocr_word.dart';
import 'package:oep_studio/knowledge/models/source_material.dart';

/// WP-INGEST-003 § 24/§ 25 -- Production Vertical Slice.
///
/// **This is a MOCKED/ISOLATED integration test, not a live EAM
/// integration test.** No `oep_acquisition` server process is started or
/// contacted. `AcquisitionApiClient`'s HTTP boundary is isolated with a
/// fake `http.Client` (`package:http/testing.dart`'s `MockClient`),
/// exactly like `reference_vault_client_test.dart` and
/// `reference_vault_adapter_test.dart` — per WP-INGEST-003 § 24: "Where a
/// real EAM server/test fixture is unavailable, isolate the HTTP boundary
/// using the repository's existing test mechanisms and clearly document
/// what was and was not exercised." This build/test machine has no
/// running/buildable `oep_acquisition` binary available to this test run,
/// and no `tesseract` executable (confirmed by
/// `ingestion_pipeline_test.dart`'s own top-of-file note, still true
/// here) — see this file's own `_fakeOcrSuccess` below for the same
/// injected-OCR-runner seam WP-INGEST-001/002 already established.
///
/// What genuinely IS exercised end-to-end, with no shortcuts or stubs of
/// its own:
///
///   - `AcquisitionApiClient.getVaultEntry` / `.downloadVaultArtifact`'s
///     real request-building, response-parsing, and SHA-256 verification
///     logic (only the transport is faked).
///   - `ReferenceVaultAdapter.materialize`'s real translation and
///     temporary-file materialization logic, against the REAL TRX300
///     PDF bytes read from `reference/ingestion/trx300/source/` (never
///     modified).
///   - The real, unmodified `IngestionOrchestrator.run` — the same
///     pipeline `ingestion_pipeline_test.dart` exercises — driven by the
///     `VaultObjectInput` the adapter produced, not `.fromFile`.
///
/// This proves the WP-INGEST-003 § 46 chain
/// `EAM -> AcquisitionApiClient -> Vault Adapter -> VaultObjectInput ->
/// UIF` is wired correctly end-to-end, with only the network leg
/// (EAM's actual process) unexercised in this environment.
void main() {
  final trx300Path =
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}'
      'reference${Platform.pathSeparator}ingestion${Platform.pathSeparator}trx300${Platform.pathSeparator}source'
      '${Platform.pathSeparator}trx300_factory_wiring_diagram.pdf';

  const vaultId = 'trx300-vault-entry-0001';

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

  setUpAll(() {
    expect(
      File(trx300Path).existsSync(),
      isTrue,
      reason: 'reference/ingestion/trx300/source/trx300_factory_wiring_diagram.pdf must exist and be unmodified.',
    );
  });

  test(
    'TRX300: EAM Reference Vault (mocked) -> AcquisitionApiClient -> checksum verification -> '
    'ReferenceVaultAdapter -> VaultObjectInput -> IngestionOrchestrator',
    () async {
      final trx300Bytes = await File(trx300Path).readAsBytes();
      final checksum = sha256.convert(trx300Bytes).toString();

      final client = AcquisitionApiClient(
        baseUrl: 'http://fake-eam/api',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/vault/$vaultId/artifact')) {
            return http.Response.bytes(
              trx300Bytes,
              200,
              headers: {'x-checksum-sha256': checksum, 'content-type': 'application/pdf'},
            );
          }
          if (path.endsWith('/vault/$vaultId')) {
            return http.Response(
              jsonEncode({
                'id': vaultId,
                'metadata_id': 'metadata-trx300',
                'verification_id': 'verification-trx300',
                'download_session_id': 'download-trx300',
                'source_id': 'source-trx300',
                'sha256_hash': checksum,
                'mime_type': 'application/pdf',
                'file_size_bytes': trx300Bytes.length,
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
                {'id': 'acq-record-trx300', 'download_session_id': 'download-trx300', 'status': 'Published'},
              ]),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        tokenReader: () async => 'test-token',
      );

      final input = await ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultId);
      addTearDown(() => ReferenceVaultAdapter.cleanupTemporaryFile(input));

      // Vault Identity (WP-INGEST-003 § 11).
      expect(input.vaultObjectId, vaultId);
      // Integrity (WP-INGEST-003 § 8/§ 12).
      expect(input.contentHash, checksum);
      expect(input.contentHash, sha256.convert(trx300Bytes).toString());
      // MIME/Artifact type (WP-INGEST-003 § 13).
      expect(input.mimeType, 'application/pdf');
      expect(input.artifactType, ArtifactType.pdf);
      // Provenance (WP-INGEST-003 § 16).
      expect(input.acquisitionRecordIds, ['acq-record-trx300']);
      // Storage reference is a local temp materialization, never an EAM path.
      expect(input.storageReference, isNot(contains('vault_path')));
      expect(input.storageReference, startsWith(Directory.systemTemp.path));

      final result = await IngestionOrchestrator.run(input: input, ocrRunner: fakeOcrSuccess);

      expect(result.run.vaultObjectId, vaultId);
      expect(result.run.status, anyOf(IngestionRunStatus.completed, IngestionRunStatus.partial));
      expect(result.structuralData.metadata.contentHash, checksum);
      expect(result.engineeringEntities, isNotEmpty);
      // Candidates remain pending review -- UIF must not commit anything
      // (WP-INGEST-003 § 20).
      for (final candidate in result.knowledgeCandidates) {
        expect(candidate.status.name, 'pending');
      }

      // The real TRX300 source file on disk was never modified.
      final afterBytes = await File(trx300Path).readAsBytes();
      expect(afterBytes, orderedEquals(trx300Bytes));
    },
  );
}
