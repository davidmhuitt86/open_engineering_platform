import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../settings/services/settings_storage.dart';
import 'dock_state.dart';

/// WP-DS-006 Engineering Workbench — Dock Manager. Owns the live
/// [DockManagerState] for one dock region and persists every change to its
/// own file, `workbench_docks/<dockId>.json` — one file per dock instance,
/// so (per the governing spec's Layout Manager section) changing one dock's
/// layout never affects another's. [dockId] is caller-chosen and must be
/// stable/unique across the app (e.g. `'instruments'`).
///
/// Generalizes WP-DS-005A's `InstrumentDockController`/
/// `InstrumentDockStorage` pair — same "fire and forget, cheap small JSON"
/// persistence precedent, now parameterized by [dockId] instead of hardcoded
/// to one file, so any Perspective can own any number of independent docks.
class DockManager extends ChangeNotifier {
  DockManager({required this.dockId, File? file, DockManagerState? initial})
      : _file = file ?? _defaultFile(dockId),
        _state = initial ?? DockManagerState.initial;

  final String dockId;
  final File _file;
  DockManagerState _state;

  DockManagerState get state => _state;

  static File _defaultFile(String dockId) =>
      File('${SettingsStorage.root().path}${Platform.pathSeparator}workbench_docks${Platform.pathSeparator}$dockId.json');

  /// Loads persisted state for [dockId], falling back to
  /// [DockManagerState.initial] if no file exists yet or it's corrupt.
  static Future<DockManager> load(String dockId, {File? file}) async {
    final resolvedFile = file ?? _defaultFile(dockId);
    if (!resolvedFile.existsSync()) return DockManager(dockId: dockId, file: resolvedFile);
    try {
      final decoded = jsonDecode(await resolvedFile.readAsString());
      final state = decoded is Map<String, Object?> ? DockManagerState.fromJson(decoded) : DockManagerState.initial;
      return DockManager(dockId: dockId, file: resolvedFile, initial: state);
    } on FormatException {
      return DockManager(dockId: dockId, file: resolvedFile);
    }
  }

  void _update(DockManagerState Function(DockManagerState) fn) {
    _state = fn(_state);
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await _file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file.writeAsString(encoder.convert(_state.toJson()));
  }

  void show(String? activeClientId) => _update(
        (s) => s.copyWith(
          visible: true,
          side: s.side == DockSide.hidden ? DockSide.bottom : s.side,
          activeClientId: activeClientId ?? s.activeClientId,
        ),
      );

  void hide() => _update((s) => s.copyWith(visible: false, side: DockSide.hidden));

  void toggleVisible(String? defaultClientId) => (_state.visible && _state.side != DockSide.hidden)
      ? hide()
      : show(defaultClientId);

  void selectClient(String id) => _update((s) => s.copyWith(activeClientId: id, visible: true));

  void setSide(DockSide side) => _update((s) => s.copyWith(side: side, visible: side != DockSide.hidden));

  void setAutoHide(bool value) => _update((s) => s.copyWith(autoHide: value));

  void setSize(double size) => _update((s) => s.copyWith(size: size.clamp(160, 800).toDouble()));

  void setFloatingBounds({double? left, double? top, double? width, double? height}) => _update(
        (s) => s.copyWith(
          floatingLeft: left,
          floatingTop: top,
          floatingWidth: width?.clamp(280, 1200).toDouble(),
          floatingHeight: height?.clamp(200, 900).toDouble(),
        ),
      );
}
