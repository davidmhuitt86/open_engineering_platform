import '../editing_command.dart';
import '../editing_session.dart';

/// Commits (or clears) the Legacy Wiring Simulator V2 bridge's own
/// relative wire-route adjustment for one relationship (AP-DIAGRAM-V2-
/// BRIDGE-SAVE-001). Mirrors [SetWireRouteCommand]'s exact apply/revert
/// shape — see `DiagramLayoutState.wireSegmentOffsets`'s own doc comment
/// for why this is a deliberately separate concept from
/// [SetWireRouteCommand]'s absolute point list, not a variant of it.
/// [offsets] `== null` means "Reset Route" — V2's own `delete
/// wireRoutes[wireId]`, clearing every segment offset for the wire at
/// once.
class SetWireSegmentOffsetsCommand implements EditingCommand {
  final String relationshipId;
  final Map<int, double>? offsets;

  Map<int, double>? _previousOffsets;
  bool _hadPreviousOffsets = false;

  SetWireSegmentOffsetsCommand(this.relationshipId, this.offsets);

  @override
  String get description =>
      offsets == null ? 'Reset V2 wire route' : 'Set V2 wire route offsets';

  @override
  EditingSession apply(EditingSession session) {
    _previousOffsets = session.layout.wireSegmentOffsetsOf(relationshipId);
    _hadPreviousOffsets = _previousOffsets != null;
    final layout = offsets == null
        ? session.layout.withoutWireSegmentOffsets(relationshipId)
        : session.layout.withWireSegmentOffsets(relationshipId, offsets!);
    return session.copyWith(layout: layout);
  }

  @override
  EditingSession revert(EditingSession session) {
    final layout = _hadPreviousOffsets
        ? session.layout.withWireSegmentOffsets(
            relationshipId,
            _previousOffsets!,
          )
        : session.layout.withoutWireSegmentOffsets(relationshipId);
    return session.copyWith(layout: layout);
  }
}
