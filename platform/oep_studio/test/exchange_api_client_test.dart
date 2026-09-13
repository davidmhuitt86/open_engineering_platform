import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oep_studio/exchange/services/exchange_api_client.dart';
import 'package:oep_studio/exchange/services/exchange_api_exception.dart';

/// Exercises `ExchangeApiClient`'s own request-building/response-parsing/
/// error-mapping logic against a fake `http.Client`
/// (`package:http/testing.dart`'s `MockClient`), mirroring
/// `anthropic_provider_test.dart`'s own "fake the transport, not the
/// business logic" approach — no real `exchange-api` process involved.
void main() {
  group('ExchangeApiClient', () {
    test('checkHealth returns true only on HTTP 200', () async {
      final client = ExchangeApiClient(
        baseUrl: 'http://fake/api/v1',
        client: MockClient((request) async => http.Response('', 200)),
      );
      expect(await client.checkHealth(), isTrue);
    });

    test('checkHealth returns false on a non-2xx response', () async {
      final client = ExchangeApiClient(
        baseUrl: 'http://fake/api/v1',
        client: MockClient((request) async => http.Response('', 503)),
      );
      expect(await client.checkHealth(), isFalse);
    });

    test('listPackages unwraps the {packages: [...]} envelope', () async {
      final client = ExchangeApiClient(
        baseUrl: 'http://fake/api/v1',
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://fake/api/v1/packages');
          return http.Response(
            jsonEncode({
              'packages': [
                {'id': 'p1', 'packageId': 'com.example.p1', 'displayName': 'Package One'},
              ],
            }),
            200,
          );
        }),
      );
      final packages = await client.listPackages();
      expect(packages, hasLength(1));
      expect(packages.single['id'], 'p1');
    });

    test('install posts version when provided and an empty body otherwise', () async {
      http.Request? captured;
      final client = ExchangeApiClient(
        baseUrl: 'http://fake/api/v1',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'id': 'install-1', 'status': 'completed'}), 201);
        }),
      );
      await client.install('pkg-1', version: '1.0.0');
      expect(captured!.url.toString(), 'http://fake/api/v1/packages/pkg-1/install');
      expect(jsonDecode(captured!.body), {'version': '1.0.0'});

      await client.install('pkg-1');
      expect(jsonDecode(captured!.body), <String, Object?>{});
    });

    test('downloadUrl builds the versioned path when a version is given', () {
      final client = ExchangeApiClient(baseUrl: 'http://fake/api/v1');
      expect(client.downloadUrl('pkg-1'), 'http://fake/api/v1/packages/pkg-1/download');
      expect(client.downloadUrl('pkg-1', version: '2.0.0'), 'http://fake/api/v1/packages/pkg-1/versions/2.0.0/download');
    });

    test('a non-2xx response is translated into ExchangeApiException with the service error code/message', () async {
      final client = ExchangeApiClient(
        baseUrl: 'http://fake/api/v1',
        client: MockClient((request) async => http.Response(
              jsonEncode({
                'error': {'code': 'NOT_FOUND', 'message': 'Package "x" was not found.'},
              }),
              404,
            )),
      );
      await expectLater(
        client.getPackage('x'),
        throwsA(isA<ExchangeApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.code, 'code', 'NOT_FOUND')),
      );
    });

    test('a connection failure is translated into a network ExchangeApiException', () async {
      final client = ExchangeApiClient(
        baseUrl: 'http://fake/api/v1',
        client: MockClient((request) async => throw http.ClientException('connection refused')),
      );
      await expectLater(client.checkHealth(), completion(isFalse));
      await expectLater(
        client.listPackages(),
        throwsA(isA<ExchangeApiException>().having((e) => e.statusCode, 'statusCode', isNull)),
      );
    });

    group('downloadArtifact (WP-EXC-013)', () {
      test('returns the body bytes and the X-Checksum-Sha256 header', () async {
        final client = ExchangeApiClient(
          baseUrl: 'http://fake/api/v1',
          client: MockClient((request) async {
            expect(request.url.toString(), 'http://fake/api/v1/packages/pkg-1/download');
            return http.Response.bytes(
              [1, 2, 3, 4],
              200,
              headers: {'x-checksum-sha256': 'abc123'},
            );
          }),
        );
        final artifact = await client.downloadArtifact('pkg-1');
        expect(artifact.bytes, [1, 2, 3, 4]);
        expect(artifact.sha256, 'abc123');
      });

      test('requests the versioned download route when a version is given', () async {
        final client = ExchangeApiClient(
          baseUrl: 'http://fake/api/v1',
          client: MockClient((request) async {
            expect(request.url.toString(), 'http://fake/api/v1/packages/pkg-1/versions/2.0.0/download');
            return http.Response.bytes([9], 200, headers: {'x-checksum-sha256': 'deadbeef'});
          }),
        );
        final artifact = await client.downloadArtifact('pkg-1', version: '2.0.0');
        expect(artifact.sha256, 'deadbeef');
      });

      test('throws a network ExchangeApiException when the checksum header is missing', () async {
        final client = ExchangeApiClient(
          baseUrl: 'http://fake/api/v1',
          client: MockClient((request) async => http.Response.bytes([1], 200)),
        );
        await expectLater(
          client.downloadArtifact('pkg-1'),
          throwsA(isA<ExchangeApiException>().having((e) => e.statusCode, 'statusCode', isNull)),
        );
      });
    });
  });
}
