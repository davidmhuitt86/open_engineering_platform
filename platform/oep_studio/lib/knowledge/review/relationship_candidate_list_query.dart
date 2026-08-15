import '../../core/models/relationship_type.dart';
import '../models/relationship_candidate.dart';

/// A [RelationshipCandidate] paired with its resolved source/target
/// Knowledge Candidate names — `RelationshipCandidate` itself only
/// stores `sourceCandidateId`/`targetCandidateId` (see that class's
/// doc comment), so display/sort/filter code needs names resolved
/// once against the session's current candidate list, the same
/// pattern `RelationshipSummary.sourceObjectName` established for
/// Foundation relationships (Work Package 006).
class ResolvedRelationshipCandidate {
  const ResolvedRelationshipCandidate({required this.relationship, required this.sourceName, required this.targetName});

  final RelationshipCandidate relationship;
  final String sourceName;
  final String targetName;
}

/// Sort fields the Relationship Candidate view supports (Work Package
/// 008 STUDIO-TASK-000017 Relationship View: "Support filtering and
/// sorting").
enum RelationshipCandidateSortField { type, source, target }

/// Pure sort/filter logic for the Relationship Candidate view, mirroring
/// `RelationshipListQuery`'s design (Work Package 006) — kept separate
/// from widget code so it can be unit-tested with synthetic data.
class RelationshipCandidateListQuery {
  const RelationshipCandidateListQuery({
    this.sortField = RelationshipCandidateSortField.type,
    this.typeFilter,
    this.sourceFilter,
    this.targetFilter,
  });

  final RelationshipCandidateSortField sortField;
  final RelationshipType? typeFilter;
  final String? sourceFilter;
  final String? targetFilter;

  RelationshipCandidateListQuery copyWith({
    RelationshipCandidateSortField? sortField,
    RelationshipType? typeFilter,
    bool clearTypeFilter = false,
    String? sourceFilter,
    bool clearSourceFilter = false,
    String? targetFilter,
    bool clearTargetFilter = false,
  }) {
    return RelationshipCandidateListQuery(
      sortField: sortField ?? this.sortField,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      sourceFilter: clearSourceFilter ? null : (sourceFilter ?? this.sourceFilter),
      targetFilter: clearTargetFilter ? null : (targetFilter ?? this.targetFilter),
    );
  }

  /// Applies this query's filters, then sort, to [relationships]. Never
  /// mutates the input; always returns a new list.
  List<ResolvedRelationshipCandidate> apply(List<ResolvedRelationshipCandidate> relationships) {
    var results = relationships.where((entry) {
      if (typeFilter != null && entry.relationship.type != typeFilter) return false;
      if (sourceFilter != null &&
          sourceFilter!.isNotEmpty &&
          !entry.sourceName.toLowerCase().contains(sourceFilter!.toLowerCase())) {
        return false;
      }
      if (targetFilter != null &&
          targetFilter!.isNotEmpty &&
          !entry.targetName.toLowerCase().contains(targetFilter!.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    results.sort(_comparatorFor(sortField));
    return results;
  }

  int Function(ResolvedRelationshipCandidate, ResolvedRelationshipCandidate) _comparatorFor(
    RelationshipCandidateSortField field,
  ) {
    switch (field) {
      case RelationshipCandidateSortField.type:
        return (a, b) => a.relationship.type.label.compareTo(b.relationship.type.label);
      case RelationshipCandidateSortField.source:
        return (a, b) => a.sourceName.toLowerCase().compareTo(b.sourceName.toLowerCase());
      case RelationshipCandidateSortField.target:
        return (a, b) => a.targetName.toLowerCase().compareTo(b.targetName.toLowerCase());
    }
  }
}
