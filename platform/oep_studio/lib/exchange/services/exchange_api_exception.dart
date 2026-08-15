/// An Engineering Exchange (`oep_exchange`) REST API failure translated
/// for display in Studio (WP-EXC-010) — mirrors
/// `AcquisitionApiException`'s own curated-message-plus-technical-detail
/// shape. Studio never shows a raw connection-refused message or a raw
/// JSON error body to the user; [message] is curated, [technicalDetail]
/// is for logging only. [code] carries the Exchange's own
/// `ApiErrorResponse.error.code` (e.g. `NOT_FOUND`, `VALIDATION_ERROR`)
/// when the failure is a service-level response rather than a network
/// failure.
class ExchangeApiException implements Exception {
  ExchangeApiException({required this.message, required this.technicalDetail, this.statusCode, this.code});

  /// A connection-level failure — `exchange-api` is unreachable (not
  /// running, wrong host/port, firewall, etc.).
  factory ExchangeApiException.network(String technicalDetail) => ExchangeApiException(
        message: 'Could not reach the Engineering Exchange service. Check that it is running and that the '
            'address in Settings > Engineering Exchange is correct.',
        technicalDetail: technicalDetail,
      );

  /// A non-2xx response `exchange-api` itself returned (its own
  /// `{"error": {"code", "message", "details"}}` envelope,
  /// `packages/api-contracts/src/errors.ts`).
  factory ExchangeApiException.service({
    required int statusCode,
    required String code,
    required String serviceMessage,
    required String technicalDetail,
  }) =>
      ExchangeApiException(
        message: switch (statusCode) {
          404 => 'The requested item couldn\'t be found.',
          422 || 400 => serviceMessage.isNotEmpty ? serviceMessage : 'That request wasn\'t valid. Check the values and try again.',
          409 => serviceMessage.isNotEmpty ? serviceMessage : 'That action conflicts with the current state of the item.',
          _ => 'The Engineering Exchange service reported an error. Please try again.',
        },
        technicalDetail: technicalDetail,
        statusCode: statusCode,
        code: code,
      );

  final String message;
  final String technicalDetail;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'ExchangeApiException($statusCode/$code): $message';
}
