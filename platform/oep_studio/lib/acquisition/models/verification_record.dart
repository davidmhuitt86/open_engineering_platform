/// Mirrors `oep_acquisition`'s `integrity::Verification` JSON shape
/// (`GET /verifications`, `GET /verifications/{id}`,
/// `POST /verifications`).
class VerificationRecord {
  const VerificationRecord({
    required this.id,
    required this.downloadSessionId,
    required this.status,
    required this.sha256Hash,
    required this.fileSizeBytes,
    this.verifiedAt,
    this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String downloadSessionId;
  final String status;
  final String sha256Hash;
  final int fileSizeBytes;
  final String? verifiedAt;
  final String? errorMessage;
  final String createdAt;

  factory VerificationRecord.fromJson(Map<String, Object?> json) => VerificationRecord(
        id: json['id'] as String? ?? '',
        downloadSessionId: json['download_session_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        sha256Hash: json['sha256_hash'] as String? ?? '',
        fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
        verifiedAt: json['verified_at'] as String?,
        errorMessage: json['error_message'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}
