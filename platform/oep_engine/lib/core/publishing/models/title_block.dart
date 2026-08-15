/// AP-DS-004: a configurable engineering drawing title block. Pure data —
/// rendering (PDF/print/SVG) lives in the exporters, which read this model,
/// never the other way around.
class TitleBlock {
  final String company;
  final String project;
  final String drawingNumber;
  final String revision;
  final String engineer;
  final String approver;
  final DateTime? date;
  final String scale;
  final String sheet;

  /// e.g. "Confidential", "For Internal Use Only", "Public" — free text,
  /// not a fixed enum, since classification schemes vary by organization
  /// and this platform does not mandate one (per CLAUDE.md's "industries
  /// are delivered as packages" principle — a classification taxonomy is
  /// exactly the kind of thing a package should define, not the engine).
  final String classification;

  final List<RevisionEntry> revisionHistory;

  /// Organization-defined fields beyond the fixed set above (per the
  /// spec's own "Custom Fields" requirement) — label -> value.
  final Map<String, String> customFields;

  const TitleBlock({
    this.company = '',
    this.project = '',
    this.drawingNumber = '',
    this.revision = '',
    this.engineer = '',
    this.approver = '',
    this.date,
    this.scale = '',
    this.sheet = '',
    this.classification = '',
    this.revisionHistory = const [],
    this.customFields = const {},
  });

  static const TitleBlock empty = TitleBlock();

  TitleBlock copyWith({
    String? company,
    String? project,
    String? drawingNumber,
    String? revision,
    String? engineer,
    String? approver,
    DateTime? date,
    String? scale,
    String? sheet,
    String? classification,
    List<RevisionEntry>? revisionHistory,
    Map<String, String>? customFields,
  }) {
    return TitleBlock(
      company: company ?? this.company,
      project: project ?? this.project,
      drawingNumber: drawingNumber ?? this.drawingNumber,
      revision: revision ?? this.revision,
      engineer: engineer ?? this.engineer,
      approver: approver ?? this.approver,
      date: date ?? this.date,
      scale: scale ?? this.scale,
      sheet: sheet ?? this.sheet,
      classification: classification ?? this.classification,
      revisionHistory: revisionHistory ?? this.revisionHistory,
      customFields: customFields ?? this.customFields,
    );
  }

  Map<String, Object?> toJson() => {
        'company': company,
        'project': project,
        'drawingNumber': drawingNumber,
        'revision': revision,
        'engineer': engineer,
        'approver': approver,
        if (date != null) 'date': date!.toIso8601String(),
        'scale': scale,
        'sheet': sheet,
        'classification': classification,
        'revisionHistory': revisionHistory.map((r) => r.toJson()).toList(),
        'customFields': customFields,
      };

  factory TitleBlock.fromJson(Map<String, Object?> json) {
    final dateRaw = json['date'] as String?;
    return TitleBlock(
      company: json['company'] as String? ?? '',
      project: json['project'] as String? ?? '',
      drawingNumber: json['drawingNumber'] as String? ?? '',
      revision: json['revision'] as String? ?? '',
      engineer: json['engineer'] as String? ?? '',
      approver: json['approver'] as String? ?? '',
      date: dateRaw == null ? null : DateTime.tryParse(dateRaw),
      scale: json['scale'] as String? ?? '',
      sheet: json['sheet'] as String? ?? '',
      classification: json['classification'] as String? ?? '',
      revisionHistory: (json['revisionHistory'] as List? ?? const [])
          .map((r) => RevisionEntry.fromJson(Map<String, Object?>.from(r as Map)))
          .toList(),
      customFields: Map<String, String>.from(json['customFields'] as Map? ?? const {}),
    );
  }
}

enum RevisionApprovalStatus { draft, pendingApproval, approved, rejected }

/// One row of a title block's Revision Table / a document's Revision
/// History (the spec names both "Revision Table" and "Document History"
/// as separate bullets; this single model serves both — a title block's
/// `revisionHistory` list IS the document's revision history, there is no
/// reason to maintain two parallel lists of the same facts).
class RevisionEntry {
  final String revisionNumber;
  final String description;
  final String author;
  final DateTime date;
  final RevisionApprovalStatus approvalStatus;
  final String notes;

  const RevisionEntry({
    required this.revisionNumber,
    required this.description,
    required this.author,
    required this.date,
    this.approvalStatus = RevisionApprovalStatus.draft,
    this.notes = '',
  });

  Map<String, Object?> toJson() => {
        'revisionNumber': revisionNumber,
        'description': description,
        'author': author,
        'date': date.toIso8601String(),
        'approvalStatus': approvalStatus.name,
        'notes': notes,
      };

  factory RevisionEntry.fromJson(Map<String, Object?> json) {
    return RevisionEntry(
      revisionNumber: json['revisionNumber'] as String? ?? '',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      approvalStatus: RevisionApprovalStatus.values.firstWhere(
        (s) => s.name == json['approvalStatus'],
        orElse: () => RevisionApprovalStatus.draft,
      ),
      notes: json['notes'] as String? ?? '',
    );
  }
}
