import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/core/services/foundation_runtime_service.dart';
import 'package:oep_studio/core/services/foundation_runtime_state.dart';
import 'package:oep_studio/exchange/services/exchange_runtime_service.dart';
import 'package:oep_studio/exchange/settings/exchange_settings.dart';
import 'package:oep_studio/exchange/settings/exchange_settings_provider.dart';

import 'fixtures/oep_package_fixture.dart';

/// WP-EXC-014 — Exchange RC1 End-to-End Verification.
///
/// Drives the REAL, unmodified production Studio orchestration
/// (`ExchangeRuntimeNotifier.search`/`.selectPackage`/`.installPackage`,
/// exactly what a user's own "Install" click runs) through the
/// documented RC1 vertical slice:
///
///   search -> package detail -> download -> checksum verification
///   -> ExchangeInstallBridge -> FoundationBridge.installPackage
///   -> Foundation package installer -> Repository registration
///   -> Engineering Objects/Relationships -> installed-package query
///
/// Two boundaries are deliberately not the literal production
/// dependency, both explicitly documented here rather than left
/// implicit:
///
/// 1. **The Exchange server.** The genuine `apps/exchange-api` Fastify
///    server requires a real PostgreSQL database matching
///    `db/README.md`'s documented `oep_exchange` role/database — this
///    sandbox's local PostgreSQL instance has no such role configured
///    (attempting to connect fails at SASL auth), exactly the same
///    pre-existing condition that already makes 17 of `apps/exchange-api`'s
///    own test files skip (`describe.skipIf(!databaseAvailable)`, per
///    `apps/exchange-api/src/persistence/test-support.ts`). Rather than
///    silently mask this the same way (which would mean the Foundation
///    half of RC1 never actually gets exercised end-to-end from a real
///    HTTP call), this test starts a minimal local `dart:io HttpServer`
///    implementing exactly the same wire contract Studio's real
///    `ExchangeApiClient` expects from the real server (same JSON
///    shapes, same `X-Checksum-Sha256` download header) — proving the
///    REAL `ExchangeApiClient`/`ExchangeRuntimeNotifier`/
///    `ExchangeInstallBridge`/`FoundationBridge` chain over a REAL
///    socket, with only the opposite HTTP endpoint substituted. The
///    genuine Postgres-backed server's own search/detail/download
///    behavior (independent of Foundation) is proven separately, for
///    real, in `apps/exchange-api/src/e2e/exchange-rc1-vertical-slice.test.ts`
///    (gated by the exact same, pre-existing `describe.skipIf` convention).
/// 2. **The package archive.** Reuses WP-EXC-013's own hand-built
///    Stored-ZIP `.oep` fixture (`test/fixtures/oep_package_fixture.dart`)
///    verbatim — no second fixture format.
///
/// The Foundation half — `FoundationBridge.installPackage` through
/// Repository registration and Engineering Object/Relationship
/// creation — is 100% real: the actual, synced `oep_foundation_bridge.dll`
/// (see WP-EXC-013A; run `flutter build windows --debug` then `dart run
/// tool/sync_foundation_bridge_dll.dart` first), the actual FFI calls,
/// the actual C++ installer. Skips (rather than failing) only if that
/// DLL cannot be loaded at all in this environment, and FAILS (per
/// WP-EXC-013A's own hardening) if it loads but is stale/incompatible.
void main() {
  late Directory repoRoot;
  late ProviderContainer container;
  _LocalExchangeServer? server;

  tearDown(() async {
    await server?.stop();
    container.dispose();
    if (repoRoot.existsSync()) {
      repoRoot.deleteSync(recursive: true);
    }
  });

  /// Sets up a fresh real Foundation repository and a real
  /// `ProviderContainer` wired with the production
  /// `FoundationRuntimeNotifier`/`ExchangeRuntimeNotifier`, pointed at
  /// [server]'s base URL. Returns `null` (after calling
  /// `markTestSkipped`/`fail` as appropriate — see
  /// `_classifyFoundationAvailability`) if Foundation is not usable in
  /// this environment.
  Future<ProviderContainer?> setUpRealStack(_LocalExchangeServer localServer) async {
    repoRoot = Directory.systemTemp.createTempSync('oep_rc1_e2e_');
    File('${repoRoot.path}${Platform.pathSeparator}repository.json').writeAsStringSync(
      '{"repositoryId":"2c8f3a10-1111-4222-8333-000000000099",'
      '"repositoryName":"rc1-e2e",'
      '"repositoryVersion":"1.0.0",'
      '"foundationVersion":"0.1.0",'
      '"templateVersion":"1.0",'
      '"createdUtc":"2026-01-01T00:00:00Z",'
      '"lastModifiedUtc":"2026-01-01T00:00:00Z"}',
    );

    container = ProviderContainer(
      overrides: [
        exchangeSettingsProvider.overrideWith(() => _FixedExchangeSettingsNotifier(localServer.baseUrl)),
      ],
    );

    final foundationState = container.read(foundationRuntimeServiceProvider);
    if (foundationState.phase == FoundationConnectionPhase.error) {
      final detail = foundationState.lastError?.technicalDetail ?? '';
      if (detail.contains('Failed to lookup symbol')) {
        fail(
          'oep_foundation_bridge.dll loaded but is stale/incompatible with the current Foundation API '
          '($detail). Run `flutter build windows --debug` then `dart run '
          'tool/sync_foundation_bridge_dll.dart` -- see docs/tasks/WP-EXC-013A.md.',
        );
      }
      markTestSkipped(
        'oep_foundation_bridge.dll is not present in this environment (Foundation was not built here).',
      );
      return null;
    }

    container.read(foundationRuntimeServiceProvider.notifier).openRepository(repoRoot.path);
    return container;
  }

  test('AC-01..11: the full RC1 vertical slice installs a real package through Foundation', () async {
    final packageId = 'com.exchange.rc1.e2e.valid';
    final archiveBytes = buildDemoOepPackage(packageId);
    final checksum = sha256.convert(archiveBytes).toString();

    server = _LocalExchangeServer(packageId: packageId, version: '1.0.0', archiveBytes: archiveBytes, checksumHeader: checksum);
    await server!.start();

    final c = await setUpRealStack(server!);
    if (c == null) return;

    // AC-01: real search finds the package through the real Exchange client.
    await c.read(exchangeRuntimeServiceProvider.notifier).search(q: packageId);
    final searchState = c.read(exchangeRuntimeServiceProvider);
    expect(searchState.lastError, isNull, reason: searchState.lastError);
    expect(searchState.searchResults.items.map((item) => item.packageId), contains(packageId));

    // AC-02: real package detail through the real Exchange client.
    await c.read(exchangeRuntimeServiceProvider.notifier).selectPackage(packageId);
    final detailState = c.read(exchangeRuntimeServiceProvider);
    expect(detailState.lastError, isNull, reason: detailState.lastError);
    expect(detailState.selectedPackage?.packageId, packageId);

    // AC-03..AC-10: real download, real checksum verification, real
    // Foundation install, real Repository registration, real Engineering
    // Object/Relationship creation -- all through
    // `ExchangeRuntimeNotifier.installPackage`, the exact production
    // method Studio's own "Install" button calls.
    await c.read(exchangeRuntimeServiceProvider.notifier).installPackage(packageId, 'RC1 E2E Demo Package');
    final installState = c.read(exchangeRuntimeServiceProvider);
    final installation = installState.selectedPackageInstallation;
    expect(installation, isNotNull);
    expect(installation!.isCompleted, isTrue, reason: installation.errorMessage);
    // Foundation's own identity, not Exchange's request parameters.
    expect(installation.repositoryPackageId, '$packageId@1.0.0');

    final bridge = c.read(foundationRuntimeServiceProvider.notifier).bridge!;
    expect(bridge.getObjectCount(), 2); // AC-09
    expect(bridge.getRelationshipCount(), 1); // AC-10

    // AC-11: the installed package is observable through Foundation's
    // existing installed-package query mechanism.
    final installed = bridge.listInstalledPackages();
    expect(installed.map((entry) => entry.packageId), contains(packageId));
  });

  test('AC-12: a second install of the same package is reported as already installed, not duplicated', () async {
    final packageId = 'com.exchange.rc1.e2e.duplicate';
    final archiveBytes = buildDemoOepPackage(packageId);
    final checksum = sha256.convert(archiveBytes).toString();

    server = _LocalExchangeServer(packageId: packageId, version: '1.0.0', archiveBytes: archiveBytes, checksumHeader: checksum);
    await server!.start();

    final c = await setUpRealStack(server!);
    if (c == null) return;

    await c.read(exchangeRuntimeServiceProvider.notifier).installPackage(packageId, 'Duplicate Demo');
    final first = c.read(exchangeRuntimeServiceProvider).selectedPackageInstallation;
    expect(first?.isCompleted, isTrue, reason: first?.errorMessage);

    final bridge = c.read(foundationRuntimeServiceProvider.notifier).bridge!;
    final objectsAfterFirst = bridge.getObjectCount();

    await c.read(exchangeRuntimeServiceProvider.notifier).installPackage(packageId, 'Duplicate Demo');
    final second = c.read(exchangeRuntimeServiceProvider).selectedPackageInstallation;
    expect(second?.isFailed, isTrue);
    expect(second?.errorMessage, contains('already installed'));

    // AC-14: no partial/duplicate state -- object count is unchanged by
    // the rejected second attempt.
    expect(bridge.getObjectCount(), objectsAfterFirst);
  });

  test('AC-13/AC-14: a corrupt package is rejected by the real Foundation installer, with no partial state', () async {
    final packageId = 'com.exchange.rc1.e2e.corrupt';
    final corruptBytes = buildCorruptOepPackage();
    final checksum = sha256.convert(corruptBytes).toString();

    server = _LocalExchangeServer(packageId: packageId, version: '1.0.0', archiveBytes: corruptBytes, checksumHeader: checksum);
    await server!.start();

    final c = await setUpRealStack(server!);
    if (c == null) return;

    await c.read(exchangeRuntimeServiceProvider.notifier).installPackage(packageId, 'Corrupt Demo');
    final installation = c.read(exchangeRuntimeServiceProvider).selectedPackageInstallation;
    expect(installation?.isFailed, isTrue);

    final bridge = c.read(foundationRuntimeServiceProvider.notifier).bridge!;
    expect(bridge.getObjectCount(), 0);
    expect(bridge.listInstalledPackages(), isEmpty);
  });

  test('AC-05: a checksum mismatch is rejected before Foundation is ever invoked, with no partial state', () async {
    final packageId = 'com.exchange.rc1.e2e.checksum';
    final archiveBytes = buildDemoOepPackage(packageId);

    server = _LocalExchangeServer(
      packageId: packageId,
      version: '1.0.0',
      archiveBytes: archiveBytes,
      checksumHeader: '0' * 64, // deliberately wrong
    );
    await server!.start();

    final c = await setUpRealStack(server!);
    if (c == null) return;

    await c.read(exchangeRuntimeServiceProvider.notifier).installPackage(packageId, 'Checksum Mismatch Demo');
    final installation = c.read(exchangeRuntimeServiceProvider).selectedPackageInstallation;
    expect(installation?.isFailed, isTrue);
    expect(installation?.errorMessage, contains('does not match the checksum'));

    final bridge = c.read(foundationRuntimeServiceProvider.notifier).bridge!;
    expect(bridge.getObjectCount(), 0);
  });
}

