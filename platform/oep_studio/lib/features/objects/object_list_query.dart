import '../../core/models/engineering_object_summary.dart';
import '../../core/models/object_category.dart';

/// Sort fields the Object Explorer supports (STUDIO-TASK-000006).
enum ObjectSortField { name, type, author }

/// Pure sort/filter logic for the Object Explorer, kept separate from
/// widget code so it can be unit-tested with synthetic data — the real
/// object list is always empty in this work package (see
/// `docs/CONNECTION_MANAGER.md` § Missing Public API), so this is the
/// only way to verify sorting/filtering actually works correctly ahead
/// of real data existing.
class ObjectListQuery {
  const ObjectListQuery({
    this.sortField = ObjectSortField.name,
    this.searchText = '',
    this.typeFilter,
    this.authorFilter,
    this.tagFilter,
  });

  final ObjectSortField sortField;

  /// Incremental filter text, matched case-insensitively against name.
  final String searchText;
  final ObjectCategory? typeFilter;
  final String? authorFilter;
  final String? tagFilter;

  ObjectListQuery copyWith({
    ObjectSortField? sortField,
    String? searchText,
    ObjectCategory? typeFilter,
    bool clearTypeFilter = false,
    String? authorFilter,
    bool clearAuthorFilter = false,
    String? tagFilter,
    bool clearTagFilter = false,
  }) {
    return ObjectListQuery(
      sortField: sortField ?? this.sortField,
      searchText: searchText ?? this.searchText,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      authorFilter: clearAuthorFilter ? null : (authorFilter ?? this.authorFilter),
      tagFilter: clearTagFilter ? null : (tagFilter ?? this.tagFilter),
    );
  }

  /// Applies this query's filters, then sort, to [objects]. Never
  /// mutates [objects]; always returns a new list. Filtering never
  /// modifies repository contents — it only changes what's visible, per
  /// SDD-008/SDD-009.
  List<EngineeringObjectSummary> apply(List<EngineeringObjectSummary> objects) {
    var results = objects.where((object) {
      if (typeFilter != null && object.category != typeFilter) return false;
      if (authorFilter != null && authorFilter!.isNotEmpty && object.author != authorFilter) {
        return false;
      }
      if (tagFilter != null && tagFilter!.isNotEmpty && !object.tags.contains(tagFilter)) {
        return false;
      }
      if (searchText.isNotEmpty && !object.name.toLowerCase().contains(searchText.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    results.sort(_comparatorFor(sortField));
    return results;
  }

  int Function(EngineeringObjectSummary, EngineeringObjectSummary) _comparatorFor(ObjectSortField field) {
    switch (field) {
      case ObjectSortField.name:
        return (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case ObjectSortField.type:
        return (a, b) => a.category.label.compareTo(b.category.label);
      case ObjectSortField.author:
        return (a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase());
    }
  }
}
