import 'runtime_metadata.dart';

/// The kind of organizational grouping an [EngineeringGroup] represents
/// (SDD-027).
enum GroupKind { circuit, harness, assembly, subsystem, module, other }

/// Organizes [EngineeringNode]s by reference.
///
/// Groups never duplicate nodes (SDD-027) — [memberNodeIds] holds ids only,
/// resolved against the owning [EngineeringGraph]. [parentGroupId] (added
/// WORK_PACKAGE_021, ENGINE-TASK-000082) supports nesting — a child
/// group's parent, not a duplicated membership list. [locked] is a
/// persisted engineering intent ("don't let this group be edited"),
/// distinct from [runtime]'s transient collapse/expand/visibility state,
/// which reuses the same [RuntimeMetadata] shape nodes and relationships
/// already carry.
class EngineeringGroup {
  final String id;
  final GroupKind kind;
  final String displayName;
  final List<String> memberNodeIds;
  final String? parentGroupId;
  final bool locked;
  final Map<String, Object?> metadata;

  /// Transient — collapse/expand ([RuntimeMetadata.expanded]) and
  /// visibility ([RuntimeMetadata.visible]). Never persisted (SDD-027).
  final RuntimeMetadata runtime;

  const EngineeringGroup({
    required this.id,
    required this.kind,
    required this.displayName,
    this.memberNodeIds = const [],
    this.parentGroupId,
    this.locked = false,
    this.metadata = const {},
    this.runtime = RuntimeMetadata.initial,
  });

  EngineeringGroup copyWith({
    String? displayName,
    List<String>? memberNodeIds,
    String? parentGroupId,
    bool clearParentGroupId = false,
    bool? locked,
    Map<String, Object?>? metadata,
    RuntimeMetadata? runtime,
  }) {
    return EngineeringGroup(
      id: id,
      kind: kind,
      displayName: displayName ?? this.displayName,
      memberNodeIds: memberNodeIds ?? this.memberNodeIds,
      parentGroupId:
          clearParentGroupId ? null : (parentGroupId ?? this.parentGroupId),
      locked: locked ?? this.locked,
      metadata: metadata ?? this.metadata,
      runtime: runtime ?? this.runtime,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'displayName': displayName,
        'memberNodeIds': memberNodeIds,
        'parentGroupId': parentGroupId,
        'locked': locked,
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
      parentGroupId: json['parentGroupId'] as String?,
      locked: json['locked'] as bool? ?? false,
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
    );
  }

  @override
  bool operator ==(Object other) => other is EngineeringGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
