/// Mirrors `oep_exchange`'s `InstallationDto` wire shape
/// (`POST /packages/{id}/install`, `GET /installations/{id}`,
/// `packages/api-contracts/src/installation.ts`) — WP-EXC-010 §6's
/// "Show Installation Status" reads [status]/[errorMessage] directly off
/// this model, the same way `MyLibraryPage` (`apps/publisher-portal`)
/// does for the web Exchange.
class Installation {
  const Installation({
    required this.id,
    required this.packageId,
    required this.version,
    required this.status,
    required this.repositoryPackageId,
    required this.errorMessage,
    required this.requestedAt,
    required this.completedAt,
  });

  final String id;
  final String packageId;
  final String version;

  /// One of `pending` / `completed` / `failed` — kept as a raw `String`
  /// rather than a Dart `enum`, matching `OfficialSource.status`'s own
  /// choice not to over-model a server-owned status string.
  final String status;
  final String? repositoryPackageId;
  final String? errorMessage;
  final String requestedAt;
  final String? completedAt;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';

  factory Installation.fromJson(Map<String, Object?> json) => Installation(
        id: json['id'] as String? ?? '',
        packageId: json['packageId'] as String? ?? '',
        version: json['version'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        repositoryPackageId: json['repositoryPackageId'] as String?,
        errorMessage: json['errorMessage'] as String?,
        requestedAt: json['requestedAt'] as String? ?? '',
        completedAt: json['completedAt'] as String?,
      );
}
