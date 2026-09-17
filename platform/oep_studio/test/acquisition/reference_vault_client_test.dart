import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_client.dart';
import 'package:oep_studio/acquisition/services/acquisition_api_exception.dart';

/// WP-INGEST-003 § 22 TEST-RV-001 through TEST-RV-008 -- the Reference
/// Vault client boundary (`AcquisitionApiClient.getVaultEntry` /
/// `.downloadVaultArtifact`), exercised against a fake `http.Client`
/// (`package:http/testing.dart`'s `MockClient`), mirroring
/// `exchange_api_client_test.dart`/`anthropic_provider_test.dart`'s own
/// "fake the transport, not the business logic" convention -- no real
/// `oep_acquisition` process involved. This is explicitly a mocked/
/// isolated HTTP-boundary test, not a live EAM integration test (see the
/// AAR's "Production Vertical Slice" section for the distinction).
void main() {
  const vaultId = 'a1b2c3d4-0000-0000-0000-000000000001';
  final bytes = utf8.encode('%PDF-1.4 fake trx300 bytes');
  final checksum = sha256.convert(bytes).toString();

  Map<String, Object?> vaultEntryJson({String? sha256Hash, String status = 'Published'}) => {
    'id': vaultId,
    'metadata_id': 'metadata-1',
    'verification_id': 'verification-1',
    'download_session_id': 'download-1',
    'source_id': 'source-1',
    'sha256_hash': sha256Hash ?? checksum,
    'mime_type': 'application/pdf',
    'file_size_bytes': bytes.length,
    'status': status,
    'published_at': '2026-01-01T00:00:00Z',
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };

  group('AcquisitionApiClient.getVaultEntry (TEST-RV-001)', () {
    test('returns a valid Vault Entry with UUID, SHA-256, MIME type, size, status, metadata preserved', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://fake/api/vault/$vaultId');
          expect(request.method, 'GET');
          return http.Response(jsonEncode(vaultEntryJson()), 200);
        }),
        tokenReader: () async => 'test-token',
      );

      final entry = await client.getVaultEntry(vaultId);

      expect(entry.id, vaultId);
      expect(entry.sha256Hash, checksum);
      expect(entry.mimeType, 'application/pdf');
      expect(entry.fileSizeBytes, bytes.length);
      expect(entry.status, 'Published');
      expect(entry.metadataId, 'metadata-1');
      expect(entry.verificationId, 'verification-1');
      expect(entry.downloadSessionId, 'download-1');
      expect(entry.sourceId, 'source-1');
    });

    test('uses the existing Bearer-token authentication mechanism', () async {
      http.Request? captured;
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(vaultEntryJson()), 200);
        }),
        tokenReader: () async => 'secret-token',
      );
      await client.getVaultEntry(vaultId);
      expect(captured!.headers['authorization'], 'Bearer secret-token');
    });
  });

  group('AcquisitionApiClient.downloadVaultArtifact (TEST-RV-002)', () {
    test('returns valid bytes with checksum header present and locally computed SHA-256 matching it', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://fake/api/vault/$vaultId/artifact');
          return http.Response.bytes(
            bytes,
            200,
            headers: {'x-checksum-sha256': checksum, 'content-type': 'application/pdf'},
          );
        }),
        tokenReader: () async => 'test-token',
      );

      final artifact = await client.downloadVaultArtifact(vaultId);

      expect(artifact.bytes, bytes);
      expect(artifact.checksum, checksum);
      expect(artifact.checksum.toLowerCase(), sha256.convert(artifact.bytes).toString());
      expect(artifact.contentType, 'application/pdf');
      expect(artifact.contentLength, bytes.length);
    });

    test('checksum comparison is case-insensitive (TEST-RV-002 continued)', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient(
          (request) async => http.Response.bytes(bytes, 200, headers: {'x-checksum-sha256': checksum.toUpperCase()}),
        ),
        tokenReader: () async => 'test-token',
      );
      final artifact = await client.downloadVaultArtifact(vaultId);
      expect(artifact.checksum, checksum);
    });
  });

  group('TEST-RV-003 checksum mismatch', () {
    test('operation fails and the artifact is not accepted', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient(
          (request) async => http.Response.bytes(bytes, 200, headers: {'x-checksum-sha256': 'not-the-real-hash'}),
        ),
        tokenReader: () async => 'test-token',
      );

      await expectLater(
        client.downloadVaultArtifact(vaultId),
        throwsA(isA<AcquisitionApiException>().having((e) => e.technicalDetail, 'technicalDetail', contains('mismatch'))),
      );
    });
  });

  group('TEST-RV-004 missing checksum', () {
    test('fails integrity verification rather than silently accepting the artifact', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async => http.Response.bytes(bytes, 200)),
        tokenReader: () async => 'test-token',
      );

      await expectLater(
        client.downloadVaultArtifact(vaultId),
        throwsA(
          isA<AcquisitionApiException>().having(
            (e) => e.technicalDetail,
            'technicalDetail',
            contains('X-Checksum-Sha256'),
          ),
        ),
      );
    });
  });

  group('TEST-RV-005 Vault Entry 404', () {
    test('is a clear retrieval failure', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async => http.Response(jsonEncode({'error': 'not_found'}), 404)),
        tokenReader: () async => 'test-token',
      );

      await expectLater(
        client.getVaultEntry(vaultId),
        throwsA(isA<AcquisitionApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('TEST-RV-006 artifact 404', () {
    test('is a clear retrieval failure', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async => http.Response(jsonEncode({'error': 'not_found'}), 404)),
        tokenReader: () async => 'test-token',
      );

      await expectLater(
        client.downloadVaultArtifact(vaultId),
        throwsA(isA<AcquisitionApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('500 artifact_missing is surfaced as a retrieval failure, not converted into a parser failure', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient(
          (request) async => http.Response(jsonEncode({'error': 'artifact_missing'}), 500),
        ),
        tokenReader: () async => 'test-token',
      );

      await expectLater(
        client.downloadVaultArtifact(vaultId),
        throwsA(isA<AcquisitionApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  group('TEST-RV-007 authentication failure', () {
    test('401 uses the existing authentication-failure handling', () async {
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async => http.Response(jsonEncode({'error': 'unauthorized'}), 401)),
        tokenReader: () async => null,
      );

      await expectLater(
        client.getVaultEntry(vaultId),
        throwsA(isA<AcquisitionApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('TEST-RV-008 authorization failure', () {
    test('403 is surfaced clearly and is not retried', () async {
      var callCount = 0;
      final client = AcquisitionApiClient(
        baseUrl: 'http://fake/api',
        client: MockClient((request) async {
          callCount++;
          return http.Response(jsonEncode({'error': 'forbidden'}), 403);
        }),
        tokenReader: () async => 'test-token',
      );

      await expectLater(
        client.getVaultEntry(vaultId),
        throwsA(isA<AcquisitionApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
      expect(callCount, 1);
    });
  });
}
