/// Mirrors `oep_acquisition`'s `vault::VaultEntry` JSON shape
/// (`GET /vault`, `GET /vault/{id}`, `POST /vault`). Vault entries are
/// immutable once published (WORK_PACKAGE-009) — this model has no
/// mutating methods, matching that invariant on the Studio side too.
class VaultEntryRecord {
  const VaultEntryRecord({
    required this.id,
    required this.metadataId,
    required this.verificationId,
    required this.downloadSessionId,
    required this.sourceId,
    required this.vaultPath,
    required this.sha256Hash,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.status,
    required this.publishedAt,
    required this.createdAt,
  });

  final String id;
  final String metadataId;
  final String verificationId;
  final String downloadSessionId;
  final String sourceId;
  final String vaultPath;
  final String sha256Hash;
  final String mimeType;
  final int fileSizeBytes;
  final String status;
  final String publishedAt;
  final String createdAt;

  factory VaultEntryRecord.fromJson(Map<String, Object?> json) => VaultEntryRecord(
        id: json['id'] as String? ?? '',
        metadataId: json['metadata_id'] as String? ?? '',
        verificationId: json['verification_id'] as String? ?? '',
        downloadSessionId: json['download_session_id'] as String? ?? '',
        sourceId: json['source_id'] as String? ?? '',
        vaultPath: json['vault_path'] as String? ?? '',
        sha256Hash: json['sha256_hash'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? '',
        fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
        status: json['status'] as String? ?? '',
        publishedAt: json['published_at'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}
