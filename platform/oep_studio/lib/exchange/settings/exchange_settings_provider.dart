import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exchange_settings.dart';
import 'exchange_settings_storage.dart';

/// Riverpod state for [ExchangeSettings] -- starts at
/// [ExchangeSettings.defaults] and loads the saved file in the
/// background, mirroring `AcquisitionSettingsNotifier` exactly.
class ExchangeSettingsNotifier extends Notifier<ExchangeSettings> {
  @override
  ExchangeSettings build() {
    unawaited(_load());
    return ExchangeSettings.defaults;
  }

  Future<void> _load() async {
    state = await ExchangeSettingsStorage.load();
  }

  Future<void> setApiBaseUrl(String value) => _update(state.copyWith(apiBaseUrl: value));

  Future<void> _update(ExchangeSettings next) async {
    state = next;
    await ExchangeSettingsStorage.save(next);
  }
}

final exchangeSettingsProvider = NotifierProvider<ExchangeSettingsNotifier, ExchangeSettings>(
  ExchangeSettingsNotifier.new,
);
