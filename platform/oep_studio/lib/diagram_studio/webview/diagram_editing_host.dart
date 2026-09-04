import 'package:engineering_engine/engineering_engine.dart';

import '../commands/studio_command_actions.dart';
import '../host/diagram_document.dart';

/// The exact surface [LegacyV2StateAdapter] needs from whatever it
/// bridges to — extracted (AP-OEP-DIAGRAM-COMPARE-001) so the V2 bridge
/// can drive either the app's one Primary diagram
/// (`DiagramStudioController`) or a second, independent Compare diagram
/// (`CompareDiagramController`) without the adapter itself knowing or
/// caring which. Every member here already existed, verbatim, on
/// `DiagramStudioController` before this interface was extracted — this
/// is a type-level cut, not a behavior change.
///
/// Deliberately narrow: only the members `legacy_v2_state_adapter.dart`
/// actually calls (confirmed by direct inspection of that file), not
/// `DiagramStudioController`'s full surface (tab lifecycle, clipboard,
/// layers, alignment, etc. — none of that is reachable from V2, so none
/// of it belongs on this interface).
abstract interface class DiagramEditingHost {
  EngineeringEngine get engine;
  DiagramDocument get document;
  String? get documentPath;
  StudioCommandActions get commands;

  void addNodeWithMetadata(
    String symbolId,
    Point2D position, {
    String? displayName,
    Map<String, Object?> metadata,
  });

  void deleteNode(String nodeId);
  void renameNode(String nodeId, String newDisplayName);
  void moveNodes(Map<String, Point2D> newPositions);
  void createRelationship(String sourceNodeId, String targetNodeId);
  void deleteRelationship(String relationshipId);
  void updateNodeMetadata(String nodeId, Map<String, Object?> patch);
  void updateRelationshipMetadata(
      String relationshipId, Map<String, Object?> patch);

  /// AP-DIAGRAM-V2-BRIDGE-SAVE-001 — see `DiagramLayoutState.
  /// wireSegmentOffsets`'s own doc comment for why this is a distinct
  /// concept from the pre-existing (but not currently bridged)
  /// `setWireRoute`/`SetWireRouteCommand`. `offsets == null` means "Reset
  /// Route" (V2's own `delete wireRoutes[wireId]`).
  void setWireSegmentOffsets(String relationshipId, Map<int, double>? offsets);

  Future<void> saveDocument();
}
