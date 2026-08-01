/// Mirrors `oep_exchange`'s `SearchResultItemDto` wire shape
/// (`GET /search`, `packages/api-contracts/src/search.ts`).
class SearchResultItem {
  const SearchResultItem({
    required this.id,
    required this.packageId,
    required this.publisherId,
    required this.publisherName,
    required this.displayName,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.currentVersion,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packageId;
  final String publisherId;
  final String publisherName;
  final String displayName;
  final String description;
  final String? categoryId;
  final String? categoryName;
  final String? currentVersion;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory SearchResultItem.fromJson(Map<String, Object?> json) => SearchResultItem(
        id: json['id'] as String? ?? '',
        packageId: json['packageId'] as String? ?? '',
        publisherId: json['publisherId'] as String? ?? '',
        publisherName: json['publisherName'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String?,
        currentVersion: json['currentVersion'] as String?,
        status: json['status'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}

/// Mirrors `SearchResponse` — the pagination envelope every `GET /search`
/// call returns.
class ExchangeSearchResponse {
  const ExchangeSearchResponse({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  final List<SearchResultItem> items;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  static const empty = ExchangeSearchResponse(
    items: [],
    totalCount: 0,
    totalPages: 0,
    currentPage: 1,
    pageSize: 20,
  );

  factory ExchangeSearchResponse.fromJson(Map<String, Object?> json) => ExchangeSearchResponse(
        items: (json['items'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>()
            .map(SearchResultItem.fromJson)
            .toList(),
        totalCount: json['totalCount'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 0,
        currentPage: json['currentPage'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 20,
      );
}
