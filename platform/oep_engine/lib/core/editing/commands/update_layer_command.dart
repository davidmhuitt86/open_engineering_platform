import '../editing_command.dart';
import '../editing_session.dart';

/// Patches a layer's name/visibility/lock/print-visibility/order in one
/// undoable step (WORK_PACKAGE_023, ENGINE-TASK-000101) — the same
/// patch-style shape `UpdateNodePropertiesCommand` already uses. Unset
/// fields leave that property untouched.
class UpdateLayerCommand implements EditingCommand {
  final String layerId;
  final String? name;
  final bool? visible;
  final bool? locked;
  final bool? printVisible;
  final int? order;

  String? _previousName;
  bool? _previousVisible;
  bool? _previousLocked;
  bool? _previousPrintVisible;
  int? _previousOrder;

  UpdateLayerCommand(
    this.layerId, {
    this.name,
    this.visible,
    this.locked,
    this.printVisible,
    this.order,
  });

  @override
  String get description => 'Update layer';

  @override
  EditingSession apply(EditingSession session) {
    final layer = session.layout.layerById(layerId);
    if (layer == null) return session;
    _previousName = layer.name;
    _previousVisible = layer.visible;
    _previousLocked = layer.locked;
    _previousPrintVisible = layer.printVisible;
    _previousOrder = layer.order;
    final updated = layer.copyWith(
      name: name,
      visible: visible,
      locked: locked,
      printVisible: printVisible,
      order: order,
    );
    return session.copyWith(layout: session.layout.withLayer(updated));
  }

  @override
  EditingSession revert(EditingSession session) {
    final layer = session.layout.layerById(layerId);
    if (layer == null || _previousName == null) return session;
    final restored = layer.copyWith(
      name: _previousName,
      visible: _previousVisible,
      locked: _previousLocked,
      printVisible: _previousPrintVisible,
      order: _previousOrder,
    );
    return session.copyWith(layout: session.layout.withLayer(restored));
  }
}
