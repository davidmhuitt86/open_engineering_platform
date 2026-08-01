import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exchange_api_exception.dart';

/// The Studio-side REST client for the Engineering Exchange
/// (`oep_exchange`) (WP-EXC-010). Mirrors `AcquisitionApiClient`'s own
/// role and shape exactly: the Exchange is an autonomous domain service
/// with its own PostgreSQL-backed persistence, reached only through its
/// published REST API (`docs/API_REFERENCE.md`-equivalent guides under
/// `oep_exchange/docs/guides/`) — this client never attempts to reach
/// the Exchange's database directly, and Studio integration happens at
/// exactly this service/API boundary. Deliberately hand-rolled to mirror
/// `packages/exchange_client`'s own TypeScript SDK (`HttpClient` +
/// per-resource classes) one-for-one, rather than generating Dart
/// bindings from it — there is no existing cross-language codegen
/// pipeline in this repository to build on, and duplicating five thin
/// methods by hand is smaller than introducing one.
///
/// A test may supply a fake `http.Client` exactly like
/// `AcquisitionApiClient` (`package:http/testing.dart`).
class ExchangeApiClient {
  ExchangeApiClient({required String baseUrl, http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$_baseUrl$path').replace(
        queryParameters: query?.isEmpty ?? true ? null : query,
      );

  Future<Map<String, Object?>> _getObject(String path, [Map<String, String>? query]) async {
    final response = await _send(() => _client.get(_uri(path, query)));
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> _postObject(String path, Map<String, Object?> body) async {
    final response = await _send(
      () => _client.post(_uri(path), headers: const {'content-type': 'application/json'}, body: jsonEncode(body)),
    );
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  /// Runs [request], translating connection/timeout failures and
  /// non-2xx responses into [ExchangeApiException] — the single place
  /// that decides what an Exchange failure means to a Studio caller,
  /// mirroring `AcquisitionApiClient._send`'s own role. Non-2xx bodies
  /// are parsed as the Exchange's `{"error": {"code", "message",
  /// "details"}}` envelope (`packages/api-contracts/src/errors.ts`)
  /// rather than EAM's own differently-shaped error body.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    late final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw ExchangeApiException.network('timed out after ${timeout.inSeconds}s');
    } on http.ClientException catch (error) {
      throw ExchangeApiException.network(error.message);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    String code = 'UNKNOWN_ERROR';
    String serviceMessage = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?>) {
          code = error['code'] as String? ?? code;
          serviceMessage = error['message'] as String? ?? '';
        }
      }
    } on FormatException {
      // Body wasn't JSON -- fall through with the generic code/message.
    }
    throw ExchangeApiException.service(
      statusCode: response.statusCode,
      code: code,
      serviceMessage: serviceMessage,
      technicalDetail: response.body,
    );
  }

  /// `GET /health` -- used for Settings' "Test Connection" and the
  /// workspace's own connection banner. Returns true only on HTTP 200.
  Future<bool> checkHealth() async {
    try {
      final response = await _send(() => _client.get(_uri('/health')));
      return response.statusCode == 200;
    } on ExchangeApiException {
      return false;
    }
  }

  Future<List<Map<String, Object?>>> listPublishers() async {
    final response = await _getObject('/publishers');
    return (response['publishers'] as List<Object?>? ?? const []).cast<Map<String, Object?>>();
  }

  Future<Map<String, Object?>> getPublisher(String id) => _getObject('/publishers/${Uri.encodeComponent(id)}');

  Future<List<Map<String, Object?>>> listPackages() async {
    final response = await _getObject('/packages');
    return (response['packages'] as List<Object?>? ?? const []).cast<Map<String, Object?>>();
  }

  Future<Map<String, Object?>> getPackage(String id) => _getObject('/packages/${Uri.encodeComponent(id)}');

  /// `GET /search` (`packages/exchange_client/src/search.ts`'s own
  /// param list) -- returns the full paginated envelope, not just the
  /// item list, since WP-EXC-010 §5's Search section needs pagination
  /// metadata.
  Future<Map<String, Object?>> search({
    String? q,
    String? publisherId,
    String? categoryId,
    String? status,
    String? sortBy,
    String? sortDirection,
    int? page,
    int? pageSize,
  }) {
    final query = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (publisherId != null) 'publisherId': publisherId,
      if (categoryId != null) 'categoryId': categoryId,
      if (status != null) 'status': status,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortDirection != null) 'sortDirection': sortDirection,
      if (page != null) 'page': page.toString(),
      if (pageSize != null) 'pageSize': pageSize.toString(),
    };
    return _getObject('/search', query);
  }

  /// `POST /packages/{id}/install` (`packages/api-contracts/src/installation.ts`).
  Future<Map<String, Object?>> install(String packageId, {String? version}) => _postObject(
        '/packages/${Uri.encodeComponent(packageId)}/install',
        version == null ? const {} : {'version': version},
      );

  Future<Map<String, Object?>> getInstallation(String installationId) =>
      _getObject('/installations/${Uri.encodeComponent(installationId)}');

  /// Builds (but does not fetch) the binary download URL -- mirrors
  /// `DownloadsResource.url` (`packages/exchange_client/src/downloads.ts`):
  /// downloading is meant to happen by navigating to this URL directly
  /// (an `<a href>`-equivalent on desktop, e.g. `url_launcher` or the
  /// platform file-save flow), not by fetching the binary into memory
  /// here.
  String downloadUrl(String packageId, {String? version}) {
    final path = version != null
        ? '/packages/${Uri.encodeComponent(packageId)}/versions/${Uri.encodeComponent(version)}/download'
        : '/packages/${Uri.encodeComponent(packageId)}/download';
    return _uri(path).toString();
  }

  /// Fetches the real artifact bytes from [downloadUrl] -- used by the
  /// Downloads section's actual "Download" action, as opposed to
  /// [downloadUrl] alone (which only builds the address).
  Future<List<int>> downloadBytes(String packageId, {String? version}) async {
    final path = version != null
        ? '/packages/${Uri.encodeComponent(packageId)}/versions/${Uri.encodeComponent(version)}/download'
        : '/packages/${Uri.encodeComponent(packageId)}/download';
    final response = await _send(() => _client.get(_uri(path)));
    return response.bodyBytes;
  }

  void dispose() => _client.close();
}
