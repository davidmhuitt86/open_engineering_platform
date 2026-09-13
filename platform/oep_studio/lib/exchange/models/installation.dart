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

  /// WP-EXC-013 -- lets [ExchangeRuntimeNotifier.installPackage] correct
  /// this record's `status`/`errorMessage`/`repositoryPackageId` once the
  /// real Foundation-side install result is known, without fabricating a
  /// new model. `id`/`packageId`/`version`/`requestedAt` never change --
  /// those are Exchange's own, already-real Installation identity.
  Installation copyWith({
    String? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? repositoryPackageId,
    String? completedAt,
  }) =>
      Installation(
        id: id,
        packageId: packageId,
        version: version,
        status: status ?? this.status,
        repositoryPackageId: repositoryPackageId ?? this.repositoryPackageId,
        errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
        requestedAt: requestedAt,
        completedAt: completedAt ?? this.completedAt,
      );

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
