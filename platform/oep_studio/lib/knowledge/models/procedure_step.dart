/// One step within a Procedure Knowledge Candidate (Work Package 010
/// STUDIO-TASK-000023).
///
/// Procedure Steps remain part of their owning Procedure Knowledge
/// Candidate — per the frozen Knowledge Architecture v1's explicit
/// restatement of that rule for this work package — but are modeled as
/// a separate, [candidateId]-keyed list rather than an embedded field on
/// [KnowledgeCandidate] itself, mirroring how [EvidenceLink] and
/// [RelationshipCandidate] already reference candidates by ID instead of
/// nesting. Ordering is the step's position within the full
/// `KnowledgeSessionRecord.procedureSteps` list filtered to one
/// [candidateId] — there is no explicit `order` field — "Display
/// automatic step numbering" (Work Package 010) only ever needs a
/// step's position among its siblings, and array position already
/// carries that unambiguously, the same way `KnowledgeSessionRecord`
/// itself carries no explicit ordering field for any of its lists.
class ProcedureStep {
  const ProcedureStep({
    required this.id,
    required this.candidateId,
    required this.title,
    this.description = '',
    this.notes = '',
    this.referencedCandidateIds = const [],
    this.referencedRegionIds = const [],
    required this.createdTime,
    this.modifiedTime,
  });

  final String id;

  /// The [KnowledgeCandidate.id] of the Procedure candidate this step
  /// belongs to.
  final String candidateId;

  final String title;
  final String description;
  final String notes;

  /// Other Knowledge Candidates this step references (Work Package 010:
  /// "Each step may reference: Knowledge Candidates").
  final List<String> referencedCandidateIds;

  /// Evidence Regions this step references (Work Package 010: "Each step
  /// may reference: ... Evidence Regions").
  final List<String> referencedRegionIds;

  final DateTime createdTime;
  final DateTime? modifiedTime;

  ProcedureStep copyWith({
    String? title,
    String? description,
    String? notes,
    List<String>? referencedCandidateIds,
    List<String>? referencedRegionIds,
    DateTime? modifiedTime,
  }) {
    return ProcedureStep(
      id: id,
      candidateId: candidateId,
      title: title ?? this.title,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      referencedCandidateIds: referencedCandidateIds ?? this.referencedCandidateIds,
      referencedRegionIds: referencedRegionIds ?? this.referencedRegionIds,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'candidateId': candidateId,
    'title': title,
    'description': description,
    'notes': notes,
    'referencedCandidateIds': referencedCandidateIds,
    'referencedRegionIds': referencedRegionIds,
    'createdTime': createdTime.toIso8601String(),
    'modifiedTime': modifiedTime?.toIso8601String(),
  };

  factory ProcedureStep.fromJson(Map<String, dynamic> json) {
    return ProcedureStep(
      id: json['id'] as String,
      candidateId: json['candidateId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      referencedCandidateIds:
          (json['referencedCandidateIds'] as List<dynamic>?)?.map((id) => id as String).toList() ?? const [],
      referencedRegionIds:
          (json['referencedRegionIds'] as List<dynamic>?)?.map((id) => id as String).toList() ?? const [],
      createdTime: DateTime.parse(json['createdTime'] as String),
      modifiedTime: json['modifiedTime'] == null ? null : DateTime.parse(json['modifiedTime'] as String),
    );
  }
}
