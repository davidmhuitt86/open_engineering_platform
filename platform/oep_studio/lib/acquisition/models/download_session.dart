/// Mirrors `oep_acquisition`'s `downloads::Download` JSON shape
/// (`GET /downloads`, `GET /downloads/{id}`, `POST /downloads`).
class DownloadSession {
  const DownloadSession({
    required this.id,
    required this.jobId,
    required this.connectorId,
    required this.sourceUri,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.status,
    required this.progressPercentage,
    this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String connectorId;
  final String sourceUri;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String status;
  final int progressPercentage;
  final String? errorMessage;
  final String createdAt;

  factory DownloadSession.fromJson(Map<String, Object?> json) => DownloadSession(
        id: json['id'] as String? ?? '',
        jobId: json['job_id'] as String? ?? '',
        connectorId: json['connector_id'] as String? ?? '',
        sourceUri: json['source_uri'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? '',
        fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
        status: json['status'] as String? ?? '',
        progressPercentage: json['progress_percentage'] as int? ?? 0,
        errorMessage: json['error_message'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}
