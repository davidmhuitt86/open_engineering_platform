import 'dart:typed_data';

/// The verified result of `AcquisitionApiClient.downloadVaultArtifact`
/// (WP-INGEST-003 § 9) — a small, focused transport result carrying only
/// what the Reference Vault Adapter needs to build a `VaultObjectInput`.
/// It never appears until *after* [AcquisitionApiClient] has already
/// verified [checksum] against the server's `X-Checksum-Sha256` header, so
/// simply holding one of these is itself proof the bytes were verified.
///
/// Deliberately inert: no OCR, parsing, candidate generation, or
/// persistence behavior belongs here (WP-INGEST-003 § 9). It is transport
/// data, nothing else.
class DownloadedVaultArtifact {
  const DownloadedVaultArtifact({
    required this.bytes,
    required this.checksum,
    required this.contentType,
    required this.contentLength,
  });

  /// The exact bytes returned by `GET /vault/{id}/artifact` — never a
  /// re-encoded, decoded, or otherwise transformed representation.
  final Uint8List bytes;

  /// The locally computed SHA-256 hex digest of [bytes], already verified
  /// (case-insensitively) against the server's `X-Checksum-Sha256` header
  /// by the time this object exists.
  final String checksum;

  /// The server-reported `Content-Type` (EAM's authoritative MIME type
  /// for this Vault Entry).
  final String contentType;

  /// The length of [bytes], in bytes.
  final int contentLength;
}
