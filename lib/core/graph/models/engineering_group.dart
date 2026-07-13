/// The kind of organizational grouping an [EngineeringGroup] represents
/// (SDD-027).
enum GroupKind { circuit, harness, assembly, subsystem, module, other }

/// Organizes [EngineeringNode]s by reference.
///
/// Groups never duplicate nodes (SDD-027) — [memberNodeIds] holds ids only,
/// resolved against the owning [EngineeringGraph].
class EngineeringGroup {
  final String id;
  final GroupKind kind;
  final String displayName;
  final List<String> memberNodeIds;
  final Map<String, Object?> metadata;

  const EngineeringGroup({
    required this.id,
    required this.kind,
    required this.displayName,
    this.memberNodeIds = const [],
    this.metadata = const {},
  });

  EngineeringGroup copyWith({
    String? displayName,
    List<String>? memberNodeIds,
    Map<String, Object?>? metadata,
  }) {
    return EngineeringGroup(
      id: id,
      kind: kind,
      displayName: displayName ?? this.displayName,
      memberNodeIds: memberNodeIds ?? this.memberNodeIds,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'displayName': displayName,
        'memberNodeIds': memberNodeIds,
        'metadata': metadata,
      };

  factory EngineeringGroup.fromJson(Map<String, Object?> json) {
    return EngineeringGroup(
      id: json['id'] as String,
      kind: GroupKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => GroupKind.other,
      ),
      displayName: json['displayName'] as String,
      memberNodeIds: List<String>.from(json['memberNodeIds'] as List? ?? const []),
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
    );
  }

  @override
  bool operator ==(Object other) => other is EngineeringGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
