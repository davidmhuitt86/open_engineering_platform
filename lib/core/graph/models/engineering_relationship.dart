import 'evidence_link.dart';
import 'runtime_metadata.dart';

/// Engineering meaning carried by an [EngineeringRelationship] edge
/// (SDD-024). Not exhaustive — extensions may contribute domain-specific
/// relationship types via metadata without needing a new enum value; the
/// enum covers the relationships Phase 1 reasons about directly.
enum RelationshipType {
  connectedTo,
  suppliesPower,
  grounds,
  communicatesWith,
  contains,
  partOf,
  mountedTo,
  references,
  controls,
  measures,
  other,
}

/// A runtime Engineering Relationship — SDD-027's canonical edge shape.
class EngineeringRelationship {
  final String id;
  final RelationshipType relationshipType;
  final String sourceNode;
  final String targetNode;
  final String? repositoryRelationshipId;
  final Map<String, Object?> metadata;
  final List<EvidenceLink> evidenceLinks;

  /// Transient, never persisted (SDD-027).
  final RuntimeMetadata runtime;

  const EngineeringRelationship({
    required this.id,
    required this.relationshipType,
    required this.sourceNode,
    required this.targetNode,
    this.repositoryRelationshipId,
    this.metadata = const {},
    this.evidenceLinks = const [],
    this.runtime = RuntimeMetadata.initial,
  });

  EngineeringRelationship copyWith({
    RelationshipType? relationshipType,
    String? repositoryRelationshipId,
    Map<String, Object?>? metadata,
    List<EvidenceLink>? evidenceLinks,
    RuntimeMetadata? runtime,
  }) {
    return EngineeringRelationship(
      id: id,
      relationshipType: relationshipType ?? this.relationshipType,
      sourceNode: sourceNode,
      targetNode: targetNode,
      repositoryRelationshipId:
          repositoryRelationshipId ?? this.repositoryRelationshipId,
      metadata: metadata ?? this.metadata,
      evidenceLinks: evidenceLinks ?? this.evidenceLinks,
      runtime: runtime ?? this.runtime,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'relationshipType': relationshipType.name,
        'sourceNode': sourceNode,
        'targetNode': targetNode,
        'repositoryRelationshipId': repositoryRelationshipId,
        'metadata': metadata,
        'evidenceLinks': evidenceLinks.map((e) => e.toJson()).toList(),
      };

  factory EngineeringRelationship.fromJson(Map<String, Object?> json) {
    return EngineeringRelationship(
      id: json['id'] as String,
      relationshipType: RelationshipType.values.firstWhere(
        (t) => t.name == json['relationshipType'],
        orElse: () => RelationshipType.other,
      ),
      sourceNode: json['sourceNode'] as String,
      targetNode: json['targetNode'] as String,
      repositoryRelationshipId: json['repositoryRelationshipId'] as String?,
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
      evidenceLinks: (json['evidenceLinks'] as List? ?? const [])
          .map((e) => EvidenceLink.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EngineeringRelationship && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
