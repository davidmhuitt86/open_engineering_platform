import 'evidence_annotation.dart';
import 'evidence_geometry.dart';
import 'evidence_annotation_status.dart';
import 'evidence_origin.dart';

/// A manually-identified rectangular region of engineering evidence within
/// an attached PDF Source Material (Work Package 009 STUDIO-TASK-000020).
///
/// SDD-015 Layer 2.5 "Evidence Objects" lists "Evidence Region" by name as
/// a Workspace artifact — "They are not Engineering Objects. They do not
/// become repository truth." — so this model carries no repository-facing
/// fields (no confidence, no trust level); it exists purely to let an
/// engineer mark and later reference *where* on a page supporting evidence
/// lives.
///
/// [x]/[y]/[width]/[height] are fractions (`0.0`–`1.0`) of the PDF page's
/// own width/height, top-left origin — resolution- and zoom-independent,
/// so a region drawn at any zoom level renders correctly at any other. See
/// `docs/EVIDENCE_MODEL.md` § Evidence Region Model for the full rationale
/// and coordinate-conversion detail.
///
/// **WP-INGEST-010 additive extension** (AP-INGEST-009 §H/§I): four new,
/// all-optional fields distinguish a machine-generated region (already
/// produced today by `CandidateGenerationService`, previously
/// indistinguishable from a human-drawn one except by a free-text `notes`
/// convention) from a human annotation, and let a human annotation
/// optionally reference the machine observation it responds to. Every
/// field defaults to `null` when absent — see [fromJson]'s own doc
/// comment for why `null`, not a default value, is the correct backward-
/// compatibility behavior here.
class EvidenceRegion {
  /// Either pass [geometry] (rectangle or polyline), or the legacy
  /// `x/y/width/height` which describe a [RectangleGeometry]. Every existing
  /// caller keeps using the rectangle form unchanged.
  EvidenceRegion({
    required this.id,
    required this.sourceId,
    required this.page,
    double? x,
    double? y,
    double? width,
    double? height,
    EvidenceGeometry? geometry,
    required this.label,
    this.notes = '',
    required this.createdTime,
    this.modifiedTime,
    this.origin,
    this.annotatorId,
    this.status,
    this.observationRef,
    this.annotation,
  }) : geometry = geometry ?? RectangleGeometry(x!, y!, width!, height!);

  final String id;

  /// The [SourceMaterial.id] this region belongs to. A region always
  /// belongs to exactly one source and one page within it.
  final String sourceId;

  /// 1-based page number, matching `pdfrx`'s `PdfPage.pageNumber`.
  final int page;

  /// WHERE this evidence is (the annotation says WHAT it is).
  final EvidenceGeometry geometry;

  /// The geometry's normalized bounding box. For a [RectangleGeometry] these
  /// are exactly the rectangle's own values; for a polyline they are the
  /// path's extent, so every bounds-based consumer (thumbnails, navigation,
  /// the Evidence Browser) keeps working for both.
  double get x => geometry.bounds.x;
  double get y => geometry.bounds.y;
  double get width => geometry.bounds.width;
  double get height => geometry.bounds.height;

  final String label;
  final String notes;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  /// `null` means "unrecorded" (a pre-WP-INGEST-010 region, or a region
  /// this work package's own callers chose not to stamp) -- never
  /// inferred as [EvidenceOrigin.human] or [EvidenceOrigin.machine] from
  /// its absence (AP-INGEST-009 §2: "Do not infer human origin from
  /// missing fields").
  final EvidenceOrigin? origin;

  /// Who created a human annotation -- `null` for a machine-generated
  /// region (there is no annotator) or an origin-unrecorded legacy
  /// region. Distinct from [KnowledgeCandidate.author]: this identifies
  /// who drew/classified the REGION, not who authored a linked candidate.
  final String? annotatorId;

  /// A human annotation's review state (`null` for a machine-generated or
  /// origin-unrecorded region, for which "reviewed" has no defined
  /// meaning yet).
  final EvidenceAnnotationStatus? status;

