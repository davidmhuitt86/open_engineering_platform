import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_client.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_exception.dart';
import 'package:oep_studio/acquisition/services/reference_vault_adapter.dart';
import 'package:oep_studio/ingestion/models/artifact_type.dart';

/// WP-INGEST-003 § 23 TEST-RV-009 through TEST-RV-011 -- the Reference
/// Vault Adapter boundary (`ReferenceVaultAdapter.materialize`), exercised
/// against a fake `http.Client` for both `AcquisitionApiClient` routes it
/// calls (`GET /vault/{id}`, `GET /vault/{id}/artifact`,
/// `GET /acquisition-records`). Mocked/isolated, exactly like
/// `reference_vault_client_test.dart` -- no real `oep_acquisition`
/// process involved.
void main() {
  const vaultId = 'b2c3d4e5-0000-0000-0000-000000000002';
  final bytes = utf8.encode('%PDF-1.4 fake trx300 bytes for adapter test');
  final checksum = sha256.convert(bytes).toString();

  AcquisitionApiClient buildClient({
    String mimeType = 'application/pdf',
    String downloadSessionId = 'download-9',
    List<Map<String, Object?>> acquisitionRecords = const [],
  }) {
    return AcquisitionApiClient(
      baseUrl: 'http://fake/api',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/vault/$vaultId/artifact')) {
          return http.Response.bytes(bytes, 200, headers: {'x-checksum-sha256': checksum, 'content-type': mimeType});
        }
        if (path.endsWith('/vault/$vaultId')) {
          return http.Response(
            jsonEncode({
              'id': vaultId,
              'metadata_id': 'metadata-9',
              'verification_id': 'verification-9',
              'download_session_id': downloadSessionId,
              'source_id': 'source-9',
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
          return http.Response(jsonEncode(acquisitionRecords), 200);
        }
        return http.Response('not found', 404);
      }),
      tokenReader: () async => 'test-token',
    );
  }

  group('TEST-RV-009 Vault Entry + verified artifact -> VaultObjectInput', () {
    test('vaultObjectId, contentHash, mimeType, acquisition identity, and metadata snapshot are all preserved', () async {
      final client = buildClient(
        acquisitionRecords: const [
          {'id': 'acq-record-77', 'download_session_id': 'download-9', 'status': 'Published'},
        ],
      );
      final input = await ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultId);
      addTearDown(() => ReferenceVaultAdapter.cleanupTemporaryFile(input));

      expect(input.vaultObjectId, vaultId, reason: 'Vault Entry UUID must become vaultObjectId exactly');
      expect(input.contentHash, checksum, reason: 'verified SHA-256 must become contentHash exactly');
      expect(input.mimeType, 'application/pdf');
      expect(input.artifactType, ArtifactType.pdf);
      expect(input.acquisitionRecordIds, ['acq-record-77']);
      expect(input.immutableMetadataSnapshot['vaultEntryId'], vaultId);
      expect(input.immutableMetadataSnapshot['sha256Hash'], checksum);
      expect(input.immutableMetadataSnapshot['mimeType'], 'application/pdf');
      expect(input.immutableMetadataSnapshot['downloadSessionId'], 'download-9');
      expect(input.immutableMetadataSnapshot['metadataId'], 'metadata-9');
      expect(input.immutableMetadataSnapshot['verificationId'], 'verification-9');
      expect(input.immutableMetadataSnapshot['sourceId'], 'source-9');
      expect(input.immutableMetadataSnapshot['status'], 'Published');
    });

    test('acquisition identity is an empty list, not a fabricated id, when no matching Acquisition Record exists',
        () async {
      final client = buildClient(acquisitionRecords: const []);
      final input = await ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultId);
      addTearDown(() => ReferenceVaultAdapter.cleanupTemporaryFile(input));

      expect(input.acquisitionRecordIds, isEmpty);
    });
  });

  group('TEST-RV-010 storageReference is a local working representation only', () {
    test('contains the verified bytes and no EAM server filesystem path', () async {
      final client = buildClient();
      final input = await ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultId);
      addTearDown(() => ReferenceVaultAdapter.cleanupTemporaryFile(input));

      // Never an EAM-owned vault_path -- it must live under this
      // process's own system temp directory, byte-for-byte identical to
      // the verified artifact.
      expect(input.storageReference, startsWith(Directory.systemTemp.path));
      final onDisk = await File(input.storageReference).readAsBytes();
      expect(onDisk, bytes);
      expect(sha256.convert(onDisk).toString(), checksum);
    });

    test('cleanupTemporaryFile removes the materialized file', () async {
      final client = buildClient();
      final input = await ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultId);
      expect(await File(input.storageReference).exists(), isTrue);
      await ReferenceVaultAdapter.cleanupTemporaryFile(input);
      expect(await File(input.storageReference).exists(), isFalse);
    });
  });

  group('TEST-RV-011 unsupported MIME type', () {
    test('is rejected at the adapter boundary, not falsely classified as PDF', () async {
      final client = buildClient(mimeType: 'application/octet-stream');
      await expectLater(
        ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultId),
        throwsA(isA<ReferenceVaultAdapterException>()),
      );
    });
  });

  group('integrity cross-check', () {
    test('a Vault Entry sha256_hash that disagrees with the artifact checksum is an integrity failure', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/vault/$vaultId/artifact')) {
            return http.Response.bytes(bytes, 200, headers: {'x-checksum-sha256': checksum});
          }
          if (path.endsWith('/vault/$vaultId')) {
            return http.Response(
              jsonEncode({
                'id': vaultId,
                'metadata_id': 'm',
                'verification_id': 'v',
                'download_session_id': 'd',
                'source_id': 's',
                'sha256_hash': 'deliberately-wrong-hash',
                'mime_type': 'application/pdf',
                'file_size_bytes': bytes.length,
                'status': 'Published',
                'published_at': '2026-01-01T00:00:00Z',
                'created_at': '2026-01-01T00:00:00Z',
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        tokenReader: () async => 'test-token',
      );

      await expectLater(
        ReferenceVaultAdapter.materialize(client: client, vaultObjectId: vaultId),
        throwsA(isA<AcquisitionApiException>()),
      );
    });
  });
}
