import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/security/credential_service.dart';
import '../models/downloaded_vault_artifact.dart';
import '../models/vault_entry_record.dart';
import 'acquisition_api_exception.dart';

/// `CredentialService` provider id under which EAM's Bearer token is
/// stored (Windows Credential Manager target
/// `oep_studio/credential/$acquisitionApiTokenCredentialId`) -- reused by
/// the Engineering Acquisition settings page so both sides agree on
/// where the token lives without this client exposing `CredentialStore`
/// itself as part of its public surface.
const acquisitionApiTokenCredentialId = 'engineering_acquisition_api_token';

/// The Studio-side REST client for EAM (`oep_acquisition`) (WP-PLAT-020).
///
/// Per the Architectural Notes accompanying this Work Package: EAM is an
/// autonomous domain service with its own PostgreSQL-backed persistence,
/// reached only through its published REST API
/// (`docs/API_REFERENCE.md`/`ADR-0007` Platform API Strategy) — this
/// client never attempts to reach EAM's database directly, and Studio
/// integration happens at exactly this service/API boundary, mirroring
/// how `AnthropicProvider` reaches Anthropic's Messages API rather than
/// any Anthropic-internal implementation detail.
///
/// EAM enforces its own bearer-token authentication boundary (ADR-0002)
/// on every route except `GET /health`. This client reads the token
/// fresh from `CredentialService` on every request (never caches it),
/// mirroring `AnthropicProvider`'s own `ApiKeyReader` pattern, so a token
/// saved/changed/removed on the Engineering Acquisition settings page
/// takes effect on the very next request with no client rebuild needed.
/// A request made with no token configured is simply sent without an
/// `Authorization` header -- EAM will reject it with 401, surfaced to
/// the caller as an ordinary [AcquisitionApiException], not a special
/// case here.
///
/// A test may supply a fake `http.Client` exactly like
/// `AnthropicProvider` (`package:http/testing.dart`), and/or a fake
/// [tokenReader] to avoid touching the real OS credential store.
class AcquisitionApiClient {
  AcquisitionApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    this.longOperationTimeout = const Duration(minutes: 10),
    Future<String?> Function()? tokenReader,
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _client = client ?? http.Client(),
        _tokenReader = tokenReader ??
            (() => CredentialService.instance
                .readCredential(acquisitionApiTokenCredentialId));

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  /// Server-side work whose duration scales with the artifact (hashing,
  /// metadata extraction, download, vault publish) -- a large document
  /// legitimately takes longer than the ordinary request [timeout].
  final Duration longOperationTimeout;
  final Future<String?> Function() _tokenReader;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(
        queryParameters: query?.isEmpty ?? true ? null : query,
      );

