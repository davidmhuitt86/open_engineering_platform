/// The kind of engineering/layout object a [SearchResult] points at
/// (WORK_PACKAGE_023, ENGINE-TASK-000104).
enum SearchResultKind { node, relationship, symbol, annotation, layer }

/// One match from `SearchProvider.search` — the Engineering Graph and
/// Diagram Layout are indexed independently (per spec), so a single
/// result set can mix graph-derived and layout-derived matches; [kind]
/// disambiguates which.
class SearchResult {
  final String id;
  final SearchResultKind kind;
  final String label;

  /// Which field matched the query (e.g. `'displayName'`, `'category'`,
  /// `'alias'`) — useful for a host to show *why* a result matched.
  final String matchedField;

  const SearchResult({
    required this.id,
    required this.kind,
    required this.label,
    required this.matchedField,
  });
}
