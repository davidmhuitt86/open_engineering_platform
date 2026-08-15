import 'evidence_link.dart';
import 'port.dart';
import 'runtime_metadata.dart';

/// The engineering category an [EngineeringNode] represents (SDD-024).
///
/// Future node types may be added — this is intentionally not exhaustive of
/// every possible domain, only the categories Phase 1 needs to model.
enum NodeCategory {
  component,
  connector,
  wire,
  circuit,
  harness,
  module,
  relay,
  fuse,
  switchNode,
  ground,
  sensor,
  actuator,
  measurementPoint,
  procedure,
  specification,
  unknown,
}

/// A runtime Engineering Object — SDD-027's canonical Node shape.
///
/// The Engineering Graph carries no layout information (SDD-024): a Node
/// has no position, color, or rotation. Those belong to a View.
class EngineeringNode {
  final String id;
  final NodeCategory category;
  final String displayName;

  /// References a [SymbolDefinition] in the Symbol Library. `null` when no
  /// symbol has been assigned yet (still a valid, if unrendered, node).
  final String? symbolId;

  /// Foundation Object this node is mapped to, once a Repository is
  /// attached. `null` for a temporary/unsaved graph (SDD-025: "Temporary
  /// Engineering Graphs may exist before Repository Commit").
  final String? repositoryObjectId;

  final Map<String, Object?> metadata;
  final List<EvidenceLink> evidenceLinks;
  final Map<String, Object?> properties;
  final List<Port> ports;

  /// Extension-contributed data (SDD-029). The core engine never
  /// interprets this — extensions read/write their own namespaced entries.
  final Map<String, Object?>? extensionData;

  /// Transient, never persisted (SDD-027).
  final RuntimeMetadata runtime;

  const EngineeringNode({
    required this.id,
    required this.category,
    required this.displayName,
    this.symbolId,
    this.repositoryObjectId,
    this.metadata = const {},
    this.evidenceLinks = const [],
    this.properties = const {},
    this.ports = const [],
    this.extensionData,
    this.runtime = RuntimeMetadata.initial,
  });

  EngineeringNode copyWith({
    NodeCategory? category,
    String? displayName,
    String? symbolId,
    bool clearSymbolId = false,
    String? repositoryObjectId,
    Map<String, Object?>? metadata,
    List<EvidenceLink>? evidenceLinks,
    Map<String, Object?>? properties,
    List<Port>? ports,
    Map<String, Object?>? extensionData,
    RuntimeMetadata? runtime,
  }) {
    return EngineeringNode(
      id: id,
      category: category ?? this.category,
      displayName: displayName ?? this.displayName,
      symbolId: clearSymbolId ? null : (symbolId ?? this.symbolId),
      repositoryObjectId: repositoryObjectId ?? this.repositoryObjectId,
      metadata: metadata ?? this.metadata,
      evidenceLinks: evidenceLinks ?? this.evidenceLinks,
      properties: properties ?? this.properties,
      ports: ports ?? this.ports,
      extensionData: extensionData ?? this.extensionData,
      runtime: runtime ?? this.runtime,
    );
  }

  /// Persisted shape only — [runtime] is intentionally excluded (SDD-027).
  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        'displayName': displayName,
        'symbolId': symbolId,
        'repositoryObjectId': repositoryObjectId,
        'metadata': metadata,
        'evidenceLinks': evidenceLinks.map((e) => e.toJson()).toList(),
        'properties': properties,
        'ports': ports.map((p) => p.toJson()).toList(),
        if (extensionData != null) 'extensionData': extensionData,
      };

  factory EngineeringNode.fromJson(Map<String, Object?> json) {
    return EngineeringNode(
      id: json['id'] as String,
      category: NodeCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => NodeCategory.unknown,
      ),
      displayName: json['displayName'] as String,
      symbolId: json['symbolId'] as String?,
      repositoryObjectId: json['repositoryObjectId'] as String?,
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
      evidenceLinks: (json['evidenceLinks'] as List? ?? const [])
          .map((e) => EvidenceLink.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      properties: Map<String, Object?>.from(json['properties'] as Map? ?? const {}),
      ports: (json['ports'] as List? ?? const [])
          .map((p) => Port.fromJson(Map<String, Object?>.from(p as Map)))
          .toList(),
      extensionData: json['extensionData'] == null
          ? null
          : Map<String, Object?>.from(json['extensionData'] as Map),
    );
  }

  @override
  bool operator ==(Object other) => other is EngineeringNode && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
