/// An EAM (`oep_acquisition`) REST API failure translated for display in
/// Studio (WP-PLAT-020) — mirrors `FoundationBridgeException`'s own
/// curated-message-plus-technical-detail shape, adapted for an HTTP
/// service boundary instead of an in-process FFI call. Studio never
/// shows a raw connection-refused message or a raw JSON error body to
/// the user; [message] is curated, [technicalDetail] is for logging
/// only.
class AcquisitionApiException implements Exception {
  AcquisitionApiException({required this.message, required this.technicalDetail, this.statusCode});

  /// A connection-level failure — EAM's process is unreachable
  /// (not running, wrong host/port, firewall, etc.).
  factory AcquisitionApiException.network(String technicalDetail) => AcquisitionApiException(
        message:
            'Could not reach the Engineering Acquisition service. Check that it is running and that the '
            'address in Settings > Engineering Acquisition is correct.',
        technicalDetail: technicalDetail,
      );

  /// A non-2xx response EAM itself returned (its own `{"error": ...,
  /// "message": ...}` REST error shape, see `oep_acquisition`'s
  /// `respond_error` convention).
  factory AcquisitionApiException.service({required int statusCode, required String technicalDetail}) =>
      AcquisitionApiException(
        message: switch (statusCode) {
          404 => 'The requested item couldn\'t be found.',
          422 => 'That request wasn\'t valid. Check the values and try again.',
          409 => 'That action conflicts with the current state of the item.',
          _ => 'The Engineering Acquisition service reported an error. Please try again.',
        },
        technicalDetail: technicalDetail,
        statusCode: statusCode,
      );

  /// An artifact integrity failure (WP-INGEST-003 § 8) — the bytes
  /// [AcquisitionApiClient.downloadVaultArtifact] received either had no
  /// `X-Checksum-Sha256` header at all, or their locally computed SHA-256
  /// did not match the header EAM sent. Either way the artifact is
  /// rejected outright: this exception is thrown *before*
  /// [AcquisitionApiClient.downloadVaultArtifact] returns, so no caller
  /// ever observes an unverified [DownloadedVaultArtifact] — the Universal
  /// Ingestion Framework is never invoked with it.
  factory AcquisitionApiException.integrity(String technicalDetail) => AcquisitionApiException(
        message: 'The downloaded Reference Vault artifact failed integrity verification and was rejected.',
        technicalDetail: technicalDetail,
      );

  final String message;
  final String technicalDetail;
  final int? statusCode;

  @override
  String toString() => 'AcquisitionApiException($statusCode): $message';
}
