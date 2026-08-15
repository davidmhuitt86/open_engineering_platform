/// One locally-tracked installation record for the "My Library" section
/// (WP-EXC-010 §5) — mirrors `apps/publisher-portal`'s `LibraryContext`
/// (`docs/guides/FRONTEND_GUIDE.md`: "scoped to the browser instead"),
/// adapted to Studio's own local-file persistence
/// ([ExchangeLibraryStorage]) since there is no browser `localStorage`
/// on desktop. Every field stored is either a real id
/// (`packageId`/`installationId`) or a value a real API response already
/// returned -- never fabricated data, the same rule the web Exchange
/// follows.
class LibraryEntry {
  const LibraryEntry({
    required this.packageId,
    required this.displayName,
    required this.version,
    required this.installationId,
    required this.status,
    required this.requestedAt,
  });

  final String packageId;
  final String displayName;
  final String version;
  final String installationId;
  final String status;
  final String requestedAt;

  LibraryEntry copyWith({String? status}) => LibraryEntry(
        packageId: packageId,
        displayName: displayName,
        version: version,
        installationId: installationId,
        status: status ?? this.status,
        requestedAt: requestedAt,
      );

  Map<String, Object?> toJson() => {
        'packageId': packageId,
        'displayName': displayName,
        'version': version,
        'installationId': installationId,
        'status': status,
        'requestedAt': requestedAt,
      };

  factory LibraryEntry.fromJson(Map<String, Object?> json) => LibraryEntry(
        packageId: json['packageId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        version: json['version'] as String? ?? '',
        installationId: json['installationId'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        requestedAt: json['requestedAt'] as String? ?? '',
      );
}

/// One locally-tracked download event for the "Downloads" section
/// (WP-EXC-010 §5) -- recorded when the engineer triggers a download
/// URL, mirroring `LibraryContext`'s own download-history entries.
class DownloadEntry {
  const DownloadEntry({
    required this.packageId,
    required this.displayName,
    required this.version,
    required this.downloadedAt,
  });

  final String packageId;
  final String displayName;
  final String? version;
  final String downloadedAt;

  Map<String, Object?> toJson() => {
        'packageId': packageId,
        'displayName': displayName,
        'version': version,
        'downloadedAt': downloadedAt,
      };

  factory DownloadEntry.fromJson(Map<String, Object?> json) => DownloadEntry(
        packageId: json['packageId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        version: json['version'] as String?,
        downloadedAt: json['downloadedAt'] as String? ?? '',
      );
}
