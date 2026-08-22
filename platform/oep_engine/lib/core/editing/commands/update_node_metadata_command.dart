import '../editing_command.dart';
import '../editing_session.dart';

/// Merges a metadata patch into a node (AP-DIAGRAM-V2-BRIDGE-011).
/// `null` values in [patch] remove the key. Mirrors
/// `UpdateRelationshipPropertiesCommand` exactly — the same generic,
/// free-form metadata-patch shape already established for relationships
/// (`v2WireId`/`label`/`wireColor`/`sourcePort`/`targetPort`), now
/// available for nodes too (`v2ModuleId`/`v2Category` were previously
/// only ever set once, at creation, via `addNodeWithMetadata` — this is
/// the first command that can patch a node's `metadata` after the fact).
///
/// Deliberately targets `metadata`, not `properties`: those are
/// semantically distinct fields on `EngineeringNode` (`properties` is
/// the engineering-value bag `MeasurementEngine`/verification read for
/// things like `expectedValue`; `metadata` is the free-form,
/// non-engineering annotation bag bridge/UI code already uses). A
/// UI-only field like a free-text note belongs in `metadata`, not
/// `properties` — using `properties` would have been a category error,
/// not a defensible mapping.
class UpdateNodeMetadataCommand implements EditingCommand {
  final String nodeId;
  final Map<String, Object?> patch;

  Map<String, Object?>? _previousMetadata;

  UpdateNodeMetadataCommand(this.nodeId, this.patch);

  @override
  String get description => 'Update node metadata';

  @override
  EditingSession apply(EditingSession session) {
    final node = session.graph.nodes[nodeId];
    if (node == null) return session;
    _previousMetadata = node.metadata;
    final merged = Map<String, Object?>.from(node.metadata);
    patch.forEach((key, value) {
      if (value == null) {
        merged.remove(key);
      } else {
        merged[key] = value;
      }
    });
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(metadata: merged)),
    );
  }

  @override
  EditingSession revert(EditingSession session) {
    final previous = _previousMetadata;
    final node = session.graph.nodes[nodeId];
    if (previous == null || node == null) return session;
    return session.copyWith(
      graph: session.graph.withNode(node.copyWith(metadata: previous)),
    );
  }
}
