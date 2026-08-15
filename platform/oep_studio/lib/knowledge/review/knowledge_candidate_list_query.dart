import '../models/candidate_validation_result.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_status.dart';
import '../models/knowledge_candidate_type.dart';

/// Sort fields the Candidate List supports (Work Package 010 Candidate
/// List: "Support: ... Sort").
enum KnowledgeCandidateSortField { name, type, status, validation }

/// Pure sort/filter logic for the Engineering Review panel's Candidate
/// List, mirroring `RelationshipCandidateListQuery`'s design (Work
/// Package 008) — kept separate from widget code so it can be
/// unit-tested with synthetic data.
class KnowledgeCandidateListQuery {
  const KnowledgeCandidateListQuery({
    this.sortField = KnowledgeCandidateSortField.name,
    this.typeFilter,
    this.statusFilter,
    this.textFilter,
  });

  final KnowledgeCandidateSortField sortField;
  final KnowledgeCandidateType? typeFilter;
  final KnowledgeCandidateStatus? statusFilter;
  final String? textFilter;

  KnowledgeCandidateListQuery copyWith({
    KnowledgeCandidateSortField? sortField,
    KnowledgeCandidateType? typeFilter,
    bool clearTypeFilter = false,
    KnowledgeCandidateStatus? statusFilter,
    bool clearStatusFilter = false,
    String? textFilter,
    bool clearTextFilter = false,
  }) {
    return KnowledgeCandidateListQuery(
      sortField: sortField ?? this.sortField,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      textFilter: clearTextFilter ? null : (textFilter ?? this.textFilter),
    );
  }

  /// Applies this query's filters, then sort, to [candidates].
  /// [validation] resolves each candidate's [CandidateValidationResult]
  /// for [KnowledgeCandidateSortField.validation] sorting — errors
  /// first, then warnings, then ok. Never mutates the input; always
  /// returns a new list.
  List<KnowledgeCandidate> apply(
    List<KnowledgeCandidate> candidates, {
    Map<String, CandidateValidationResult> validation = const {},
  }) {
    var results = candidates.where((candidate) {
      if (typeFilter != null && candidate.type != typeFilter) return false;
      if (statusFilter != null && candidate.status != statusFilter) return false;
      if (textFilter != null &&
          textFilter!.isNotEmpty &&
          !candidate.name.toLowerCase().contains(textFilter!.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    results.sort(_comparatorFor(sortField, validation));
    return results;
  }

  int Function(KnowledgeCandidate, KnowledgeCandidate) _comparatorFor(
    KnowledgeCandidateSortField field,
    Map<String, CandidateValidationResult> validation,
  ) {
    switch (field) {
      case KnowledgeCandidateSortField.name:
        return (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case KnowledgeCandidateSortField.type:
        return (a, b) => a.type.label.compareTo(b.type.label);
      case KnowledgeCandidateSortField.status:
        return (a, b) => a.status.label.compareTo(b.status.label);
      case KnowledgeCandidateSortField.validation:
        return (a, b) => _severityRank(validation[a.id]).compareTo(_severityRank(validation[b.id]));
    }
  }

  int _severityRank(CandidateValidationResult? result) {
    return switch (result?.severity) {
      ValidationSeverity.error => 0,
      ValidationSeverity.warning => 1,
      ValidationSeverity.ok || null => 2,
    };
  }
}
