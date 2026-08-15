import '../../core/models/relationship_summary.dart';
import '../../core/models/relationship_type.dart';

/// Sort fields the Relationship Explorer supports (STUDIO-TASK-000009).
enum RelationshipSortField { type, source, target, author }

/// Pure sort/filter logic for the Relationship Explorer, mirroring
/// `ObjectListQuery`'s design (kept separate from widget code so it can
/// be unit-tested with synthetic data — the real relationship list is
/// always empty in this work package; see
/// `docs/CONNECTION_MANAGER.md` § Missing Public API).
class RelationshipListQuery {
  const RelationshipListQuery({
    this.sortField = RelationshipSortField.type,
    this.typeFilter,
    this.sourceFilter,
    this.targetFilter,
    this.authorFilter,
  });

  final RelationshipSortField sortField;
  final RelationshipType? typeFilter;
  final String? sourceFilter;
  final String? targetFilter;
  final String? authorFilter;

  RelationshipListQuery copyWith({
    RelationshipSortField? sortField,
    RelationshipType? typeFilter,
    bool clearTypeFilter = false,
    String? sourceFilter,
    bool clearSourceFilter = false,
    String? targetFilter,
    bool clearTargetFilter = false,
    String? authorFilter,
    bool clearAuthorFilter = false,
  }) {
    return RelationshipListQuery(
      sortField: sortField ?? this.sortField,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      sourceFilter: clearSourceFilter ? null : (sourceFilter ?? this.sourceFilter),
      targetFilter: clearTargetFilter ? null : (targetFilter ?? this.targetFilter),
      authorFilter: clearAuthorFilter ? null : (authorFilter ?? this.authorFilter),
    );
  }

  /// Applies this query's filters, then sort, to [relationships]. Never
  /// mutates the input; always returns a new list. Filtering never
  /// modifies repository contents.
  List<RelationshipSummary> apply(List<RelationshipSummary> relationships) {
    var results = relationships.where((relationship) {
      if (typeFilter != null && relationship.type != typeFilter) return false;
      if (sourceFilter != null &&
          sourceFilter!.isNotEmpty &&
          !relationship.sourceObjectName.toLowerCase().contains(sourceFilter!.toLowerCase())) {
        return false;
      }
      if (targetFilter != null &&
          targetFilter!.isNotEmpty &&
          !relationship.targetObjectName.toLowerCase().contains(targetFilter!.toLowerCase())) {
        return false;
      }
      if (authorFilter != null && authorFilter!.isNotEmpty && relationship.author != authorFilter) {
        return false;
      }
      return true;
    }).toList();

    results.sort(_comparatorFor(sortField));
    return results;
  }

  int Function(RelationshipSummary, RelationshipSummary) _comparatorFor(RelationshipSortField field) {
    switch (field) {
      case RelationshipSortField.type:
        return (a, b) => a.type.label.compareTo(b.type.label);
      case RelationshipSortField.source:
        return (a, b) => a.sourceObjectName.toLowerCase().compareTo(b.sourceObjectName.toLowerCase());
      case RelationshipSortField.target:
        return (a, b) => a.targetObjectName.toLowerCase().compareTo(b.targetObjectName.toLowerCase());
      case RelationshipSortField.author:
        return (a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase());
    }
  }
}
