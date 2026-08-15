import 'engineering_entity_status.dart';
import 'engineering_entity_type.dart';
import 'ocr_bounding_box.dart';

/// One deterministically-recognized engineering entity (Work Package
/// 014 STUDIO-TASK-000038 "Entity Output": "UUID, Entity Type,
/// Extracted Text, Normalized Value, Source Material, Page, Bounding
/// Box, Confidence, Character Range"). A Workspace artifact, exactly
/// like `OcrPageResult`/`EvidenceRegion` before it — SDD-015 Layer 2
/// ("Extracted Artifacts... machine-readable... not Engineering
/// Objects"). "Entities are suggestions only" — never an Engineering
/// Object, never a Knowledge Candidate, until [status] becomes
/// [EngineeringEntityStatus.accepted] through explicit engineer
/// review (`docs/ENGINEERING_ENTITY_EXTRACTION.md` § Review Workflow).
class EngineeringEntity {
  const EngineeringEntity({
    required this.id,
    required this.type,
    required this.matchedPatternId,
    required this.extractedText,
    required this.normalizedValue,
    required this.sourceId,
    required this.page,
    required this.boundingBox,
    required this.confidence,
    required this.characterStart,
    required this.characterEnd,
    required this.sourceFingerprint,
    required this.extractedTime,
    this.status = EngineeringEntityStatus.pending,
    this.createdCandidateId,
  });

  final String id;
  final EngineeringEntityType type;

  /// Which `EngineeringPattern.id` (`EngineeringPatternLibrary`)
  /// produced this entity — the Property Inspector's "Pattern Match"
  /// (STUDIO-TASK-000041) resolves this back to the pattern's label/
  /// regex for display; never re-derived by guesswork.
  final String matchedPatternId;

  /// The raw OCR text the pattern matched, verbatim.
  final String extractedText;

  /// The canonical/normalized form (`EngineeringPattern.normalize`) —
  /// e.g. `"24 Nm"` for an extracted `"24nm"`.
  final String normalizedValue;

  /// The [SourceMaterial.id] this entity was extracted from.
  final String sourceId;

  /// 1-based page number, matching `OcrPageResult.page`.
  final int page;

  /// The union of every overlapping `OcrWord.boundingBox` the match
  /// spans — a fraction of the page image, top-left origin, the same
  /// convention `OcrBoundingBox`/`EvidenceRegion` already use.
  final OcrBoundingBox boundingBox;

  /// `0.0`–`1.0` — the mean confidence of every `OcrWord` the match
  /// overlaps (`docs/ENGINEERING_ENTITY_EXTRACTION.md` § Pattern
  /// Engine). Deterministic: the same OCR input always yields the same
  /// confidence for the same match.
  final double confidence;

  /// The matched substring's `[start, end)` character offsets within
  /// the OCR line text it was found in (0-based) — recorded for
  /// reproducibility/debugging, not for display.
  final int characterStart;
  final int characterEnd;

  /// The `OcrPageResult.sourceFingerprint` this entity was extracted
  /// from — lets re-extraction detect which pages' entities are still
  /// valid (the OCR hasn't changed) versus stale (see
  /// `EngineeringEntityExtractionService`).
  final String sourceFingerprint;

  final DateTime extractedTime;

  final EngineeringEntityStatus status;

  /// The `KnowledgeCandidate.id` created when this entity was accepted,
  /// `null` until then. Once set, never cleared — acceptance is
  /// one-way, the same way `KnowledgeCandidate.committedObjectId` is
  /// (Work Package 012).
  final String? createdCandidateId;

  bool get isPending => status == EngineeringEntityStatus.pending;
  bool get isAccepted => status == EngineeringEntityStatus.accepted;
  bool get isIgnored => status == EngineeringEntityStatus.ignored;

  EngineeringEntity copyWith({EngineeringEntityStatus? status, String? createdCandidateId}) {
    return EngineeringEntity(
      id: id,
      type: type,
      matchedPatternId: matchedPatternId,
      extractedText: extractedText,
      normalizedValue: normalizedValue,
      sourceId: sourceId,
      page: page,
      boundingBox: boundingBox,
      confidence: confidence,
      characterStart: characterStart,
      characterEnd: characterEnd,
      sourceFingerprint: sourceFingerprint,
      extractedTime: extractedTime,
      status: status ?? this.status,
      createdCandidateId: createdCandidateId ?? this.createdCandidateId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'matchedPatternId': matchedPatternId,
    'extractedText': extractedText,
    'normalizedValue': normalizedValue,
    'sourceId': sourceId,
    'page': page,
    'boundingBox': boundingBox.toJson(),
    'confidence': confidence,
    'characterStart': characterStart,
    'characterEnd': characterEnd,
    'sourceFingerprint': sourceFingerprint,
    'extractedTime': extractedTime.toIso8601String(),
    'status': status.name,
    'createdCandidateId': createdCandidateId,
  };

  factory EngineeringEntity.fromJson(Map<String, dynamic> json) {
    return EngineeringEntity(
      id: json['id'] as String,
      type: EngineeringEntityType.values.byName(json['type'] as String),
      matchedPatternId: json['matchedPatternId'] as String,
      extractedText: json['extractedText'] as String,
      normalizedValue: json['normalizedValue'] as String,
      sourceId: json['sourceId'] as String,
      page: json['page'] as int,
      boundingBox: OcrBoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>),
      confidence: (json['confidence'] as num).toDouble(),
      characterStart: json['characterStart'] as int,
      characterEnd: json['characterEnd'] as int,
      sourceFingerprint: json['sourceFingerprint'] as String,
      extractedTime: DateTime.parse(json['extractedTime'] as String),
      status: EngineeringEntityStatus.values.byName(json['status'] as String),
      createdCandidateId: json['createdCandidateId'] as String?,
    );
  }
}
