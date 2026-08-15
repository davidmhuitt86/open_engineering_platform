import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagram_studio_settings.dart';
import 'diagram_studio_settings_storage.dart';

/// Riverpod state for [DiagramStudioSettings] — starts at
/// [DiagramStudioSettings.defaults] and loads the saved file in the
/// background (mirrors `FoundationRuntimeNotifier`'s own
/// synchronous-`build()`-then-async-update shape).
class DiagramStudioSettingsNotifier extends Notifier<DiagramStudioSettings> {
  @override
  DiagramStudioSettings build() {
    unawaited(_load());
    return DiagramStudioSettings.defaults;
  }

  Future<void> _load() async {
    state = await DiagramStudioSettingsStorage.load();
  }

  Future<void> setDefaultGridVisible(bool value) => _update(state.copyWith(defaultGridVisible: value));
  Future<void> setDefaultSnapEnabled(bool value) => _update(state.copyWith(defaultSnapEnabled: value));
  Future<void> setDefaultGuidesVisible(bool value) => _update(state.copyWith(defaultGuidesVisible: value));

  Future<void> _update(DiagramStudioSettings next) async {
    state = next;
    await DiagramStudioSettingsStorage.save(next);
  }
}

final diagramStudioSettingsProvider =
    NotifierProvider<DiagramStudioSettingsNotifier, DiagramStudioSettings>(
  DiagramStudioSettingsNotifier.new,
);
