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
class EvidenceRegion {
  const EvidenceRegion({
    required this.id,
    required this.sourceId,
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    this.notes = '',
    required this.createdTime,
    this.modifiedTime,
  });

  final String id;

  /// The [SourceMaterial.id] this region belongs to. A region always
  /// belongs to exactly one source and one page within it.
  final String sourceId;

  /// 1-based page number, matching `pdfrx`'s `PdfPage.pageNumber`.
  final int page;

  final double x;
  final double y;
  final double width;
  final double height;

  final String label;
  final String notes;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  EvidenceRegion copyWith({String? label, String? notes, DateTime? modifiedTime}) {
    return EvidenceRegion(
      id: id,
      sourceId: sourceId,
      page: page,
      x: x,
      y: y,
      width: width,
      height: height,
      label: label ?? this.label,
      notes: notes ?? this.notes,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'page': page,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'label': label,
    'notes': notes,
    'createdTime': createdTime.toIso8601String(),
    'modifiedTime': modifiedTime?.toIso8601String(),
  };

  factory EvidenceRegion.fromJson(Map<String, dynamic> json) {
    return EvidenceRegion(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      page: json['page'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      label: json['label'] as String,
      notes: json['notes'] as String? ?? '',
      createdTime: DateTime.parse(json['createdTime'] as String),
      modifiedTime: json['modifiedTime'] == null ? null : DateTime.parse(json['modifiedTime'] as String),
    );
  }
}
