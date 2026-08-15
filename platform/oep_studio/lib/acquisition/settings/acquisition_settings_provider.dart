import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'acquisition_settings.dart';
import 'acquisition_settings_storage.dart';

/// Riverpod state for [AcquisitionSettings] — starts at
/// [AcquisitionSettings.defaults] and loads the saved file in the
/// background, mirroring `DiagramStudioSettingsNotifier` exactly.
class AcquisitionSettingsNotifier extends Notifier<AcquisitionSettings> {
  @override
  AcquisitionSettings build() {
    unawaited(_load());
    return AcquisitionSettings.defaults;
  }

  Future<void> _load() async {
    state = await AcquisitionSettingsStorage.load();
  }

  Future<void> setApiBaseUrl(String value) => _update(state.copyWith(apiBaseUrl: value));

  Future<void> _update(AcquisitionSettings next) async {
    state = next;
    await AcquisitionSettingsStorage.save(next);
  }
}

final acquisitionSettingsProvider = NotifierProvider<AcquisitionSettingsNotifier, AcquisitionSettings>(
  AcquisitionSettingsNotifier.new,
);
