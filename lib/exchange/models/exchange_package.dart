/// Mirrors `oep_exchange`'s `PackageDto` wire shape (`GET /packages`,
/// `GET /packages/{id}`, `packages/api-contracts/src/package.ts`). Named
/// `ExchangePackage` rather than `Package` to avoid colliding with
/// `features/packages/packages_page.dart`'s own unrelated `Packages`
/// Studio destination (the existing Foundation Package concept).
class ExchangePackage {
  const ExchangePackage({
    required this.id,
    required this.packageId,
    required this.publisherId,
    required this.displayName,
    required this.description,
    required this.categoryId,
    required this.currentVersion,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packageId;
  final String publisherId;
  final String displayName;
  final String description;
  final String? categoryId;
  final String? currentVersion;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory ExchangePackage.fromJson(Map<String, Object?> json) => ExchangePackage(
        id: json['id'] as String? ?? '',
        packageId: json['packageId'] as String? ?? '',
        publisherId: json['publisherId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        categoryId: json['categoryId'] as String?,
        currentVersion: json['currentVersion'] as String?,
        status: json['status'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}
