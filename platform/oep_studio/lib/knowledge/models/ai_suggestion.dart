import 'ai_suggestion_status.dart';
import 'knowledge_candidate_type.dart';

/// One AI-generated Knowledge Candidate suggestion (Work Package 016
/// STUDIO-TASK-000046/000048). A Workspace artifact — "AI outputs are
/// Workspace artifacts. AI outputs are never Engineering Objects."
/// (SDD-022) — never a Knowledge Candidate itself until an engineer
/// explicitly accepts it (`docs/AI_PROVIDER_ARCHITECTURE.md` § Review
/// Workflow), exactly mirroring `EngineeringEntity`'s own
/// suggestion-until-accepted precedent (Work Package 014).
class AiSuggestion {
  const AiSuggestion({
    required this.id,
    required this.sourceId,
    required this.providerId,
    required this.modelId,
    required this.suggestedType,
    required this.suggestedName,
    required this.suggestedDescription,
    required this.supportingEntityIds,
    required this.supportingContextIds,
    required this.confidence,
    required this.reasoning,
    required this.sourceFingerprint,
    required this.createdTime,
    this.status = AiSuggestionStatus.pending,
    this.editedType,
    this.editedName,
    this.editedDescription,
    this.createdCandidateId,
  });

  final String id;

  /// The `SourceMaterial.id` this suggestion's evidence was drawn from.
  final String sourceId;

  /// Which `AiProvider`/model produced this suggestion — persisted per
  /// SDD-022's own "AI Session Persistence: Persist... Provider,
  /// Model."
  final String providerId;
  final String modelId;

  final KnowledgeCandidateType suggestedType;
  final String suggestedName;
  final String suggestedDescription;

  /// `EngineeringEntity.id`s this suggestion cites as supporting
  /// evidence — "Engineers shall always be able to trace a suggestion
  /// back to the originating engineering evidence" (SDD-022).
  final List<String> supportingEntityIds;

  /// `EngineeringContext.id`s this suggestion cites as supporting
  /// evidence.
  final List<String> supportingContextIds;

  /// `0.0`–`1.0` — the AI's own self-reported confidence. Informational
  /// only; "Confidence shall never: Automatically approve, Automatically
  /// reject, Automatically commit" (SDD-022).
  final double confidence;

  /// The AI's own explanation for this suggestion, shown verbatim to
  /// the engineer — "All AI reasoning shall be inspectable" (SDD-022).
  final String reasoning;

  /// A combined fingerprint of the OCR/entity/context evidence this
  /// suggestion was analyzed from — lets re-analysis detect whether the
  /// underlying deterministic evidence actually changed ("Re-analysis
  /// shall occur only when deterministic engineering evidence changes,"
  /// SDD-022), the same whole-source cache-reuse contract Work Package
  /// 015 established for Engineering Contexts, applied one layer up.
  final String sourceFingerprint;

  final DateTime createdTime;

  final AiSuggestionStatus status;

  /// The engineer's corrected type/name/description, set only once
  /// [status] becomes [AiSuggestionStatus.edited] — the AI's own
  /// [suggestedType]/[suggestedName]/[suggestedDescription] are never
  /// overwritten, so the original suggestion remains fully inspectable
  /// alongside the correction ("No hidden state").
  final KnowledgeCandidateType? editedType;
  final String? editedName;
  final String? editedDescription;

  /// The `KnowledgeCandidate.id` created when this suggestion was
  /// accepted, `null` until then. Once set, never cleared — the same
  /// one-way-set precedent `EngineeringEntity.createdCandidateId`/
  /// `KnowledgeCandidate.committedObjectId` already established.
  final String? createdCandidateId;

  bool get isPending => status == AiSuggestionStatus.pending;
  bool get isAccepted => status == AiSuggestionStatus.accepted;
  bool get isEdited => status == AiSuggestionStatus.edited;
  bool get isRejected => status == AiSuggestionStatus.rejected;
  bool get isDeferred => status == AiSuggestionStatus.deferred;

  /// The type/name/description a Knowledge Candidate created from this
  /// suggestion should use — the engineer's edited values if present,
  /// otherwise the AI's own original ones.
  KnowledgeCandidateType get effectiveType => editedType ?? suggestedType;
  String get effectiveName => editedName ?? suggestedName;
  String get effectiveDescription => editedDescription ?? suggestedDescription;

  AiSuggestion copyWith({
    AiSuggestionStatus? status,
    KnowledgeCandidateType? editedType,
    String? editedName,
    String? editedDescription,
    String? createdCandidateId,
  }) {
    return AiSuggestion(
      id: id,
      sourceId: sourceId,
      providerId: providerId,
      modelId: modelId,
      suggestedType: suggestedType,
      suggestedName: suggestedName,
      suggestedDescription: suggestedDescription,
      supportingEntityIds: supportingEntityIds,
      supportingContextIds: supportingContextIds,
      confidence: confidence,
      reasoning: reasoning,
      sourceFingerprint: sourceFingerprint,
      createdTime: createdTime,
      status: status ?? this.status,
      editedType: editedType ?? this.editedType,
      editedName: editedName ?? this.editedName,
      editedDescription: editedDescription ?? this.editedDescription,
      createdCandidateId: createdCandidateId ?? this.createdCandidateId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'providerId': providerId,
    'modelId': modelId,
    'suggestedType': suggestedType.name,
    'suggestedName': suggestedName,
    'suggestedDescription': suggestedDescription,
    'supportingEntityIds': supportingEntityIds,
    'supportingContextIds': supportingContextIds,
    'confidence': confidence,
    'reasoning': reasoning,
    'sourceFingerprint': sourceFingerprint,
    'createdTime': createdTime.toIso8601String(),
    'status': status.name,
    'editedType': editedType?.name,
    'editedName': editedName,
    'editedDescription': editedDescription,
    'createdCandidateId': createdCandidateId,
  };

  factory AiSuggestion.fromJson(Map<String, dynamic> json) {
    return AiSuggestion(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      providerId: json['providerId'] as String,
      modelId: json['modelId'] as String,
      suggestedType: KnowledgeCandidateType.values.byName(json['suggestedType'] as String),
      suggestedName: json['suggestedName'] as String,
      suggestedDescription: json['suggestedDescription'] as String,
      supportingEntityIds: (json['supportingEntityIds'] as List).cast<String>(),
      supportingContextIds: (json['supportingContextIds'] as List).cast<String>(),
      confidence: (json['confidence'] as num).toDouble(),
      reasoning: json['reasoning'] as String,
      sourceFingerprint: json['sourceFingerprint'] as String,
      createdTime: DateTime.parse(json['createdTime'] as String),
      status: AiSuggestionStatus.values.byName(json['status'] as String),
      editedType: (json['editedType'] as String?) == null
          ? null
          : KnowledgeCandidateType.values.byName(json['editedType'] as String),
      editedName: json['editedName'] as String?,
      editedDescription: json['editedDescription'] as String?,
      createdCandidateId: json['createdCandidateId'] as String?,
    );
  }
}
