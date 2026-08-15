import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'acquisition_api_exception.dart';

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
/// A test may supply a fake `http.Client` exactly like
/// `AnthropicProvider` (`package:http/testing.dart`).
class AcquisitionApiClient {
  AcquisitionApiClient({required String baseUrl, http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$_baseUrl$path').replace(
        queryParameters: query?.isEmpty ?? true ? null : query,
      );

  Future<List<Map<String, Object?>>> _getList(String path, [Map<String, String>? query]) async {
    final response = await _send(() => _client.get(_uri(path, query)));
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded.cast<Map<String, Object?>>();
  }

  Future<Map<String, Object?>> _postObject(String path, Map<String, Object?> body) async {
    final response = await _send(
      () => _client.post(_uri(path), headers: const {'content-type': 'application/json'}, body: jsonEncode(body)),
    );
    final decoded = jsonDecode(response.body);
    return decoded as Map<String, Object?>;
  }

  /// Runs [request], translating connection/timeout failures and
  /// non-2xx responses into [AcquisitionApiException] — the single
  /// place that decides what an EAM failure means to a Studio caller,
  /// mirroring `FoundationBridgeException.fromResult`'s own role.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    late final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw AcquisitionApiException.network('timed out after ${timeout.inSeconds}s');
    } on http.ClientException catch (error) {
      throw AcquisitionApiException.network(error.message);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw AcquisitionApiException.service(statusCode: response.statusCode, technicalDetail: response.body);
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

  Future<Map<String, Object?>> createSource(Map<String, Object?> body) => _postObject('/sources', body);

  Future<List<Map<String, Object?>>> listJobs({String? sourceId}) =>
      _getList('/jobs', sourceId == null ? null : {'source_id': sourceId});

  Future<Map<String, Object?>> createJob(Map<String, Object?> body) => _postObject('/jobs', body);

  Future<Map<String, Object?>> executeJob(String jobId) => _postObject('/jobs/$jobId/execute', const {});

  Future<Map<String, Object?>> cancelJob(String jobId) => _postObject('/jobs/$jobId/cancel', const {});

  Future<List<Map<String, Object?>>> listDownloads({String? jobId}) =>
      _getList('/downloads', jobId == null ? null : {'job_id': jobId});

  Future<Map<String, Object?>> startDownload(Map<String, Object?> body) => _postObject('/downloads', body);

  Future<List<Map<String, Object?>>> listVerifications({String? downloadSessionId}) =>
      _getList('/verifications', downloadSessionId == null ? null : {'download_session_id': downloadSessionId});

  Future<Map<String, Object?>> verify(String downloadSessionId) =>
      _postObject('/verifications', {'download_session_id': downloadSessionId});

  Future<List<Map<String, Object?>>> listMetadata({String? verificationId}) =>
      _getList('/metadata', verificationId == null ? null : {'verification_id': verificationId});

  Future<Map<String, Object?>> extractMetadata(String verificationId) =>
      _postObject('/metadata', {'verification_id': verificationId});

  Future<List<Map<String, Object?>>> listVault({String? metadataId}) =>
      _getList('/vault', metadataId == null ? null : {'metadata_id': metadataId});

  Future<Map<String, Object?>> publish(String metadataId) => _postObject('/vault', {'metadata_id': metadataId});

  void dispose() => _client.close();
}