/// Never touches disk (`ExchangeSettingsNotifier.build()`'s own
/// `_load()` is skipped entirely), so this test's chosen local server
/// URL is never raced by an async settings-file read.
class _FixedExchangeSettingsNotifier extends ExchangeSettingsNotifier {
  _FixedExchangeSettingsNotifier(this._baseUrl);
  final String _baseUrl;

  @override
  ExchangeSettings build() => ExchangeSettings(apiBaseUrl: _baseUrl);
}

/// A minimal, real, socket-bound HTTP server implementing exactly the
/// wire contract `ExchangeApiClient` expects from the real, Postgres-backed
/// `apps/exchange-api` (see this file's own top-level doc comment for
/// why it stands in for that server in this sandbox). Not a mock of
/// `ExchangeApiClient` or any Studio code -- a real `dart:io HttpServer`
/// a real `http.Client` genuinely connects to over a real loopback socket.
class _LocalExchangeServer {
  _LocalExchangeServer({
    required this.packageId,
    required this.version,
    required this.archiveBytes,
    required this.checksumHeader,
  });

  final String packageId;
  final String version;
  final List<int> archiveBytes;
  final String checksumHeader;

  HttpServer? _server;
  String get baseUrl => 'http://127.0.0.1:${_server!.port}/api/v1';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _serve();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  void _serve() {
    _server!.listen((request) async {
      final path = request.uri.path;
      try {
        if (path == '/api/v1/search') {
          _writeJson(request.response, 200, {
            'items': [
              {
                'id': packageId,
                'packageId': packageId,
                'publisherId': 'rc1-e2e-publisher',
                'publisherName': 'RC1 E2E Publisher',
                'displayName': 'RC1 E2E Demo Package',
                'description': 'd',
                'categoryId': 'demonstration',
                'categoryName': 'Demonstration',
                'currentVersion': version,
                'status': 'published',
                'createdAt': '2026-01-01T00:00:00Z',
                'updatedAt': '2026-01-01T00:00:00Z',
              },
            ],
            'totalCount': 1,
            'totalPages': 1,
            'currentPage': 1,
            'pageSize': 20,
          });
        } else if (path == '/api/v1/packages/$packageId') {
          _writeJson(request.response, 200, {
            'id': packageId,
            'packageId': packageId,
            'publisherId': 'rc1-e2e-publisher',
            'displayName': 'RC1 E2E Demo Package',
            'description': 'd',
            'categoryId': 'demonstration',
            'currentVersion': version,
            'status': 'published',
            'createdAt': '2026-01-01T00:00:00Z',
            'updatedAt': '2026-01-01T00:00:00Z',
          });
        } else if (path == '/api/v1/packages/$packageId/install' && request.method == 'POST') {
          // Mirrors the real (currently simulated) install route's own
          // immediate-"completed" response -- exactly what
          // `ExchangeInstallBridge` (WP-EXC-013) exists to correct with
          // the real Foundation outcome.
          _writeJson(request.response, 200, {
            'id': 'install-${DateTime.now().microsecondsSinceEpoch}',
            'packageId': packageId,
            'version': version,
            'status': 'completed',
            'repositoryPackageId': 'stub-$packageId@$version',
            'errorMessage': null,
            'requestedAt': '2026-01-01T00:00:00Z',
            'completedAt': '2026-01-01T00:00:01Z',
          });
        } else if (path == '/api/v1/packages/$packageId/download') {
          request.response.statusCode = 200;
          request.response.headers.set('Content-Type', 'application/vnd.oep.package');
          request.response.headers.set('X-Checksum-Sha256', checksumHeader);
          request.response.headers.set('X-Package-Id', packageId);
          request.response.headers.set('X-Package-Version', version);
          request.response.add(archiveBytes);
          await request.response.close();
        } else {
          _writeJson(request.response, 404, {
            'error': {'code': 'NOT_FOUND', 'message': 'no such route in this local RC1 E2E test server'},
          });
        }
      } catch (error) {
        _writeJson(request.response, 500, {
          'error': {'code': 'INTERNAL_ERROR', 'message': error.toString()},
        });
      }
    });
  }

  void _writeJson(HttpResponse response, int statusCode, Object? body) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }
}
