/// AP-DS-004: a uniform, generic tabular-report shape shared by every
/// Engineering Deliverable this phase names that is fundamentally "rows of
/// data about engineering objects" — Bill of Materials, Wire List,
/// Connector List/Report, Harness Report, Relationship Report, Engineering
/// Object Report. One shape, one CSV renderer, one Markdown renderer, one
/// PDF table renderer serve all six report types (see
/// `lib/core/exporters/`), rather than six bespoke ones — deliberately, to
/// avoid the kind of duplicated-rendering-logic debt this platform's own
/// architecture reviews have repeatedly flagged elsewhere. Each report
/// TYPE is a thin generator function producing a [TabularReport]; nothing
/// downstream needs to know which generator produced it.
class TabularReport {
  final String title;
  final DateTime generatedAt;

  /// Column ids, in display order. Row maps use these as keys.
  final List<String> columns;

  /// Human-readable header label per column id (falls back to the column
  /// id itself if absent).
  final Map<String, String> columnLabels;

  final List<Map<String, Object?>> rows;

  /// Free-text notes shown under the table (e.g. a Connector Report's
  /// disclosed per-pin-connectivity limitation — see
  /// `connector_report.dart`).
  final List<String> notes;

  const TabularReport({
    required this.title,
    required this.generatedAt,
    required this.columns,
    this.columnLabels = const {},
    required this.rows,
    this.notes = const [],
  });

  String labelFor(String column) => columnLabels[column] ?? column;

  /// Grouping (per the BOM spec's own "Grouping" requirement): buckets
  /// rows by the string value of [column], preserving first-seen group
  /// order. Returns the whole report unchanged (one implicit group) if
  /// [column] is null.
  List<MapEntry<String, List<Map<String, Object?>>>> groupedBy(String? column) {
    if (column == null) return [MapEntry('', rows)];
    final groups = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final key = (row[column] ?? '').toString();
      groups.putIfAbsent(key, () => []).add(row);
    }
    return groups.entries.toList();
  }

  /// Sorting (per the BOM spec's own "Sorting" requirement) — returns a
  /// new [TabularReport], stable-sorted by the string value of [column].
  TabularReport sortedBy(String column, {bool descending = false}) {
    final sorted = [...rows]..sort((a, b) {
        final cmp = (a[column] ?? '').toString().compareTo((b[column] ?? '').toString());
        return descending ? -cmp : cmp;
      });
    return TabularReport(
      title: title,
      generatedAt: generatedAt,
      columns: columns,
      columnLabels: columnLabels,
      rows: sorted,
      notes: notes,
    );
  }

  /// Filtering (per the BOM spec's own "Filtering" requirement) — keeps
  /// only rows where [predicate] returns true.
  TabularReport filtered(bool Function(Map<String, Object?> row) predicate) {
    return TabularReport(
      title: title,
      generatedAt: generatedAt,
      columns: columns,
      columnLabels: columnLabels,
      rows: rows.where(predicate).toList(),
      notes: notes,
    );
  }

  /// Custom Columns (per the BOM spec's own requirement) — appends
  /// additional columns computed per-row by [compute], without touching
  /// existing columns/rows otherwise.
  TabularReport withCustomColumn(String columnId, String label, Object? Function(Map<String, Object?> row) compute) {
    return TabularReport(
      title: title,
      generatedAt: generatedAt,
      columns: [...columns, columnId],
      columnLabels: {...columnLabels, columnId: label},
      rows: [
        for (final row in rows) {...row, columnId: compute(row)},
      ],
      notes: notes,
    );
  }
}
