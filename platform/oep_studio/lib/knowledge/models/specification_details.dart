import 'specification_type.dart';

/// The Specification-specific fields of a Specification Knowledge
/// Candidate (Work Package 010 STUDIO-TASK-000024: "Each Specification
/// supports: Type, Value, Unit, Notes, Linked Evidence").
///
/// Kept as a separate, [candidateId]-keyed (1:1) list rather than
/// nullable fields directly on [KnowledgeCandidate], mirroring
/// [ProcedureStep]'s separation from its owning candidate — a
/// Component or Tool candidate has no use for `specType`/`value`/`unit`,
/// and adding them as always-present nullable fields on every candidate
/// would blur "candidate" and "specification-candidate" the same way
/// embedding steps on the candidate would blur "candidate" and
/// "procedure". "Linked Evidence" is not a field here — it is the same
/// [EvidenceLink] list already keyed by `candidateId` that every other
/// Knowledge Candidate type uses (Work Package 009), so a Specification
/// needs no separate evidence-linking mechanism.
class SpecificationDetails {
  const SpecificationDetails({
    required this.candidateId,
    required this.specType,
    this.value = '',
    this.unit = '',
    this.notes = '',
    required this.createdTime,
    this.modifiedTime,
  });

  /// The [KnowledgeCandidate.id] this specification belongs to — exactly
  /// one [SpecificationDetails] per Specification-type candidate.
  final String candidateId;

  final SpecificationType specType;
  final String value;
  final String unit;
  final String notes;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  SpecificationDetails copyWith({
    SpecificationType? specType,
    String? value,
    String? unit,
    String? notes,
    DateTime? modifiedTime,
  }) {
    return SpecificationDetails(
      candidateId: candidateId,
      specType: specType ?? this.specType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'candidateId': candidateId,
    'specType': specType.name,
    'value': value,
    'unit': unit,
    'notes': notes,
    'createdTime': createdTime.toIso8601String(),
    'modifiedTime': modifiedTime?.toIso8601String(),
  };

  factory SpecificationDetails.fromJson(Map<String, dynamic> json) {
    return SpecificationDetails(
      candidateId: json['candidateId'] as String,
      specType: SpecificationType.values.byName(json['specType'] as String),
      value: json['value'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdTime: DateTime.parse(json['createdTime'] as String),
      modifiedTime: json['modifiedTime'] == null ? null : DateTime.parse(json['modifiedTime'] as String),
    );
  }
}