  Future<Map<String, String>> _headers([Map<String, String>? extra]) async {
    final token = await _tokenReader();
    return {
      if (extra != null) ...extra,
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, Object?>>> _getList(String path,
      [Map<String, String>? query]) async {
    final response = await _send(
        () async => _client.get(_uri(path, query), headers: await _headers()));
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded.cast<Map<String, Object?>>();
  }

  Future<Map<String, Object?>> _getObject(String path) async {
    final response = await _send(
        () async => _client.get(_uri(path), headers: await _headers()));
    final decoded = jsonDecode(response.body);
    return decoded as Map<String, Object?>;
  }

  Future<Map<String, Object?>> _postObject(
      String path, Map<String, Object?> body,
      {bool longRunning = false}) async {
    final response = await _send(
      () async => _client.post(_uri(path),
          headers: await _headers(const {'content-type': 'application/json'}),
          body: jsonEncode(body)),
      timeout: longRunning ? longOperationTimeout : null,
    );
    final decoded = jsonDecode(response.body);
    return decoded as Map<String, Object?>;
  }

  /// Runs [request], translating connection/timeout failures and
  /// non-2xx responses into [AcquisitionApiException] — the single
  /// place that decides what an EAM failure means to a Studio caller,
  /// mirroring `FoundationBridgeException.fromResult`'s own role.
  Future<http.Response> _send(Future<http.Response> Function() request,
      {Duration? timeout}) async {
    final limit = timeout ?? this.timeout;
    late final http.Response response;
    try {
      response = await request().timeout(limit);
    } on TimeoutException {
      throw AcquisitionApiException.network(
          'timed out after ${limit.inSeconds}s');
    } on http.ClientException catch (error) {
      throw AcquisitionApiException.network(error.message);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw AcquisitionApiException.service(
        statusCode: response.statusCode, technicalDetail: response.body);
  }

  /// `GET /health` — used for Settings' "Test Connection" and the
  /// workspace's own connection banner. Returns true only on HTTP 200.
  Future<bool> checkHealth() async {
    try {
      final response = await _send(() => _client.get(_uri('/health')));
      return response.statusCode == 200;
    } on AcquisitionApiException {
      return false;
    }
  }

  Future<List<Map<String, Object?>>> listSources() => _getList('/sources');

  Future<Map<String, Object?>> createSource(Map<String, Object?> body) =>
      _postObject('/sources', body);

  Future<List<Map<String, Object?>>> listJobs({String? sourceId}) =>
      _getList('/jobs', sourceId == null ? null : {'source_id': sourceId});

  Future<Map<String, Object?>> createJob(Map<String, Object?> body) =>
      _postObject('/jobs', body);

  Future<Map<String, Object?>> executeJob(String jobId) =>
      _postObject('/jobs/$jobId/execute', const {}, longRunning: true);

  Future<Map<String, Object?>> cancelJob(String jobId) =>
      _postObject('/jobs/$jobId/cancel', const {});

  Future<List<Map<String, Object?>>> listDownloads({String? jobId}) =>
      _getList('/downloads', jobId == null ? null : {'job_id': jobId});

  Future<Map<String, Object?>> startDownload(Map<String, Object?> body) =>
      _postObject('/downloads', body, longRunning: true);

  Future<List<Map<String, Object?>>> listVerifications(
          {String? downloadSessionId}) =>
      _getList(
          '/verifications',
          downloadSessionId == null
              ? null
              : {'download_session_id': downloadSessionId});

  Future<Map<String, Object?>> verify(String downloadSessionId) =>
      _postObject('/verifications', {'download_session_id': downloadSessionId},
          longRunning: true);

  Future<List<Map<String, Object?>>> listMetadata({String? verificationId}) =>
      _getList('/metadata',
          verificationId == null ? null : {'verification_id': verificationId});

  Future<Map<String, Object?>> extractMetadata(String verificationId) =>
      _postObject('/metadata', {'verification_id': verificationId},
          longRunning: true);

  Future<List<Map<String, Object?>>> listVault({String? metadataId}) =>
      _getList(
          '/vault', metadataId == null ? null : {'metadata_id': metadataId});

  Future<Map<String, Object?>> publish(String metadataId) =>
      _postObject('/vault', {'metadata_id': metadataId}, longRunning: true);

  /// `GET /vault/{id}` (WP-INGEST-003 § 6) — retrieves one authoritative
  /// Vault Entry. Reuses the existing [VaultEntryRecord] model
  /// (`acquisition/models/vault_entry_record.dart`), which already mirrors
  /// `oep_acquisition`'s `vault::to_json` shape exactly (including the
  /// fact that the server never sends `vault_path` — see that model's own
  /// doc comment and `vault_entry_json.cpp`'s WP-SRV-002 note), so no new
  /// Vault Entry model is introduced here.
  ///
  /// A 404 response (no such Vault Entry) surfaces as an
  /// [AcquisitionApiException] with `statusCode == 404`, exactly like
  /// every other not-found response this client already produces — the
  /// caller (the Reference Vault Adapter) treats that as a retrieval
  /// failure and never constructs a `VaultObjectInput` from it.
  Future<VaultEntryRecord> getVaultEntry(String vaultObjectId) async {
    final json = await _getObject('/vault/$vaultObjectId');
    return VaultEntryRecord.fromJson(json);
  }

  /// `GET /vault/{id}/artifact` (WP-INGEST-003 § 7/§ 8) — retrieves the
  /// actual immutable artifact bytes and mandatorily verifies them before
  /// returning.
  ///
  /// The verification rule (WP-INGEST-003 § 8) is exact:
  /// `SHA256(received bytes) == X-Checksum-Sha256` (case-insensitively).
  /// The exact bytes `http.Response.bodyBytes` returns are hashed --
  /// never a decoded/re-encoded/transformed representation. A missing
  /// header or a mismatch both throw [AcquisitionApiException.integrity]
  /// *before* this method returns, so no caller can ever observe an
  /// unverified [DownloadedVaultArtifact] -- satisfying "the client must
  /// not silently continue after checksum failure" and "do not invoke UIF
  /// with an unverified/rejected artifact".
  Future<DownloadedVaultArtifact> downloadVaultArtifact(
      String vaultObjectId) async {
    final response = await _send(
      () async => _client.get(_uri('/vault/$vaultObjectId/artifact'),
          headers: await _headers()),
    );
    final serverChecksum = response.headers['x-checksum-sha256'];
    if (serverChecksum == null || serverChecksum.trim().isEmpty) {
      throw AcquisitionApiException.integrity(
        'GET /vault/$vaultObjectId/artifact response is missing the required X-Checksum-Sha256 header.',
      );
    }
    final bytes = response.bodyBytes;
    final computedChecksum = sha256.convert(bytes).toString();
    if (computedChecksum.toLowerCase() != serverChecksum.trim().toLowerCase()) {
      throw AcquisitionApiException.integrity(
        'SHA-256 mismatch for vault object $vaultObjectId: computed $computedChecksum but server '
        'reported $serverChecksum.',
      );
    }
    return DownloadedVaultArtifact(
      bytes: bytes,
      checksum: computedChecksum,
      contentType: response.headers['content-type'] ?? '',
      contentLength: bytes.length,
    );
  }

  /// `GET /acquisition-records` (WP-INGEST-003 § 16) -- the only
  /// authoritative EAM route that exposes Acquisition Record identity.
  /// `GET /vault/{id}` itself does not include an acquisition-record id
  /// (confirmed against `vault_entry_json.cpp`'s `to_json`, which emits
  /// only `download_session_id`, not an Acquisition Record id) --
  /// resolving it requires correlating a Vault Entry's
  /// `download_session_id` against this list, since
  /// `/acquisition-records` supports filtering by `status` only, not by
  /// `download_session_id` (see `parse_acquisition_record_filter` in
  /// `services/acquisition/src/api/server.cpp`). The Reference Vault
  /// Adapter performs that correlation; this method only exposes the
  /// authoritative list, mirroring every other `list*` method above.
  Future<List<Map<String, Object?>>> listAcquisitionRecords({String? status}) =>
      _getList(
          '/acquisition-records', status == null ? null : {'status': status});

  void dispose() => _client.close();
}
