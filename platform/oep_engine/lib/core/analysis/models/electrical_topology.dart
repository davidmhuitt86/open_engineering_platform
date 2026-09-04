import '../../knowledge/knowledge_runtime.dart';
import '../../knowledge/models/quantity.dart';

/// Electrical topology entities extracted from an [EngineeringGraph]
/// (AP-EK-020 §11 / Phase 5). Every entity retains `sourceObjectId`
/// (or equivalent) tracing back to the originating Engineering Object —
/// topology never becomes a parallel, untraceable identity system.

/// One electrical node (a set of terminals held at the same potential).
/// `isReference` marks the circuit's 0 V reference (AP-EK-020 §11
/// `ReferenceNode`) — there must be exactly one per analyzed topology.
class ElectricalNode {
  final String id;
  final bool isReference;

  /// The Engineering Object this node's reference terminal originates
  /// from, when this node corresponds 1:1 to a ground/reference
  /// Engineering Object (null for an internal junction node with no
  /// single originating object).
  final String? sourceObjectId;

  const ElectricalNode({
    required this.id,
    this.isReference = false,
    this.sourceObjectId,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'isReference': isReference,
    'sourceObjectId': sourceObjectId,
  };

  factory ElectricalNode.fromJson(Map<String, Object?> json) => ElectricalNode(
    id: json['id'] as String,
    isReference: json['isReference'] as bool? ?? false,
    sourceObjectId: json['sourceObjectId'] as String?,
  );
}

/// One resolved component instance: an Engineering Object bound to a
/// runtime Component Model, with its parameters resolved to typed
/// [Quantity] values (AP-EK-020 Phase 6/7).
class ComponentInstance {
  final String id;
  final String sourceObjectId;
  final String componentModelId;
  final Map<String, Quantity> parameters;

  const ComponentInstance({
    required this.id,
    required this.sourceObjectId,
    required this.componentModelId,
    required this.parameters,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceObjectId': sourceObjectId,
    'componentModelId': componentModelId,
    'parameters': {for (final e in parameters.entries) e.key: e.value.toJson()},
  };

  /// Reconstructs parameters as typed [Quantity]s by re-resolving each
  /// stored `unitId` through [runtime] — this is why topology reload
  /// requires the same runtime identity the analysis was produced with
  /// (AP-EK-020 §17, historical-runtime binding).
  factory ComponentInstance.fromJson(
    Map<String, Object?> json,
    KnowledgeRuntime runtime,
  ) {
    final rawParameters = Map<String, Object?>.from(json['parameters'] as Map);
    return ComponentInstance(
      id: json['id'] as String,
      sourceObjectId: json['sourceObjectId'] as String,
      componentModelId: json['componentModelId'] as String,
      parameters: {
        for (final entry in rawParameters.entries)
          entry.key: runtime.quantity(
            ((entry.value as Map)['value'] as num).toDouble(),
            (entry.value as Map)['unitId'] as String,
          ),
      },
    );
  }
}

/// A two-terminal branch connecting two [ElectricalNode]s through one
/// [ComponentInstance] (AP-EK-020 §11 `ElectricalBranch`).
class ElectricalBranch {
  final String id;
  final String componentInstanceId;
  final String fromNodeId;
  final String toNodeId;

  const ElectricalBranch({
    required this.id,
    required this.componentInstanceId,
    required this.fromNodeId,
    required this.toNodeId,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'componentInstanceId': componentInstanceId,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
  };

  factory ElectricalBranch.fromJson(Map<String, Object?> json) =>
      ElectricalBranch(
        id: json['id'] as String,
        componentInstanceId: json['componentInstanceId'] as String,
        fromNodeId: json['fromNodeId'] as String,
        toNodeId: json['toNodeId'] as String,
      );
}

/// A terminal-to-node binding (AP-EK-020 §11 `TerminalConnection`).
class TerminalConnection {
  final String componentInstanceId;
  final String terminalId;
  final String electricalNodeId;

  const TerminalConnection({
    required this.componentInstanceId,
    required this.terminalId,
    required this.electricalNodeId,
  });

  Map<String, Object?> toJson() => {
    'componentInstanceId': componentInstanceId,
    'terminalId': terminalId,
    'electricalNodeId': electricalNodeId,
  };

  factory TerminalConnection.fromJson(Map<String, Object?> json) =>
      TerminalConnection(
        componentInstanceId: json['componentInstanceId'] as String,
        terminalId: json['terminalId'] as String,
        electricalNodeId: json['electricalNodeId'] as String,
      );
}

/// The complete extracted topology for one analysis (AP-EK-020 §11).
/// Node/branch ordering is deterministic (assigned by a single
/// left-to-right walk from source to reference — see
/// `TopologyExtractor`), never dependent on `Map` iteration order.
class ElectricalTopology {
  final List<ElectricalNode> nodes;
  final List<ComponentInstance> components;
  final List<ElectricalBranch> branches;
  final List<TerminalConnection> terminalConnections;
  final String referenceNodeId;

  const ElectricalTopology({
    required this.nodes,
    required this.components,
    required this.branches,
    required this.terminalConnections,
    required this.referenceNodeId,
  });

  Map<String, Object?> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'components': components.map((c) => c.toJson()).toList(),
    'branches': branches.map((b) => b.toJson()).toList(),
    'terminalConnections': terminalConnections.map((t) => t.toJson()).toList(),
    'referenceNodeId': referenceNodeId,
  };

  factory ElectricalTopology.fromJson(
    Map<String, Object?> json,
    KnowledgeRuntime runtime,
  ) => ElectricalTopology(
    nodes: (json['nodes'] as List)
        .map(
          (n) => ElectricalNode.fromJson(Map<String, Object?>.from(n as Map)),
        )
        .toList(),
    components: (json['components'] as List)
        .map(
          (c) => ComponentInstance.fromJson(
            Map<String, Object?>.from(c as Map),
            runtime,
          ),
        )
        .toList(),
    branches: (json['branches'] as List)
        .map(
          (b) => ElectricalBranch.fromJson(Map<String, Object?>.from(b as Map)),
        )
        .toList(),
    terminalConnections: (json['terminalConnections'] as List)
        .map(
          (t) =>
              TerminalConnection.fromJson(Map<String, Object?>.from(t as Map)),
        )
        .toList(),
    referenceNodeId: json['referenceNodeId'] as String,
  );
}