  /// Optionally identifies the machine observation this human annotation
  /// responds to or confirms -- an `EngineeringEntity.id` or a
  /// `DerivedArtifact.derivedArtifactId`, resolved contextually the same
  /// way `EvidenceLink.candidateId`/`regionId` are plain, untyped id
  /// references elsewhere in this codebase. `null` is a fully valid,
  /// expected value: a human may annotate a region where UIF produced no
  /// machine observation at all (AP-INGEST-009 §4 -- "essential for the
  /// TRX300 case," where entity extraction produced zero results).
  final String? observationRef;

  /// WP-INGEST-013: the optional structured observation recorded about
  /// this region (open-ended properties). `null` on every region saved
  /// before this work package and on any region nobody has added a
  /// property to -- a missing payload is the ordinary, valid empty state.
  /// [EvidenceRegion] itself stays spatial/evidence-only; this is one
  /// optional payload, not a set of engineering-specific fields.
  final EvidenceAnnotation? annotation;

  EvidenceRegion copyWith({
    String? label,
    String? notes,
    DateTime? modifiedTime,
    EvidenceOrigin? origin,
    String? annotatorId,
    EvidenceAnnotationStatus? status,
    String? observationRef,
    EvidenceAnnotation? annotation,
    EvidenceGeometry? geometry,
  }) {
    return EvidenceRegion(
      id: id,
      sourceId: sourceId,
      page: page,
      geometry: geometry ?? this.geometry,
      label: label ?? this.label,
      notes: notes ?? this.notes,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      origin: origin ?? this.origin,
      annotatorId: annotatorId ?? this.annotatorId,
      status: status ?? this.status,
      observationRef: observationRef ?? this.observationRef,
      annotation: annotation ?? this.annotation,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'page': page,
        // Rectangles keep the legacy flat keys unchanged. A polyline also
        // writes its bounding box there (so older readers degrade to its
        // extent) plus the authoritative 'geometry' object.
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        if (geometry is! RectangleGeometry) 'geometry': geometry.toJson(),
        'label': label,
        'notes': notes,
        'createdTime': createdTime.toIso8601String(),
        'modifiedTime': modifiedTime?.toIso8601String(),
        'origin': origin?.name,
        'annotatorId': annotatorId,
        'status': status?.name,
        'observationRef': observationRef,
        'annotation': annotation?.toJson(),
      };

  /// **WP-INGEST-010 backward compatibility**: a session file saved
  /// before this work package has no `origin`/`annotatorId`/`status`/
  /// `observationRef` keys at all. Each defaults to `null` when absent --
  /// never a non-null fallback -- so an old region loads successfully
  /// with an honestly-unknown origin rather than a guessed one. Mirrors
  /// the exact precedent `docs/EVIDENCE_MODEL.md` already documents for
  /// `evidenceRegions`/`evidenceLinks`/`pageSelections` themselves
  /// defaulting to `[]` when a whole pre-Work-Package-009 session file
  /// predates the arrays entirely.
  factory EvidenceRegion.fromJson(Map<String, dynamic> json) {
    return EvidenceRegion(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      page: json['page'] as int,
      geometry: json['geometry'] == null
          ? RectangleGeometry(
              (json['x'] as num).toDouble(),
              (json['y'] as num).toDouble(),
              (json['width'] as num).toDouble(),
              (json['height'] as num).toDouble(),
            )
          : EvidenceGeometry.fromJson(json['geometry'] as Map<String, dynamic>),
      label: json['label'] as String,
      notes: json['notes'] as String? ?? '',
      createdTime: DateTime.parse(json['createdTime'] as String),
      modifiedTime: json['modifiedTime'] == null
          ? null
          : DateTime.parse(json['modifiedTime'] as String),
      origin: json['origin'] == null
          ? null
          : EvidenceOrigin.values.byName(json['origin'] as String),
      annotatorId: json['annotatorId'] as String?,
      status: json['status'] == null
          ? null
          : EvidenceAnnotationStatus.values.byName(json['status'] as String),
      observationRef: json['observationRef'] as String?,
      annotation: json['annotation'] == null
          ? null
          : EvidenceAnnotation.fromJson(
              json['annotation'] as Map<String, dynamic>),
    );
  }
}
