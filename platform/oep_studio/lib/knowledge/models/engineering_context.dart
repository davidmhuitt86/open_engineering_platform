import 'engineering_context_status.dart';
import 'engineering_context_type.dart';
import 'ocr_bounding_box.dart';

/// One deterministically-detected engineering context (Work Package
/// 015 STUDIO-TASK-000042 "Context Output": "UUID, Context Type,
/// Title, Source Material, Page Range, Bounding Region, Child
/// Entities, Confidence"). A Workspace artifact, one layer above
/// `EngineeringEntity` — "Contexts organize OCR evidence and extracted
/// entities... Contexts are not Knowledge Candidates... Contexts are
/// not Foundation Engineering Objects" (this work package's own
/// Architecture Rules). Never converted into anything else; accepting
/// one is purely a review-status marker
/// (`docs/ENGINEERING_CONTEXT.md` § Context Explorer).
class EngineeringContext {
  const EngineeringContext({
    required this.id,
    required this.type,
    required this.title,
    required this.sourceId,
    required this.pageStart,
    required this.pageEnd,
    required this.boundingRegion,
    required this.childEntityIds,
    required this.confidence,
    required this.sourceFingerprint,
    required this.detectedTime,
    this.parentContextId,
    this.status = EngineeringContextStatus.pending,
  });

  final String id;
  final EngineeringContextType type;

  /// The detected heading/callout line's own OCR text, trimmed,
  /// verbatim — not re-cased or otherwise cleaned up.
  final String title;

  /// The [SourceMaterial.id] this context was detected within.
  final String sourceId;

  /// 1-based, inclusive — the page range this context's content
  /// actually spans, computed from the lines included in it (not
  /// merely "until the next heading's page," which can overstate the
  /// range when a later heading is several blank pages away).
  final int pageStart;
  final int pageEnd;

  /// The union of the heading line's own bounding box and every child
  /// entity's bounding box — a fraction of the page image, top-left
  /// origin, the same convention `OcrBoundingBox`/`EngineeringEntity`
  /// already use. Since a context can span multiple pages, this is
  /// only meaningful relative to [pageStart] (the page the heading
  /// itself was detected on) — see `docs/ENGINEERING_CONTEXT.md` §
  /// Context Model.
  final OcrBoundingBox boundingRegion;

  /// The `EngineeringEntity.id`s whose OCR position falls within this
  /// context's own line range ("entity proximity").
  final List<String> childEntityIds;

  /// `0.0`–`1.0` — see `docs/ENGINEERING_CONTEXT.md` § Detection Rules
  /// for the formula (grounded in the heading line's own OCR word
  /// confidence, not an invented score).
  final double confidence;

  /// The enclosing context's id, if this context's detected position
  /// falls within a "section-like" context's range (e.g. a Warning
  /// callout detected inside a Procedure section) — `null` for a
  /// top-level context. See `docs/ENGINEERING_CONTEXT.md` § Detection
  /// Rules for the major/minor tiering this is derived from.
  final String? parentContextId;

  /// A combined fingerprint of every OCR page this source's context
  /// detection considered — SHA-256 of the concatenation of each
  /// page's own `OcrPageResult.sourceFingerprint`, in page order.
  /// Whole-source, not per-page, since a context can span multiple
  /// pages and detection re-derives the *entire* document's context
  /// list together (`docs/ENGINEERING_CONTEXT.md` § Detection Rules —
  /// Cache Reuse).
  final String sourceFingerprint;

  final DateTime detectedTime;

  final EngineeringContextStatus status;

  bool get isPending => status == EngineeringContextStatus.pending;
  bool get isAccepted => status == EngineeringContextStatus.accepted;
  bool get isIgnored => status == EngineeringContextStatus.ignored;

  EngineeringContext copyWith({
    EngineeringContextStatus? status,
    String? parentContextId,
    bool clearParentContextId = false,
  }) {
    return EngineeringContext(
      id: id,
      type: type,
      title: title,
      sourceId: sourceId,
      pageStart: pageStart,
      pageEnd: pageEnd,
      boundingRegion: boundingRegion,
      childEntityIds: childEntityIds,
      confidence: confidence,
      sourceFingerprint: sourceFingerprint,
      detectedTime: detectedTime,
      parentContextId: clearParentContextId ? null : (parentContextId ?? this.parentContextId),
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'sourceId': sourceId,
    'pageStart': pageStart,
    'pageEnd': pageEnd,
    'boundingRegion': boundingRegion.toJson(),
    'childEntityIds': childEntityIds,
    'confidence': confidence,
    'parentContextId': parentContextId,
    'sourceFingerprint': sourceFingerprint,
    'detectedTime': detectedTime.toIso8601String(),
    'status': status.name,
  };

  factory EngineeringContext.fromJson(Map<String, dynamic> json) {
    return EngineeringContext(
      id: json['id'] as String,
      type: EngineeringContextType.values.byName(json['type'] as String),
      title: json['title'] as String,
      sourceId: json['sourceId'] as String,
      pageStart: json['pageStart'] as int,
      pageEnd: json['pageEnd'] as int,
      boundingRegion: OcrBoundingBox.fromJson(json['boundingRegion'] as Map<String, dynamic>),
      childEntityIds: (json['childEntityIds'] as List).cast<String>(),
      confidence: (json['confidence'] as num).toDouble(),
      parentContextId: json['parentContextId'] as String?,
      sourceFingerprint: json['sourceFingerprint'] as String,
      detectedTime: DateTime.parse(json['detectedTime'] as String),
      status: EngineeringContextStatus.values.byName(json['status'] as String),
    );
  }
}
