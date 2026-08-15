/// A whole-page evidence marker (Work Package 009 STUDIO-TASK-000019 §
/// Selection: "The engineer may select pages. Selection becomes part of
/// the active Knowledge Session. No text selection required. Page
/// selection only.").
///
/// Deliberately lighter than [EvidenceRegion] — SDD-015 lists "Page
/// Selection" and "Evidence Region" as separate example Evidence Object
/// kinds, and STUDIO-TASK-000021's linking requirement names only
/// "Evidence Region" as something a Knowledge Candidate may reference, so
/// a page selection carries no label/notes/links, just identity and which
/// page of which source it marks as relevant.
class PageSelection {
  const PageSelection({required this.id, required this.sourceId, required this.page, required this.createdTime});

  final String id;

  /// The [SourceMaterial.id] this selection belongs to.
  final String sourceId;

  /// 1-based page number.
  final int page;
  final DateTime createdTime;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'page': page,
    'createdTime': createdTime.toIso8601String(),
  };

  factory PageSelection.fromJson(Map<String, dynamic> json) {
    return PageSelection(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      page: json['page'] as int,
      createdTime: DateTime.parse(json['createdTime'] as String),
    );
  }
}
