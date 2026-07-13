import 'dart:async';

import 'engine_event.dart';

/// Internal broadcast event bus shared by engine subsystems (SDD-026).
///
/// Not exposed on the public API surface directly — public services filter
/// and re-expose narrower typed streams (e.g. `SelectionProvider.changes`).
class EngineEventBus {
  final StreamController<EngineEvent> _controller =
      StreamController<EngineEvent>.broadcast();

  Stream<EngineEvent> get stream => _controller.stream;

  Stream<EngineEvent> on(EngineEventKind kind) =>
      _controller.stream.where((e) => e.kind == kind);

  void emit(EngineEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}
