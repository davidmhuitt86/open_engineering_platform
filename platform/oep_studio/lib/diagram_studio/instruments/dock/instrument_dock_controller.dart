import 'dart:async';

import 'package:flutter/foundation.dart';

import 'instrument_dock_state.dart';
import 'instrument_dock_storage.dart';

/// Owns the live [InstrumentDockState] and persists every change to disk
/// (debounced-free — writes are cheap, small JSON, matching
/// `WorkspaceStateStorage`'s own "fire and forget on every change"
/// precedent used elsewhere in this codebase).
///
/// One controller per Diagram Studio page, created in `initState` and
/// disposed in `dispose`, exactly like `DiagramSimulationService`.
class InstrumentDockController extends ChangeNotifier {
  InstrumentDockController({InstrumentDockState? initial}) : _state = initial ?? InstrumentDockState.initial;

  InstrumentDockState _state;
  InstrumentDockState get state => _state;

  static Future<InstrumentDockController> load() async {
    final saved = await InstrumentDockStorage.load();
    return InstrumentDockController(initial: saved);
  }

  void _update(InstrumentDockState Function(InstrumentDockState) fn) {
    _state = fn(_state);
    notifyListeners();
    unawaited(InstrumentDockStorage.save(_state));
  }

  void show(String? activeInstrumentId) => _update(
        (s) => s.copyWith(visible: true, activeInstrumentId: activeInstrumentId ?? s.activeInstrumentId),
      );

  void hide() => _update((s) => s.copyWith(visible: false));

  void toggleVisible(String? defaultInstrumentId) =>
      _state.visible ? hide() : show(defaultInstrumentId);

  void selectInstrument(String id) => _update((s) => s.copyWith(activeInstrumentId: id, visible: true));

  void setPosition(DockPosition position) => _update((s) => s.copyWith(position: position));

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
