/// A many-to-many link between a [KnowledgeCandidate] and an
/// [EvidenceRegion] (Work Package 009 STUDIO-TASK-000021): "One candidate
/// may reference multiple regions. One region may support multiple
/// candidates."
///
/// A thin join record — no fields of its own beyond identity and the two
/// endpoints — since nothing in Work Package 009's Requirements asks a
/// link itself to carry a reason/description; unlinking is by ID, not by
/// content.
class EvidenceLink {
  const EvidenceLink({
    required this.id,
    required this.candidateId,
    required this.regionId,
    required this.createdTime,
  });

  final String id;
  final String candidateId;
  final String regionId;
  final DateTime createdTime;

  Map<String, dynamic> toJson() => {
    'id': id,
    'candidateId': candidateId,
    'regionId': regionId,
    'createdTime': createdTime.toIso8601String(),
  };

  factory EvidenceLink.fromJson(Map<String, dynamic> json) {
    return EvidenceLink(
      id: json['id'] as String,
      candidateId: json['candidateId'] as String,
      regionId: json['regionId'] as String,
      createdTime: DateTime.parse(json['createdTime'] as String),
    );
  }
}
