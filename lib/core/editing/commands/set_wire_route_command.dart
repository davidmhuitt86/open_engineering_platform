import '../../views/diagram/diagram_geometry.dart';
import '../editing_command.dart';
import '../editing_session.dart';

/// Commits a manual wire route override, or restores automatic routing
/// (WORK_PACKAGE_023, ENGINE-TASK-000099).
///
/// Every manual wire edit — Insert Vertex, Remove Vertex, Drag Segment,
/// Drag Corner, Manual Route Override — reduces to the same operation:
/// compute a new point list (`lib/core/views/diagram/wire_editing.dart`)
/// and commit it here. There is deliberately no separate command type per
/// gesture. [points] `== null` means "Restore Automatic Routing" — it
/// clears the override so `DiagramView` falls back to the deterministic
/// `RoutingProvider` again.
class SetWireRouteCommand implements EditingCommand {
  final String relationshipId;
  final List<Point2D>? points;

  List<Point2D>? _previousOverride;
  bool _hadPreviousOverride = false;

  SetWireRouteCommand(this.relationshipId, this.points);

  @override
  String get description =>
      points == null ? 'Restore automatic routing' : 'Set manual wire route';

  @override
  EditingSession apply(EditingSession session) {
    _previousOverride = session.layout.wireOverrideOf(relationshipId);
    _hadPreviousOverride = _previousOverride != null;
    final layout = points == null
        ? session.layout.withoutWireOverride(relationshipId)
        : session.layout.withWireOverride(relationshipId, points!);
    return session.copyWith(layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    final layout = _hadPreviousOverride
        ? session.layout.withWireOverride(relationshipId, _previousOverride!)
        : session.layout.withoutWireOverride(relationshipId);
    return session.copyWith(layout: layout);
  }
}
