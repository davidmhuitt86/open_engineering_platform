/// Mirrors `oep_acquisition`'s `metadata::ArtifactMetadata` JSON shape
/// (`GET /metadata`, `GET /metadata/{id}`, `POST /metadata`).
class ArtifactMetadataRecord {
  const ArtifactMetadataRecord({
    required this.id,
    required this.verificationId,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.sha256Hash,
    this.pdfVersion,
    this.pdfPageCount,
    required this.status,
    this.extractedAt,
    this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String verificationId;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String sha256Hash;
  final String? pdfVersion;
  final int? pdfPageCount;
  final String status;
  final String? extractedAt;
  final String? errorMessage;
  final String createdAt;

  factory ArtifactMetadataRecord.fromJson(Map<String, Object?> json) => ArtifactMetadataRecord(
        id: json['id'] as String? ?? '',
        verificationId: json['verification_id'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? '',
        fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
        sha256Hash: json['sha256_hash'] as String? ?? '',
        pdfVersion: json['pdf_version'] as String?,
        pdfPageCount: json['pdf_page_count'] as int?,
        status: json['status'] as String? ?? '',
        extractedAt: json['extracted_at'] as String?,
        errorMessage: json['error_message'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}
